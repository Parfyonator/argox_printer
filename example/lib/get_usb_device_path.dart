import 'dart:io';
import 'dart:typed_data';
import 'package:argox_printer/argox_printer.dart';

/// Get USB device path from Windows Registry or WMI
void main() async {
  print('=== Getting USB Device Path ===\n');

  // Method 1: Try via PowerShell/WMI
  await getDevicePathViaWMI();

  // Method 2: Try via Registry
  await getDevicePathViaRegistry();

  // Method 3: Test if A_GetUSBDeviceInfo works now
  await tryGetUSBDeviceInfo();
}

/// Method 1: Get device path using WMI (Windows Management Instrumentation)
Future<void> getDevicePathViaWMI() async {
  print('Method 1: WMI Query');
  print('-' * 50);

  try {
    // Query for USB Printing Support devices
    final result = await Process.run(
      'powershell',
      [
        '-Command',
        '''
        Get-PnpDevice | Where-Object {
          \$_.Class -eq 'USB' -and \$_.FriendlyName -like '*Argox*'
        } | ForEach-Object {
          \$deviceId = \$_.InstanceId
          # Convert PnP format to device path format
          \$devicePath = "\\\\?\\\" + \$deviceId.Replace('\\', '#') + \"#{a5dcbf10-6530-11d2-901f-00c04fb951ed}\"
          Write-Output "Name: \$(\$_.FriendlyName)"
          Write-Output "Path: \$devicePath"
          Write-Output "---"
        }
        '''
      ],
    );

    if (result.exitCode == 0) {
      print(result.stdout);

      // Parse the output to extract device path
      String output = result.stdout.toString();
      RegExp pathRegex = RegExp(r'Path: (.+)');
      Match? match = pathRegex.firstMatch(output);

      if (match != null) {
        String devicePath = match.group(1)!.trim();
        print('✓ Found device path: $devicePath\n');

        // Test connection
        await testConnection(devicePath);
      }
    } else {
      print('✗ WMI query failed: ${result.stderr}\n');
    }
  } catch (e) {
    print('✗ Error: $e\n');
  }
}

/// Method 2: Get device path from Registry
Future<void> getDevicePathViaRegistry() async {
  print('\nMethod 2: Registry Query');
  print('-' * 50);

  try {
    final result = await Process.run(
      'reg',
      [
        'query',
        'HKLM\\SYSTEM\\CurrentControlSet\\Enum\\USB',
        '/s',
        '/f',
        'Argox',
      ],
    );

    if (result.exitCode == 0) {
      print('Registry entries found:');
      print(result.stdout);
    } else {
      print('✗ Registry query failed\n');
    }
  } catch (e) {
    print('✗ Error: $e\n');
  }
}

/// Method 3: Try A_GetUSBDeviceInfo (might work now with fixes)
Future<void> tryGetUSBDeviceInfo() async {
  print('\nMethod 3: A_GetUSBDeviceInfo');
  print('-' * 50);

  final printer = ArgoxPPLA();

  try {
    int bufferLen = printer.A_GetUSBBufferLen();
    print('Buffer length: $bufferLen');

    if (bufferLen > 0) {
      String usbList = printer.A_EnumUSB();
      print('USB List: "$usbList"');

      // Try to get device info
      Map<String, String> info = printer.A_GetUSBDeviceInfo(1);
      print('Device Name: ${info['deviceName']}');
      print('Device Path: ${info['devicePath']}');

      if (info['devicePath']?.isNotEmpty == true) {
        print('\n✓ Got device path from A_GetUSBDeviceInfo!');
        await testConnection(info['devicePath']!);
      }
    } else {
      print('⚠ A_GetUSBBufferLen returned 0 - enumeration not available\n');
    }
  } catch (e) {
    print('✗ Error: $e\n');
  }
}

/// Test connection with device path
Future<void> testConnection(String devicePath) async {
  print('\n🔌 Testing connection with device path...');
  print('Path: $devicePath\n');

  final printer = ArgoxPPLA();

  try {
    int result = printer.A_CreatePrn(12, devicePath);

    if (result == 0) {
      print('✓ Connection successful!\n');

      // Test print
      printer.A_Set_Unit('m');
      printer.A_Clear_Memory();

      final text = 'Device Path Test - ${DateTime.now()}';
      final textBytes = Uint8List.fromList(text.codeUnits);

      printer.A_Prn_Text(10, 10, 1, 2, 0, 1, 1, 'N', 0, textBytes);
      int printResult = printer.A_Print_Out(1, 1, 1, 1);

      if (printResult == 0) {
        print('✓ Print successful!');
      } else {
        print('⚠ Print failed with code: $printResult');
      }

      printer.A_ClosePrn();
    } else {
      print('✗ Connection failed with code: $result');
    }
  } catch (e) {
    print('✗ Connection error: $e');
  }
}
