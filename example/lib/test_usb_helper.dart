import 'dart:typed_data';
import 'package:argox_printer/argox_printer.dart';

/// Test the USB helper with the FFI workaround
/// This should work even if A_GetUSBBufferLen returns 0
void main() async {
  print('=== Testing USB Helper (with FFI workaround) ===\n');

  final printer = ArgoxPPLA();

  // First, confirm the issue
  print('Step 1: Confirm A_GetUSBBufferLen issue');
  print('=' * 60);
  int bufferLen = printer.A_GetUSBBufferLen();
  print('A_GetUSBBufferLen() = $bufferLen');
  if (bufferLen == 0) {
    print('Confirmed: Returns 0 (FFI issue)\n');
  } else {
    print('Unexpected: Returns $bufferLen (FFI works!)\n');
  }

  // Test getUsbPrinters (should try multiple methods including workaround)
  print('Step 2: Test getUsbPrinters() with workaround');
  print('=' * 60);
  print('Calling printer.usb.getUsbPrinters()...');
  print('This will try:');
  print('  1. A_GetUSBBufferLen + A_EnumUSB');
  print('  2. A_GetUSBDeviceInfo direct (FFI workaround)');
  print('  3. Windows PowerShell query');
  print('');

  List<UsbDeviceInfo> devices = await printer.usb.getUsbPrinters();

  print('Found ${devices.length} device(s):');
  if (devices.isEmpty) {
    print('  (none)\n');
    print('✗ FAILED: No devices found');
    print('  All methods failed, including workarounds');
    return;
  }

  for (var device in devices) {
    print('');
    print('  Device ${device.index}:');
    print('    Name: ${device.name}');
    print('    Path: ${device.path}');
  }

  print('');
  print('✓ SUCCESS: Found ${devices.length} device(s)!\n');

  // Test autoConnect
  print('Step 3: Test autoConnect()');
  print('=' * 60);
  print('Calling printer.usb.autoConnect()...');

  bool connected = await printer.usb.autoConnect();

  if (!connected) {
    print('✗ autoConnect failed');
    print('  Could not connect to any detected device\n');
    return;
  }

  print('✓ Connected successfully!\n');

  // Test printing
  print('Step 4: Test actual printing');
  print('=' * 60);
  print('Printing test label...');

  try {
    printer.A_Set_Unit('m');
    printer.A_Clear_Memory();

    // Add test text
    printer.A_Prn_Text(
      10, 10, 1, 2, 0, 1, 1, 'N', 0,
      Uint8List.fromList('FFI Workaround Test'.codeUnits)
    );

    printer.A_Prn_Text(
      10, 30, 1, 1, 0, 1, 1, 'N', 0,
      Uint8List.fromList('A_GetUSBBufferLen returns: $bufferLen'.codeUnits)
    );

    printer.A_Prn_Text(
      10, 45, 1, 1, 0, 1, 1, 'N', 0,
      Uint8List.fromList('Devices found: ${devices.length}'.codeUnits)
    );

    // Print
    int result = printer.A_Print_Out(1, 1, 1, 1);

    if (result == 0) {
      print('✓ Print command sent successfully!');
      print('  Check printer for output\n');
    } else {
      print('✗ Print failed with code: $result\n');
    }
  } catch (e) {
    print('✗ Print error: $e\n');
  } finally {
    printer.A_ClosePrn();
  }

  // Summary
  print('=' * 60);
  print('SUMMARY');
  print('=' * 60);
  print('A_GetUSBBufferLen:      ${bufferLen == 0 ? "FAILS (FFI issue)" : "WORKS"}');
  print('Device detection:       ${devices.isNotEmpty ? "WORKS (via workaround)" : "FAILS"}');
  print('Connection:             ${connected ? "WORKS" : "FAILS"}');
  print('Printing:               (check printer output)');
  print('');
  print('Conclusion:');
  if (devices.isNotEmpty && connected) {
    print('  ✓ FFI workaround is SUCCESSFUL!');
    print('  ✓ USB functionality works despite A_GetUSBBufferLen returning 0');
    print('  ✓ The usb_helper.dart workaround handles the FFI issue');
  } else {
    print('  ✗ Workaround FAILED - need deeper investigation');
  }
  print('=' * 60);
}
