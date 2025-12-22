import 'dart:typed_data';
import 'package:argox_printer/argox_printer.dart';

/// Test USB connection using device path (like the C++ example)
void main() {
  final printer = ArgoxPPLA();

  // ignore: avoid_print
  print('=== USB Device Path Connection Test ===\n');

  try {
    // Step 1: Check if USB printers exist
    int bufferLen = printer.A_GetUSBBufferLen();
    // ignore: avoid_print
    print('USB Buffer Length: $bufferLen');

    if (bufferLen > 0) {
      // Step 2: Enumerate USB printers
      String usbList = printer.A_EnumUSB();
      // ignore: avoid_print
      print('USB Enumeration: "$usbList"\n');

      // Step 3: Get device info for first printer
      try {
        Map<String, String> deviceInfo = printer.A_GetUSBDeviceInfo(1);
        // ignore: avoid_print
        print('Device Info for printer 1:');
        // ignore: avoid_print
        print('  Device Name: ${deviceInfo['deviceName']}');
        // ignore: avoid_print
        print('  Device Path: ${deviceInfo['devicePath']}\n');

        // Step 4: Connect using device path (selection = 12)
        // This is like the C++ code: A_CreatePrn(12, buf2)
        String? devicePath = deviceInfo['devicePath'];
        if (devicePath != null && devicePath.isNotEmpty) {
          // ignore: avoid_print
          print('Connecting via device path...');
          int result = printer.A_CreatePrn(12, devicePath);

          if (result == 0) {
            // ignore: avoid_print
            print('✓ Connected successfully using device path!\n');

            // Test print
            testPrint(printer);

            printer.A_ClosePrn();
          } else {
            // ignore: avoid_print
            print('✗ Connection failed with code: $result\n');
          }
        } else {
          // ignore: avoid_print
          print('✗ Device path is empty\n');
        }
      } catch (e) {
        // ignore: avoid_print
        print('✗ Error getting device info: $e\n');

        // Fallback to A_CreatePort
        // ignore: avoid_print
        print('Falling back to A_CreatePort(11, 1, "")...');
        fallbackConnection(printer);
      }
    } else {
      // ignore: avoid_print
      print('⚠ No USB printers detected by A_GetUSBBufferLen()\n');
      // ignore: avoid_print
      print('This might indicate:');
      // ignore: avoid_print
      print('  1. Wrong DLL architecture (32-bit vs 64-bit)');
      // ignore: avoid_print
      print('  2. Printer driver not properly installed');
      // ignore: avoid_print
      print('  3. USB permissions issue\n');

      // Try fallback
      // ignore: avoid_print
      print('Trying fallback connection method...');
      fallbackConnection(printer);
    }
  } catch (e) {
    // ignore: avoid_print
    print('✗ Error: $e\n');

    // Try fallback
    // ignore: avoid_print
    print('Trying fallback connection method...');
    fallbackConnection(printer);
  }
}

void fallbackConnection(ArgoxPPLA printer) {
  try {
    int result = printer.A_CreatePort(11, 1, '');
    if (result == 0) {
      // ignore: avoid_print
      print('✓ Fallback connection successful!\n');
      testPrint(printer);
      printer.A_ClosePrn();
    } else {
      // ignore: avoid_print
      print('✗ Fallback connection failed with code: $result');
    }
  } catch (e) {
    // ignore: avoid_print
    print('✗ Fallback connection error: $e');
  }
}

void testPrint(ArgoxPPLA printer) {
  try {
    printer.A_Set_Unit('m');
    printer.A_Clear_Memory();

    final text = 'USB Device Path Test - ${DateTime.now()}';
    final textBytes = Uint8List.fromList(text.codeUnits);

    printer.A_Prn_Text(10, 10, 1, 2, 0, 1, 1, 'N', 0, textBytes);
    int printResult = printer.A_Print_Out(1, 1, 1, 1);

    if (printResult == 0) {
      // ignore: avoid_print
      print('✓ Test print successful!');
    } else {
      // ignore: avoid_print
      print('✗ Print failed with code: $printResult');
    }
  } catch (e) {
    // ignore: avoid_print
    print('✗ Print error: $e');
  }
}
