import 'dart:typed_data';
import 'package:argox_printer/argox_printer.dart';

/// Example demonstrating different methods to connect to USB printers
void main() {
  usbConnectionExamples();
}

void usbConnectionExamples() {
  final printer = ArgoxPPLA();

  print('=== USB Printer Connection Examples ===\n');

  // Method 1: Enumerate and connect by index
  connectByEnumeration(printer);

  // Method 2: Connect using A_CreateUSBPort
  connectUsingCreateUSBPort(printer);

  // Method 3: Connect using A_CreatePrn with USB index
  connectUsingCreatePrn(printer);

  // Method 4: Connect using A_CreatePort (unified method)
  connectUsingCreatePort(printer);

  // Method 5: Get detailed device information
  getUSBDeviceDetails(printer);
}

/// Method 1: Enumerate USB printers and connect to the first one
void connectByEnumeration(ArgoxPPLA printer) {
  print('--- Method 1: Enumerate USB Printers ---');
  try {
    // Check if any USB printers are connected
    int bufferLen = printer.A_GetUSBBufferLen();
    print('USB buffer length: $bufferLen');

    if (bufferLen > 0) {
      // Get list of USB printers
      String usbPrinters = printer.A_EnumUSB();
      print('Available USB printers:');

      // Parse the returned string (format: "Printer1\r\nPrinter2\r\n...")
      List<String> printers = usbPrinters.split('\r\n').where((s) => s.isNotEmpty).toList();
      for (int i = 0; i < printers.length; i++) {
        print('  [$i] ${printers[i]}');
      }

      if (printers.isNotEmpty) {
        // Connect to first printer using A_CreateUSBPort
        printer.A_CreateUSBPort(1); // Port index starts from 1
        print('✓ Connected to: ${printers[0]}\n');

        // Now you can use the printer
        testPrint(printer);

        printer.A_ClosePrn();
      }
    } else {
      print('✗ No USB printers found\n');
    }
  } catch (e) {
    print('✗ Error: $e\n');
  }
}

/// Method 2: Direct connection using A_CreateUSBPort
void connectUsingCreateUSBPort(ArgoxPPLA printer) {
  print('--- Method 2: A_CreateUSBPort ---');
  try {
    // Connect to first USB printer (index 1)
    int result = printer.A_CreateUSBPort(1);
    if (result == 0) {
      print('✓ Connected to USB printer at index 1\n');

      testPrint(printer);

      printer.A_ClosePrn();
    } else {
      print('✗ Connection failed with error code: $result\n');
    }
  } catch (e) {
    print('✗ Error: $e\n');
  }
}

/// Method 3: Connect using A_CreatePrn with selection=11 (USB by index)
void connectUsingCreatePrn(ArgoxPPLA printer) {
  print('--- Method 3: A_CreatePrn (USB by index) ---');
  try {
    // selection = 11 means USB by index
    // filename = printer index as string (1, 2, 3, etc.)
    int result = printer.A_CreatePrn(11, '1');
    if (result == 0) {
      print('✓ Connected using A_CreatePrn(11, "1")\n');

      testPrint(printer);

      printer.A_ClosePrn();
    } else {
      print('✗ Connection failed with error code: $result\n');
    }
  } catch (e) {
    print('✗ Error: $e\n');
  }
}

/// Method 4: Connect using A_CreatePort (unified method)
void connectUsingCreatePort(ArgoxPPLA printer) {
  print('--- Method 4: A_CreatePort ---');
  try {
    // nPortType values:
    // 0 = File, 1-3 = LPT, 4-6 = COM, 11 = USB by index, 12 = USB by path, 13 = Network
    int result = printer.A_CreatePort(11, 1, '');
    if (result == 0) {
      print('✓ Connected using A_CreatePort(11, 1, "")\n');

      testPrint(printer);

      printer.A_ClosePrn();
    } else {
      print('✗ Connection failed with error code: $result\n');
    }
  } catch (e) {
    print('✗ Error: $e\n');
  }
}

/// Method 5: Get detailed USB device information
void getUSBDeviceDetails(ArgoxPPLA printer) {
  print('--- Method 5: Get USB Device Details ---');
  try {
    // First check how many USB printers are available
    int bufferLen = printer.A_GetUSBBufferLen();

    if (bufferLen > 0) {
      String usbList = printer.A_EnumUSB();
      List<String> printers = usbList.split('\r\n').where((s) => s.isNotEmpty).toList();

      print('Found ${printers.length} USB printer(s):\n');

      // Get detailed info for each printer
      for (int i = 1; i <= printers.length; i++) {
        try {
          Map<String, String> info = printer.A_GetUSBDeviceInfo(i);
          print('Printer $i:');
          print('  Name: ${info['deviceName']}');
          print('  Path: ${info['devicePath']}');
          print('');

          // You can now connect using the device path if needed
          // printer.A_CreatePrn(12, info['devicePath']!);
        } catch (e) {
          print('  Error getting info for printer $i: $e\n');
        }
      }
    } else {
      print('✗ No USB printers found\n');
    }
  } catch (e) {
    print('✗ Error: $e\n');
  }
}

/// Simple test print to verify connection
void testPrint(ArgoxPPLA printer) {
  try {
    printer.A_Set_Unit('m');
    printer.A_Clear_Memory();

    // Convert string to Uint8List for A_Prn_Text
    final text = 'USB Connection Test';
    final textBytes = Uint8List.fromList(text.codeUnits);

    printer.A_Prn_Text(10, 10, 1, 2, 0, 1, 1, 'N', 0, textBytes);
    printer.A_Print_Out(1, 1, 1, 1);

    // ignore: avoid_print
    print('  Test print sent successfully');
  } catch (e) {
    // ignore: avoid_print
    print('  Test print failed: $e');
  }
}
