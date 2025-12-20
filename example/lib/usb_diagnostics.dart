import 'dart:typed_data';
import 'package:argox_printer/argox_printer.dart';

/// Diagnostic script to debug USB connection issues
void main() {
  print('=== Argox USB Diagnostics ===\n');

  final printer = ArgoxPPLA();

  // Step 1: Check DLL version
  print('Step 1: Checking DLL version...');
  try {
    String version = printer.A_Get_DLL_Version(0);
    print('✓ DLL Version: $version\n');
  } catch (e) {
    print('✗ Failed to get DLL version: $e\n');
    return;
  }

  // Step 2: Check USB buffer length
  print('Step 2: Checking USB buffer length...');
  try {
    int bufferLen = printer.A_GetUSBBufferLen();
    print('✓ USB Buffer Length: $bufferLen');

    if (bufferLen <= 0) {
      print('⚠ Buffer length is 0 or negative - no USB printers detected by DLL\n');
      print('This could mean:');
      print('  1. Printer driver not installed correctly');
      print('  2. Printer not in a ready state');
      print('  3. DLL cannot access USB devices');
      print('  4. Windows USB permissions issue\n');

      // Try alternative detection method
      tryAlternativeMethod(printer);
      return;
    }
    print('');
  } catch (e) {
    print('✗ Error getting buffer length: $e\n');
    tryAlternativeMethod(printer);
    return;
  }

  // Step 3: Enumerate USB printers
  print('Step 3: Enumerating USB printers...');
  try {
    String usbList = printer.A_EnumUSB();
    print('✓ USB Enumeration Result:');
    print('Raw output: "$usbList"');

    if (usbList.isEmpty) {
      print('⚠ Enumeration returned empty string\n');
    } else {
      List<String> printers = usbList.split('\r\n').where((s) => s.isNotEmpty).toList();
      print('\nParsed printers:');
      for (int i = 0; i < printers.length; i++) {
        print('  [$i] ${printers[i]}');
      }
      print('');

      // Step 4: Get device info for each printer
      if (printers.isNotEmpty) {
        print('Step 4: Getting detailed device information...');
        for (int i = 1; i <= printers.length; i++) {
          try {
            Map<String, String> info = printer.A_GetUSBDeviceInfo(i);
            print('Printer $i:');
            print('  Name: ${info['deviceName']}');
            print('  Path: ${info['devicePath']}');
          } catch (e) {
            print('Printer $i: Error - $e');
          }
        }
        print('');

        // Step 5: Try to connect
        print('Step 5: Attempting connection to first printer...');
        tryConnection(printer, 1);
      }
    }
  } catch (e) {
    print('✗ Error during enumeration: $e');
    print('Error type: ${e.runtimeType}\n');

    if (e is ArgoxException) {
      print('Argox Error Code: ${e.code}');
      explainErrorCode(e.code);
    }
    print('');

    tryAlternativeMethod(printer);
  }
}

void tryConnection(ArgoxPPLA printer, int index) {
  print('Trying A_CreateUSBPort($index)...');
  try {
    int result = printer.A_CreateUSBPort(index);
    if (result == 0) {
      print('✓ Connection successful!\n');

      // Try a test print
      print('Step 6: Attempting test print...');
      try {
        printer.A_Set_Unit('m');
        printer.A_Clear_Memory();

        final text = 'USB Test - ${DateTime.now()}';
        final textBytes = Uint8List.fromList(text.codeUnits);

        printer.A_Prn_Text(10, 10, 1, 2, 0, 1, 1, 'N', 0, textBytes);
        int printResult = printer.A_Print_Out(1, 1, 1, 1);

        if (printResult == 0) {
          print('✓ Test print command sent successfully!');
        } else {
          print('⚠ Print command returned error code: $printResult');
          explainErrorCode(printResult);
        }

        printer.A_ClosePrn();
      } catch (e) {
        print('✗ Test print failed: $e');
        try {
          printer.A_ClosePrn();
        } catch (_) {}
      }
    } else {
      print('✗ Connection failed with code: $result');
      explainErrorCode(result);
    }
  } catch (e) {
    print('✗ Connection attempt threw exception: $e');
  }
  print('');
}

void tryAlternativeMethod(ArgoxPPLA printer) {
  print('=== Trying Alternative Connection Methods ===\n');

  // Method 1: Direct USB port creation
  print('Method 1: Direct A_CreateUSBPort(1)...');
  try {
    int result = printer.A_CreateUSBPort(1);
    if (result == 0) {
      print('✓ Connected successfully!');
      printer.A_ClosePrn();
    } else {
      print('✗ Failed with error code: $result');
      explainErrorCode(result);
    }
  } catch (e) {
    print('✗ Exception: $e');
  }
  print('');

  // Method 2: A_CreatePrn with USB index
  print('Method 2: A_CreatePrn(11, "1")...');
  try {
    int result = printer.A_CreatePrn(11, '1');
    if (result == 0) {
      print('✓ Connected successfully!');
      printer.A_ClosePrn();
    } else {
      print('✗ Failed with error code: $result');
      explainErrorCode(result);
    }
  } catch (e) {
    print('✗ Exception: $e');
  }
  print('');

  // Method 3: A_CreatePort
  print('Method 3: A_CreatePort(11, 1, "")...');
  try {
    int result = printer.A_CreatePort(11, 1, '');
    if (result == 0) {
      print('✓ Connected successfully!');
      printer.A_ClosePrn();
    } else {
      print('✗ Failed with error code: $result');
      explainErrorCode(result);
    }
  } catch (e) {
    print('✗ Exception: $e');
  }
  print('');

  // Method 4: Try with device path if you know it
  print('Method 4: Would need device path from Windows...');
  print('You can find it using Device Manager or the PowerShell command you ran.');
  print('Example: printer.A_CreatePrn(12, "USB_DEVICE_PATH_HERE");\n');
}

void explainErrorCode(int code) {
  Map<int, String> errorMessages = {
    4001: 'No USB Printer Connect - DLL cannot find USB printer',
    4002: 'USB port number is out of range',
    118: 'USB printer does not exist',
    119: 'Specified USB port cannot be found',
    2042: 'Memory allocation failed',
    1000: 'Print out failed',
  };

  if (errorMessages.containsKey(code)) {
    print('  → ${errorMessages[code]}');
  }

  if (code == 4001) {
    print('  Possible causes:');
    print('    • Printer driver not installed or incorrect driver');
    print('    • Printer is offline or in error state');
    print('    • USB cable disconnected');
    print('    • Printer requires specific DLL version');
    print('    • Application needs to run as Administrator');
  }
}
