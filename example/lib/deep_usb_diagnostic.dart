import 'dart:io';
import 'package:argox_printer/argox_printer.dart';

/// Deep diagnostic to understand why A_GetUSBBufferLen returns 0
void main() async {
  print('=== Deep USB Diagnostic ===\n');

  await checkWindowsUsbDevices();
  await checkDllFunctions();
  await testDirectDllCalls();
  await compareWithWorkingConnection();
}

/// Check what Windows sees
Future<void> checkWindowsUsbDevices() async {
  print('Step 1: What Windows Sees');
  print('=' * 60);

  try {
    final result = await Process.run(
      'powershell',
      [
        '-NoProfile',
        '-Command',
        r'''
        Write-Output "All USB-related Argox devices:"
        Write-Output ""

        Get-PnpDevice | Where-Object {
          $_.FriendlyName -like '*Argox*' -or
          $_.InstanceId -like '*VID_1664*'
        } | Format-Table FriendlyName, Class, InstanceId -AutoSize | Out-String

        Write-Output ""
        Write-Output "USB Printing Support devices:"
        Write-Output ""

        Get-PnpDevice | Where-Object {
          $_.FriendlyName -like '*USB Printing Support*'
        } | Format-Table FriendlyName, Status, InstanceId -AutoSize | Out-String
        ''',
      ],
    );

    print(result.stdout);
  } catch (e) {
    print('Error: $e\n');
  }
}

/// Check DLL functions
Future<void> checkDllFunctions() async {
  print('\nStep 2: DLL Function Checks');
  print('=' * 60);

  final printer = ArgoxPPLA();

  // Check DLL version
  try {
    String version = printer.A_Get_DLL_Version(0);
    print('✓ DLL Version: $version');
  } catch (e) {
    print('✗ A_Get_DLL_Version failed: $e');
  }

  // Check A_GetUSBBufferLen
  try {
    int bufferLen = printer.A_GetUSBBufferLen();
    print('  A_GetUSBBufferLen(): $bufferLen');

    if (bufferLen == 0) {
      print('  ⚠ Returns 0 - DLL sees no USB printers');
    } else {
      print('  ✓ Returns $bufferLen - DLL sees USB printers!');
    }
  } catch (e) {
    print('✗ A_GetUSBBufferLen failed: $e');
  }

  // Try A_EnumUSB regardless
  try {
    print('\n  Attempting A_EnumUSB()...');
    String result = printer.A_EnumUSB();
    print('  Result: "$result"');
    print('  Length: ${result.length} bytes');

    if (result.isEmpty) {
      print('  ⚠ Empty result');
    } else {
      print('  ✓ Got data: $result');
    }
  } catch (e) {
    print('  ✗ A_EnumUSB failed: $e');
  }

  // Try A_GetUSBDeviceInfo
  try {
    print('\n  Attempting A_GetUSBDeviceInfo(1)...');
    Map<String, String> info = printer.A_GetUSBDeviceInfo(1);
    print('  Device Name: ${info['deviceName']}');
    print('  Device Path: ${info['devicePath']}');
  } catch (e) {
    print('  ✗ A_GetUSBDeviceInfo failed: $e');
  }

  print('');
}

/// Test direct DLL calls with different approaches
Future<void> testDirectDllCalls() async {
  print('\nStep 3: Connection Method Tests');
  print('=' * 60);

  final printer = ArgoxPPLA();

  // Test 1: A_CreateUSBPort
  print('Test 1: A_CreateUSBPort(1)');
  try {
    int result = printer.A_CreateUSBPort(1);
    print('  Result: $result');
    if (result == 0) {
      print('  ✓ Success!');
      printer.A_ClosePrn();
    } else {
      print('  ✗ Failed with code: $result');
      explainError(result);
    }
  } catch (e) {
    print('  ✗ Exception: $e');
  }

  // Test 2: A_CreatePort
  print('\nTest 2: A_CreatePort(11, 1, "")');
  try {
    int result = printer.A_CreatePort(11, 1, '');
    print('  Result: $result');
    if (result == 0) {
      print('  ✓ Success!');
      printer.A_ClosePrn();
    } else {
      print('  ✗ Failed with code: $result');
      explainError(result);
    }
  } catch (e) {
    print('  ✗ Exception: $e');
  }

  // Test 3: A_CreatePrn with index
  print('\nTest 3: A_CreatePrn(11, "1")');
  try {
    int result = printer.A_CreatePrn(11, '1');
    print('  Result: $result');
    if (result == 0) {
      print('  ✓ Success!');
      printer.A_ClosePrn();
    } else {
      print('  ✗ Failed with code: $result');
      explainError(result);
    }
  } catch (e) {
    print('  ✗ Exception: $e');
  }

  print('');
}

/// Compare with working method
Future<void> compareWithWorkingConnection() async {
  print('\nStep 4: Analysis');
  print('=' * 60);

  print('''
Understanding A_GetUSBBufferLen() returning 0:

The DLL's A_GetUSBBufferLen() function checks for USB printers using
a specific internal method. When it returns 0, it means:

1. The DLL is looking for "raw" USB devices
2. Your printer is registered through Windows Print Spooler
3. The DLL can't see it via its enumeration mechanism

However:
- A_CreatePort(11, index, '') works because it uses a different code path
- It likely uses Windows API (SetupDi* functions) to find USB printers
- This works even when enumeration returns 0

Possible reasons for A_GetUSBBufferLen() returning 0:

□ Printer driver type mismatch
  The DLL expects a specific driver type (RAW printer vs. Windows printer)

□ USB device class difference
  Printer shows as USBPRINT\* instead of USB\*

□ Windows version compatibility
  The DLL's enumeration might not work on newer Windows versions

□ Registry key location
  The DLL might be checking old registry locations

To verify:
1. Check if printer is configured as "Generic / Text Only" driver
2. Try installing as RAW USB printer (bypassing Windows spooler)
3. Check if older DLL version works differently
''');

  print('\nRecommendation:');
  print('  Use A_CreatePort(11, 1, "") or device path method');
  print('  These work reliably even when enumeration fails\n');
}

void explainError(int code) {
  Map<int, String> errors = {
    4001: 'No USB Printer Connect',
    4002: 'USB port number out of range',
    118: 'USB printer does not exist',
    119: 'Specified USB port not found',
  };

  if (errors.containsKey(code)) {
    print('  → ${errors[code]}');
  }
}
