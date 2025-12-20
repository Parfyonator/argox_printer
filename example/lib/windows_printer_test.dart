import 'dart:typed_data';
import 'package:argox_printer/argox_printer.dart';

/// Test connecting via Windows printer name instead of direct USB
void main() {
  final printer = ArgoxPPLA();

  // ignore: avoid_print
  print('=== Windows Printer Name Connection Test ===\n');

  // Replace with your actual printer name from Windows
  // You can find it with: Get-Printer | Select-Object Name
  final printerNames = [
    'Argox iX4-250 PPLA',  // Based on your PowerShell output
    'iX4-250 PPLA',
    'Argox iX4-250',
    'USB001',  // Sometimes just the port name
  ];

  for (var printerName in printerNames) {
    // ignore: avoid_print
    print('Trying printer name: "$printerName"');

    try {
      // Use A_CreatePrn with selection=0 and printer name as filename
      // This uses Windows print spooler
      int result = printer.A_CreatePrn(0, printerName);

      // ignore: avoid_print
      print('  Result: $result');

      if (result == 0) {
        // ignore: avoid_print
        print('  ✓ Connected!\n');

        // Try test print
        // ignore: avoid_print
        print('Sending test print...');
        try {
          printer.A_Set_Unit('m');
          printer.A_Clear_Memory();

          final text = Uint8List.fromList('Windows Printer Test'.codeUnits);
          printer.A_Prn_Text(10, 10, 1, 3, 0, 2, 2, 'N', 0, text);

          int printResult = printer.A_Print_Out(1, 1, 1, 1);
          // ignore: avoid_print
          print('Print result: $printResult\n');

          if (printResult == 0) {
            // ignore: avoid_print
            print('✓ SUCCESS! Check your printer for output.\n');
          }
        } catch (e) {
          // ignore: avoid_print
          print('Print error: $e\n');
        }

        printer.A_ClosePrn();
        return; // Success, exit
      } else {
        // ignore: avoid_print
        print('  ✗ Failed with code: $result\n');
      }
    } catch (e) {
      // ignore: avoid_print
      print('  ✗ Exception: $e\n');
    }
  }

  // ignore: avoid_print
  print('\n=== Additional Diagnostics ===\n');

  // ignore: avoid_print
  print('Run this PowerShell command to find your printer name:');
  // ignore: avoid_print
  print('Get-Printer | Select-Object Name, DriverName, PortName\n');

  // ignore: avoid_print
  print('Then update this script with the exact printer name.');
}
