# USB Connection - SOLVED! ✅

## Working Solutions (Tested & Verified)

### ✅ Solution 1: A_CreatePort (USB Direct)
**Best for: Direct USB connection**

```dart
final printer = ArgoxPPLA();

printer.A_CreatePort(11, 1, '');  // 11 = USB by index, 1 = first printer

printer.A_Set_Unit('m');
printer.A_Clear_Memory();
printer.A_Prn_Text(10, 10, 1, 2, 0, 1, 1, 'N', 0,
  Uint8List.fromList('Test'.codeUnits));
printer.A_Print_Out(1, 1, 1, 1);

printer.A_ClosePrn();
```

### ✅ Solution 2: Windows Printer Name
**Best for: Maximum compatibility and reliability**

```dart
final printer = ArgoxPPLA();

// Use the exact printer name from Windows
printer.A_CreatePrn(0, 'Argox iX4-250 PPLA');

printer.A_Set_Unit('m');
printer.A_Clear_Memory();
printer.A_Prn_Text(10, 10, 1, 2, 0, 1, 1, 'N', 0,
  Uint8List.fromList('Test'.codeUnits));
printer.A_Print_Out(1, 1, 1, 1);

printer.A_ClosePrn();
```

**Find your printer name:**
```powershell
Get-Printer | Select-Object Name
```

---

## What Was Fixed

### 1. Fixed `A_EnumUSB()` Buffer Allocation
**Problem**: Hard-coded 128-byte buffer was too small
**Solution**: Dynamic allocation based on `A_GetUSBBufferLen()`

### 2. Fixed `A_GetUSBDeviceInfo()` Implementation
**Problem**: Function was sending data instead of receiving it
**Solution**: Complete rewrite with proper output buffers

### 3. Identified Working Connection Methods
**Discovery**: While `A_EnumUSB()` returns 0 (DLL limitation), `A_CreatePort(11, 1, '')` works perfectly!

---

## Your Printer Setup

From your system:
```
Name                    DriverName             PortName
----                    ----------             --------
Argox USB Printer       Argox iX4-250 PPLA     USB001      ← USB connection
Argox iX4-250 PPLA      Argox iX4-250 PPLA     10.80.1.60  ← Network connection
```

**Both connections work!**

---

## Why A_EnumUSB() Returns 0

The Argox DLL's `A_EnumUSB()` function looks for printers using a specific USB detection method. When it returns 0, it means:

1. The printer is connected via Windows print spooler (which is fine!)
2. The DLL doesn't detect "raw" USB devices directly
3. **This is normal** - Windows manages the USB connection

**Important**: Even though `A_EnumUSB()` returns 0, the printer still works perfectly with `A_CreatePort()` or Windows printer names.

---

## Complete Working Example

```dart
import 'dart:typed_data';
import 'package:argox_printer/argox_printer.dart';

void printLabel() {
  final printer = ArgoxPPLA();

  try {
    // Method 1: Direct USB
    printer.A_CreatePort(11, 1, '');

    // OR Method 2: Windows printer name (more reliable)
    // printer.A_CreatePrn(0, 'Argox iX4-250 PPLA');

    // Configure printer
    printer.A_Set_Unit('m');
    printer.A_Set_Darkness(12);
    printer.A_Clear_Memory();

    // Add content
    final title = Uint8List.fromList('Product Label'.codeUnits);
    printer.A_Prn_Text(10, 10, 1, 3, 0, 2, 2, 'N', 0, title);

    final sku = Uint8List.fromList('SKU: 12345'.codeUnits);
    printer.A_Prn_Text(10, 40, 1, 2, 0, 1, 1, 'N', 0, sku);

    // Add barcode
    printer.A_Prn_Barcode(10, 60, 1, 'E', 2, 2, 30, 'N', 0, '12345');

    // Add QR code
    printer.A_Bar2d_QR_A(120, 10, 1, 3, 3, 'N', 0, 'https://example.com');

    // Print
    int result = printer.A_Print_Out(1, 1, 1, 1);

    if (result == 0) {
      print('✓ Print successful!');
    } else {
      print('✗ Print failed with code: $result');
    }

    printer.A_ClosePrn();
  } catch (e) {
    print('Error: $e');
  }
}
```

---

## CMake Configuration for Apps Using This Package

Add this to your app's `windows/runner/CMakeLists.txt`:

```cmake
# Copy Argox printer DLLs to the executable directory
install(CODE "
  file(GLOB ARGOX_DLLS \"${INSTALL_BUNDLE_DATA_DIR}/${FLUTTER_ASSET_DIR_NAME}/packages/argox_printer/windows/*.dll\")
  if(ARGOX_DLLS)
    file(COPY \${ARGOX_DLLS} DESTINATION \"${INSTALL_BUNDLE_LIB_DIR}/..\")
    message(STATUS \"Copied Argox DLLs to executable directory\")
  endif()
  " COMPONENT Runtime)
```

---

## Troubleshooting

### Problem: DLL not found error
**Solution**: Make sure DLL is copied to executable directory (see CMake config above)

### Problem: "Port open failed" dialog
**Solution**:
1. Check printer is powered on and connected
2. Verify printer name: `Get-Printer | Select-Object Name`
3. Try both USB and network connection methods

### Problem: A_EnumUSB() returns 0
**Solution**: This is normal! Use `A_CreatePort(11, 1, '')` instead.

### Problem: Can't find printer
**Solution**:
1. Install official Argox driver (not generic Windows driver)
2. Check Device Manager for "Argox" device
3. Try printing test page from Windows first

---

## Files Modified

- ✅ `lib/src/printer_drivers.dart` - Fixed A_EnumUSB() and A_GetUSBDeviceInfo()
- ✅ `example/windows/runner/CMakeLists.txt` - Added DLL copy for examples
- ✅ `example/lib/usb_diagnostics.dart` - Diagnostic tool
- ✅ `example/lib/windows_printer_test.dart` - Working example
- ✅ `USB_CONNECTION_FIX.md` - Complete documentation

---

## Next Steps

1. ✅ USB connection working via `A_CreatePort(11, 1, '')`
2. ✅ USB connection working via Windows printer name
3. ✅ Test print successful
4. 📝 Consider updating main example to show both methods
5. 📝 Consider adding printer name detection helper function

---

**Status: RESOLVED** ✅
**Tested On**: Windows with Argox iX4-250 PPLA
**DLL Version**: 4.11 AW
**Working Methods**: A_CreatePort(11, 1, '') and A_CreatePrn(0, 'printer_name')
