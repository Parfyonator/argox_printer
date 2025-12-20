import 'dart:typed_data';
import 'package:argox_printer/argox_printer.dart';

/// Ultra-simple USB test - just try to connect directly
void main() {
  final printer = ArgoxPPLA();

  // ignore: avoid_print
  print('Attempting direct USB connection...\n');

  // Try each method one by one
  final methods = [
    () {
      // ignore: avoid_print
      print('Method 1: A_CreateUSBPort(1)');
      return printer.A_CreateUSBPort(1);
    },
    () {
      // ignore: avoid_print
      print('Method 2: A_CreatePrn(11, "1")');
      return printer.A_CreatePrn(11, '1');
    },
    () {
      // ignore: avoid_print
      print('Method 3: A_CreatePort(11, 1, "")');
      return printer.A_CreatePort(11, 1, '');
    },
  ];

  for (var method in methods) {
    try {
      int result = method();
      // ignore: avoid_print
      print('  Result: $result');

      if (result == 0) {
        // ignore: avoid_print
        print('  ✓ SUCCESS! Connection established.\n');

        // Try to print something
        // ignore: avoid_print
        print('Sending test print...');
        try {
          printer.A_Set_Unit('m');
          printer.A_Clear_Memory();

          final text = Uint8List.fromList('USB Test OK'.codeUnits);
          printer.A_Prn_Text(10, 10, 1, 3, 0, 2, 2, 'N', 0, text);

          final printResult = printer.A_Print_Out(1, 1, 1, 1);
          // ignore: avoid_print
          print('Print result: $printResult');

          if (printResult == 0) {
            // ignore: avoid_print
            print('✓ Print command sent successfully!\n');
          } else {
            // ignore: avoid_print
            print('✗ Print failed with error: $printResult\n');
          }
        } catch (e) {
          // ignore: avoid_print
          print('✗ Print exception: $e\n');
        }

        printer.A_ClosePrn();
        // ignore: avoid_print
        print('Connection closed.\n');
        return; // Success, exit
      } else {
        // ignore: avoid_print
        print('  ✗ Failed with error code: $result\n');
      }
    } catch (e) {
      // ignore: avoid_print
      print('  ✗ Exception: $e\n');
    }
  }

  // ignore: avoid_print
  print('All methods failed. Checking enumeration...\n');

  try {
    // ignore: avoid_print
    print('A_GetUSBBufferLen(): ${printer.A_GetUSBBufferLen()}');
  } catch (e) {
    // ignore: avoid_print
    print('A_GetUSBBufferLen() failed: $e');
  }

  try {
    final enumResult = printer.A_EnumUSB();
    // ignore: avoid_print
    print('A_EnumUSB(): "$enumResult"');
  } catch (e) {
    // ignore: avoid_print
    print('A_EnumUSB() failed: $e');
  }
}
