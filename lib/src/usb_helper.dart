import 'dart:io';
import 'printer_drivers.dart';

/// USB Device Information
class UsbDeviceInfo {
  final String name;
  final String path;
  final int index;

  UsbDeviceInfo({
    required this.name,
    required this.path,
    required this.index,
  });

  @override
  String toString() => 'UsbDeviceInfo(name: $name, path: $path, index: $index)';
}

/// Helper class for USB printer operations
class ArgoxUsbHelper {
  final ArgoxPPLA _printer;

  ArgoxUsbHelper(this._printer);

  /// Get list of available USB printers
  /// Returns list of UsbDeviceInfo or empty list if none found
  Future<List<UsbDeviceInfo>> getUsbPrinters() async {
    final devices = <UsbDeviceInfo>[];

    // Try Method 1: A_GetUSBDeviceInfo (if DLL supports it)
    // Note: A_GetUSBBufferLen might return 0 in FFI even when printer is connected
    // Try direct device info query as workaround
    try {
      // First, try the documented approach with A_GetUSBBufferLen
      int bufferLen = _printer.A_GetUSBBufferLen();
      if (bufferLen > 0) {
        String usbList = _printer.A_EnumUSB();
        List<String> printerNames = usbList
            .split('\r\n')
            .where((s) => s.isNotEmpty)
            .toList();

        for (int i = 1; i <= printerNames.length; i++) {
          try {
            Map<String, String> info = _printer.A_GetUSBDeviceInfo(i);
            if (info['devicePath']?.isNotEmpty == true) {
              devices.add(UsbDeviceInfo(
                name: info['deviceName'] ?? 'Unknown',
                path: info['devicePath']!,
                index: i,
              ));
            }
          } catch (_) {
            // Skip this device if info retrieval fails
          }
        }

        if (devices.isNotEmpty) return devices;
      }
    } catch (_) {
      // A_GetUSBBufferLen failed, try alternative
    }

    // Method 1b: Try A_GetUSBDeviceInfo directly (FFI workaround)
    // Even if A_GetUSBBufferLen returns 0, A_GetUSBDeviceInfo might work
    if (devices.isEmpty) {
      try {
        for (int i = 1; i <= 5; i++) {
          try {
            Map<String, String> info = _printer.A_GetUSBDeviceInfo(i);
            if (info['devicePath']?.isNotEmpty == true) {
              devices.add(UsbDeviceInfo(
                name: info['deviceName'] ?? 'Unknown',
                path: info['devicePath']!,
                index: i,
              ));
            }
          } catch (_) {
            // No more devices at this index
            break;
          }
        }

        if (devices.isNotEmpty) return devices;
      } catch (_) {
        // A_GetUSBDeviceInfo also not available
      }
    }

    // Try Method 2: Query Windows via PowerShell/WMI
    try {
      final result = await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-Command',
          r'''
          # USB Printing Support interface GUID (Windows constant)
          $usbPrintGuid = "{a5dcbf10-6530-11d2-901f-00c04fb951ed}"

          # Find Argox printers - check both Printer and USB classes
          $devices = Get-PnpDevice | Where-Object {
            $_.FriendlyName -like '*Argox*' -and
            ($_.Class -eq 'Printer' -or $_.Class -eq 'USB')
          }

          foreach ($device in $devices) {
            $deviceId = $device.InstanceId

            # For USBPRINT devices, we need to get the USB parent device
            if ($deviceId -like 'USBPRINT*') {
              # Get the USB parent device which has the actual VID/PID
              $usbParent = Get-PnpDevice | Where-Object {
                $_.InstanceId -like 'USB\VID_1664*' -and
                $_.FriendlyName -like '*USB Printing Support*'
              }

              if ($usbParent) {
                $usbId = $usbParent.InstanceId
                $devicePath = "\\?\$($usbId.Replace('\', '#'))#$usbPrintGuid"
                Write-Output "$($device.FriendlyName)|$devicePath"
              }
            } elseif ($deviceId -like 'USB*') {
              # Direct USB device
              $devicePath = "\\?\$($deviceId.Replace('\', '#'))#$usbPrintGuid"
              Write-Output "$($device.FriendlyName)|$devicePath"
            }
          }
          ''',
        ],
      );

      if (result.exitCode == 0 && result.stdout.toString().isNotEmpty) {
        String output = result.stdout.toString();
        int index = 1;

        for (String line in output.split('\n')) {
          if (line.trim().isEmpty) continue;

          List<String> parts = line.split('|');
          if (parts.length == 2) {
            devices.add(UsbDeviceInfo(
              name: parts[0].trim(),
              path: parts[1].trim(),
              index: index++,
            ));
          }
        }
      }
    } catch (_) {
      // Windows query failed
    }

    return devices;
  }

  /// Connect to USB printer by device path
  /// Returns true if connection successful
  bool connectByDevicePath(String devicePath) {
    try {
      int result = _printer.A_CreatePrn(12, devicePath);
      return result == 0;
    } catch (_) {
      return false;
    }
  }

  /// Connect to USB printer by index (fallback method)
  /// Returns true if connection successful
  bool connectByIndex(int index) {
    try {
      int result = _printer.A_CreatePort(11, index, '');
      return result == 0;
    } catch (_) {
      return false;
    }
  }

  /// Auto-connect to first available USB printer
  /// Tries device path first, falls back to index
  /// Returns true if connection successful
  Future<bool> autoConnect() async {
    // Try to get device list
    List<UsbDeviceInfo> devices = await getUsbPrinters();

    // Try connecting via device path
    for (var device in devices) {
      if (connectByDevicePath(device.path)) {
        return true;
      }
    }

    // Fallback: Try connecting by index (1, 2, 3)
    for (int i = 1; i <= 3; i++) {
      if (connectByIndex(i)) {
        return true;
      }
    }

    return false;
  }
}

/// Extension to add USB helper to ArgoxPPLA
extension ArgoxUsbExtension on ArgoxPPLA {
  /// Get USB helper for this printer instance
  ArgoxUsbHelper get usb => ArgoxUsbHelper(this);
}
