import 'package:argox_printer/argox_printer.dart';

/// Test if A_GetUSBDeviceInfo works directly without A_GetUSBBufferLen
/// This is the workaround implemented in usb_helper.dart
void main() {
  print('=== Testing A_GetUSBDeviceInfo Direct Call ===\n');

  final printer = ArgoxPPLA();

  // First, confirm A_GetUSBBufferLen returns 0 (as expected on this system)
  print('Step 1: Check A_GetUSBBufferLen');
  print('=' * 60);
  int bufferLen = printer.A_GetUSBBufferLen();
  print('A_GetUSBBufferLen() = $bufferLen');
  if (bufferLen == 0) {
    print('✓ Returns 0 as expected (no printer on this system)\n');
  }

  // Now try calling A_GetUSBDeviceInfo directly for indices 1-5
  print('Step 2: Try A_GetUSBDeviceInfo(1..5) Directly');
  print('=' * 60);
  print('This tests if we can skip A_GetUSBBufferLen entirely\n');

  bool foundAny = false;

  for (int i = 1; i <= 5; i++) {
    print('Trying index $i...');
    try {
      Map<String, String> info = printer.A_GetUSBDeviceInfo(i);

      if (info['devicePath']?.isNotEmpty == true) {
        print('  ✓ Found device!');
        print('    Name: ${info['deviceName']}');
        print('    Path: ${info['devicePath']}\n');
        foundAny = true;
      } else {
        print('  - Empty device info at index $i\n');
      }
    } catch (e) {
      print('  ✗ Exception at index $i: $e\n');
      // Stop trying after first exception
      break;
    }
  }

  print('=' * 60);
  if (foundAny) {
    print('✓ SUCCESS: A_GetUSBDeviceInfo works directly!');
    print('  This means the workaround in usb_helper.dart should work.');
  } else {
    print('⚠️  No devices found (expected on system without printer)');
    print('  Need to test this on system WITH connected Argox printer.');
  }
  print('=' * 60);
}
