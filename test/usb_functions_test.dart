import 'package:test/test.dart';
import 'package:argox_printer/argox_printer.dart';

/// Tests for USB enumeration functions
///
/// NOTE: These tests require an actual Argox USB printer to be connected
/// When no printer is connected, A_GetUSBBufferLen() should return 0
void main() {
  group('USB Enumeration Functions', () {
    late ArgoxPPLA printer;

    setUp(() {
      printer = ArgoxPPLA();
    });

    test('A_GetUSBBufferLen returns 0 when no printer connected', () {
      // This is expected behavior when no printer is present
      int bufferLen = printer.A_GetUSBBufferLen();

      expect(bufferLen, equals(0),
          reason: 'No USB printer connected, should return 0');
    });

    test('A_EnumUSB throws exception when no printer connected', () {
      // When bufferLen is 0, A_EnumUSB should throw
      expect(
        () => printer.A_EnumUSB(),
        throwsA(isA<ArgoxException>().having(
          (e) => e.code,
          'error code',
          equals(4001), // No USB Printer Connect
        )),
        reason: 'Should throw "No USB Printer Connect" error',
      );
    });

    test('A_GetUSBDeviceInfo throws when no devices available', () {
      // When no printers are enumerated, this should fail
      expect(
        () => printer.A_GetUSBDeviceInfo(1),
        throwsA(isA<ArgoxException>()),
        reason: 'Should throw exception when no devices to query',
      );
    });

    // This test can only pass with an actual printer connected
    test('USB connection workflow (requires printer)', () {
      int bufferLen = printer.A_GetUSBBufferLen();

      if (bufferLen > 0) {
        // Printer is connected - test enumeration
        String usbList = printer.A_EnumUSB();
        expect(usbList, isNotEmpty, reason: 'Should return printer names');

        // Parse the list
        List<String> printers = usbList
            .split('\r\n')
            .where((s) => s.isNotEmpty)
            .toList();

        expect(printers, isNotEmpty, reason: 'Should have at least one printer');

        // Test getting device info
        Map<String, String> info = printer.A_GetUSBDeviceInfo(1);
        expect(info['deviceName'], isNotEmpty, reason: 'Should have device name');
        expect(info['devicePath'], isNotEmpty, reason: 'Should have device path');
      } else {
        // No printer connected - skip this test
        print('⚠️  Skipping: No USB printer connected');
      }
    }, skip: 'Requires physical printer connection');
  });

  group('USB Helper Functions', () {
    test('getUsbPrinters returns empty list when no printer connected', () async {
      final printer = ArgoxPPLA();
      final devices = await printer.usb.getUsbPrinters();

      // When no printer is connected:
      // - DLL enumeration fails (returns 0)
      // - Windows PowerShell query returns no devices
      // - Result should be empty list
      expect(devices, isEmpty,
          reason: 'No USB printer connected, should return empty list');
    });

    test('autoConnect fails gracefully when no printer connected', () async {
      final printer = ArgoxPPLA();
      final connected = await printer.usb.autoConnect();

      expect(connected, isFalse,
          reason: 'No USB printer connected, should return false');
    });

    test('connectByIndex fails when no printer connected', () {
      final printer = ArgoxPPLA();
      final connected = printer.usb.connectByIndex(1);

      expect(connected, isFalse,
          reason: 'No USB printer connected, should return false');
    });
  });

  group('Expected Behavior Documentation', () {
    test('Behavior when printer IS connected', () {
      // This documents expected behavior - not an actual test

      // When an Argox printer IS connected:
      // 1. A_GetUSBBufferLen() returns > 0 (size of device names buffer)
      // 2. A_EnumUSB() returns device names separated by \r\n
      // 3. A_GetUSBDeviceInfo(n) returns device info for printer n
      // 4. usb.getUsbPrinters() returns list of devices
      // 5. usb.autoConnect() connects and returns true

      expect(true, isTrue, reason: 'Documentation placeholder');
    });

    test('Behavior when printer is NOT connected', () {
      // This documents current behavior - this IS tested above

      // When NO Argox printer is connected:
      // 1. A_GetUSBBufferLen() returns 0 ✓
      // 2. A_EnumUSB() throws ArgoxException(4001) ✓
      // 3. A_GetUSBDeviceInfo(n) throws exception ✓
      // 4. usb.getUsbPrinters() returns empty list ✓
      // 5. usb.autoConnect() returns false ✓

      expect(true, isTrue, reason: 'Documentation placeholder');
    });
  });
}
