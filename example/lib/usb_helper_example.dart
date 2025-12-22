import 'dart:typed_data';
import 'package:argox_printer/argox_printer.dart';

/// Example showing the USB helper usage
void main() async {
  await exampleAutoConnect();
  await exampleManualSelection();
}

/// Example 1: Auto-connect (easiest)
Future<void> exampleAutoConnect() async {
  // ignore: avoid_print
  print('=== Example 1: Auto-Connect ===\n');

  final printer = ArgoxPPLA();

  // Auto-connect to first available USB printer
  bool connected = await printer.usb.autoConnect();

  if (connected) {
    // ignore: avoid_print
    print('✓ Connected successfully!\n');

    // Print something
    printer.A_Set_Unit('m');
    printer.A_Clear_Memory();

    final text = 'Auto-Connect Test';
    printer.A_Prn_Text(10, 10, 1, 2, 0, 1, 1, 'N', 0,
        Uint8List.fromList(text.codeUnits));
    printer.A_Print_Out(1, 1, 1, 1);

    printer.A_ClosePrn();
    // ignore: avoid_print
    print('✓ Print completed!\n');
  } else {
    // ignore: avoid_print
    print('✗ Failed to connect to any USB printer\n');
  }
}

/// Example 2: List and select printer manually
Future<void> exampleManualSelection() async {
  // ignore: avoid_print
  print('=== Example 2: Manual Selection ===\n');

  final printer = ArgoxPPLA();

  // Get list of available USB printers
  List<UsbDeviceInfo> devices = await printer.usb.getUsbPrinters();

  if (devices.isEmpty) {
    // ignore: avoid_print
    print('✗ No USB printers found\n');
    return;
  }

  // ignore: avoid_print
  print('Found ${devices.length} USB printer(s):\n');
  for (var device in devices) {
    // ignore: avoid_print
    print('  ${device.index}. ${device.name}');
    // ignore: avoid_print
    print('     Path: ${device.path}\n');
  }

  // Connect to first printer using device path
  UsbDeviceInfo firstPrinter = devices.first;
  // ignore: avoid_print
  print('Connecting to: ${firstPrinter.name}...');

  bool connected = printer.usb.connectByDevicePath(firstPrinter.path);

  if (connected) {
    // ignore: avoid_print
    print('✓ Connected!\n');

    // Print something
    printer.A_Set_Unit('m');
    printer.A_Clear_Memory();

    final text = 'Manual Connect Test - ${firstPrinter.name}';
    printer.A_Prn_Text(10, 10, 1, 2, 0, 1, 1, 'N', 0,
        Uint8List.fromList(text.codeUnits));
    printer.A_Print_Out(1, 1, 1, 1);

    printer.A_ClosePrn();
    // ignore: avoid_print
    print('✓ Print completed!\n');
  } else {
    // ignore: avoid_print
    print('✗ Connection failed\n');
  }
}
