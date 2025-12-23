import 'package:argox_printer/argox_printer.dart';

/// Simple test to understand A_GetUSBBufferLen behavior
void main() {
  print('=== Simple USB Test ===\n');

  final printer = ArgoxPPLA();

  // Test 1: Check DLL version
  print('Step 1: DLL Version Check');
  print('-' * 60);
  try {
    String version = printer.A_Get_DLL_Version(0);
    print('✓ DLL Version: $version\n');
  } catch (e) {
    print('✗ A_Get_DLL_Version failed: $e\n');
    return;
  }

  // Test 2: A_GetUSBBufferLen
  print('Step 2: A_GetUSBBufferLen Check');
  print('-' * 60);
  try {
    int bufferLen = printer.A_GetUSBBufferLen();
    print('Result: $bufferLen bytes\n');

    if (bufferLen == 0) {
      print('Analysis: A_GetUSBBufferLen() returns 0');
      print('This means the DLL\'s internal USB enumeration finds no devices.\n');
    } else {
      print('✓ DLL found USB printers! Buffer size: $bufferLen bytes\n');
    }
  } catch (e) {
    print('✗ A_GetUSBBufferLen failed: $e\n');
  }

  // Test 3: Try A_EnumUSB anyway (will throw if bufferLen is 0)
  print('Step 3: A_EnumUSB Attempt');
  print('-' * 60);
  try {
    String result = printer.A_EnumUSB();
    print('✓ Result: "$result"');
    print('Length: ${result.length} characters\n');
  } catch (e) {
    print('✗ A_EnumUSB failed: $e');
    print('This is expected when A_GetUSBBufferLen returns 0\n');
  }

  // Test 4: Try connection methods that DO work
  print('Step 4: Testing Known Working Methods');
  print('-' * 60);

  // Method A: A_CreatePort(11, 1, '')
  print('Test A: A_CreatePort(11, 1, \"\")');
  try {
    int result = printer.A_CreatePort(11, 1, '');
    print('  Result code: $result');
    if (result == 0) {
      print('  ✓ SUCCESS! Connected via index method');
      printer.A_ClosePrn();
    } else {
      print('  ✗ Failed with error code: $result');
      explainError(result);
    }
  } catch (e) {
    print('  ✗ Exception: $e');
  }

  print('');

  // Method B: A_CreateUSBPort(1)
  print('Test B: A_CreateUSBPort(1)');
  try {
    int result = printer.A_CreateUSBPort(1);
    print('  Result code: $result');
    if (result == 0) {
      print('  ✓ SUCCESS! Connected via A_CreateUSBPort');
      printer.A_ClosePrn();
    } else {
      print('  ✗ Failed with error code: $result');
      explainError(result);
    }
  } catch (e) {
    print('  ✗ Exception: $e');
  }

  print('\n' + '=' * 60);
  print('CONCLUSION');
  print('=' * 60);
  print('''
If A_GetUSBBufferLen() returns 0 but A_CreatePort(11, 1, '') works:

This indicates the DLL has TWO different code paths:

1. ENUMERATION PATH (A_GetUSBBufferLen/A_EnumUSB):
   - Uses DLL's internal USB device enumeration
   - Looking for "raw" USB devices
   - Returns 0 when printer is managed by Windows Print Spooler
   - This is NOT a bug - it's expected behavior!

2. CONNECTION PATH (A_CreatePort/A_CreateUSBPort):
   - Uses Windows API (likely SetupDiEnumDeviceInterfaces)
   - Can find printers even when enumeration returns 0
   - Works with Windows Print Spooler managed devices
   - This is the RELIABLE method!

WHY this happens:
- When printer is installed via Windows "Add Printer"
- Printer shows as USBPRINT\\* device (not USB\\*)
- Windows Print Spooler manages the device
- DLL enumeration doesn't see it (by design)
- But Windows API connection methods DO see it

RECOMMENDATION:
Use A_CreatePort(11, index, '') or device path method.
Don't rely on A_GetUSBBufferLen/A_EnumUSB for printer detection.
''');
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
