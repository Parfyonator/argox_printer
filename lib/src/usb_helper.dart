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
    try {
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
      // A_GetUSBDeviceInfo not available, try Windows query
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

          $devices = Get-PnpDevice | Where-Object {
            $_.Class -eq 'USB' -and $_.FriendlyName -like '*Argox*'
          }

          foreach ($device in $devices) {
            $deviceId = $device.InstanceId

            # Convert PnP Instance ID to device path format
            # Format: \\?\USB#VID_XXXX&PID_XXXX#SERIAL#GUID
            $devicePath = "\\?\$($deviceId.Replace('\', '#'))#$usbPrintGuid"

            Write-Output "$($device.FriendlyName)|$devicePath"
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
