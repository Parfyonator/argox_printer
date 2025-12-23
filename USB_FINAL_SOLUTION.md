# USB Connection - FINAL COMPLETE SOLUTION ✅

## Problem Solved
USB printer connection now works with automatic device path detection!

## The Complete Solution

### Method 1: Auto-Connect (Recommended - Easiest)

```dart
import 'package:argox_printer/argox_printer.dart';

final printer = ArgoxPPLA();

// Automatically find and connect to first USB printer
bool connected = await printer.usb.autoConnect();

if (connected) {
  // Print your content
  printer.A_Set_Unit('m');
  printer.A_Clear_Memory();
  printer.A_Prn_Text(10, 10, 1, 2, 0, 1, 1, 'N', 0,
    Uint8List.fromList('Hello!'.codeUnits));
  printer.A_Print_Out(1, 1, 1, 1);
  printer.A_ClosePrn();
}
```

### Method 2: List and Select Manually

```dart
final printer = ArgoxPPLA();

// Get list of available USB printers
List<UsbDeviceInfo> devices = await printer.usb.getUsbPrinters();

if (devices.isNotEmpty) {
  // Show user the list
  for (var device in devices) {
    print('${device.index}. ${device.name}');
  }

  // Connect to specific printer
  bool connected = printer.usb.connectByDevicePath(devices.first.path);
  // ... print your content ...
}
```

### Method 3: Direct Device Path (If You Know It)

```dart
final printer = ArgoxPPLA();

// Your specific device path
String devicePath = r'\\?\USB#VID_1664&PID_2010#21GA0DA58205#{a5dcbf10-6530-11d2-901f-00c04fb951ed}';

bool connected = printer.usb.connectByDevicePath(devicePath);
```

### Method 4: Fallback to Index

```dart
final printer = ArgoxPPLA();

// Connect by index (works even when enumeration fails)
bool connected = printer.usb.connectByIndex(1);  // 1 = first printer
```

---

## How It Works

### USB Helper Features

The `ArgoxUsbHelper` class provides:

1. **`getUsbPrinters()`** - Returns list of available USB printers with device paths
2. **`connectByDevicePath(String path)`** - Connect using device path (selection 12)
3. **`connectByIndex(int index)`** - Connect using index (selection 11)
4. **`autoConnect()`** - Automatically find and connect to first available printer

### Device Path Detection

The helper tries two methods:

1. **DLL enumeration** (if `A_GetUSBBufferLen()` > 0)
   - Uses `A_EnumUSB()` and `A_GetUSBDeviceInfo()`

2. **Windows WMI query** (fallback)
   - Queries Windows via PowerShell for USB devices
   - Converts PnP Instance ID to device path format
   - Format: `\\?\USB#VID_XXXX&PID_XXXX#SERIAL#{GUID}`

---

## What Was Fixed

### 1. Fixed `A_EnumUSB()` Buffer Allocation ✅
```dart
// Before: Hard-coded 128 bytes
// After: Dynamic allocation based on A_GetUSBBufferLen()
```

### 2. Fixed `A_GetUSBDeviceInfo()` Implementation ✅
```dart
// Before: Tried to send data (wrong)
// After: Allocates output buffers to receive data (correct)
```

### 3. Added USB Helper Class ✅
- Automatic device path detection via Windows WMI
- Fallback connection methods
- Easy-to-use API

---

## Connection Methods Comparison

| Method | Description | Works When A_EnumUSB Returns 0 | Reliability |
|--------|-------------|--------------------------------|-------------|
| **`usb.autoConnect()`** | Automatic detection + connection | ✅ Yes | ⭐⭐⭐⭐⭐ Best |
| **`usb.connectByDevicePath(path)`** | Direct device path (selection 12) | ✅ Yes | ⭐⭐⭐⭐⭐ Best |
| **`usb.connectByIndex(index)`** | Index-based (selection 11) | ✅ Yes | ⭐⭐⭐⭐ Good |
| **`A_CreateUSBPort(index)`** | Direct USB port | ❌ No | ⭐⭐⭐ Fair |

---

## Device Path Format

Windows USB device path format:
```
\\?\USB#VID_1664&PID_2010#21GA0DA58205#{a5dcbf10-6530-11d2-901f-00c04fb951ed}
```

Breaking it down:
- `\\?\` - Windows device path prefix
- `USB#VID_1664&PID_2010` - Vendor ID & Product ID
- `21GA0DA58205` - Serial number
- `{a5dcbf10-6530-11d2-901f-00c04fb951ed}` - USB Printing Support GUID

---

## PowerShell Query Used

The helper uses this PowerShell command to find USB printers:

```powershell
Get-PnpDevice | Where-Object {
  $_.Class -eq 'USB' -and $_.FriendlyName -like '*Argox*'
} | ForEach-Object {
  $deviceId = $_.InstanceId
  $devicePath = "\\?\$($deviceId.Replace('\', '#'))#{a5dcbf10-6530-11d2-901f-00c04fb951ed}"
  Write-Output "$($_.FriendlyName)|$devicePath"
}
```

This converts Windows PnP Instance ID to device path format.

---

## Complete Working Example

```dart
import 'dart:typed_data';
import 'package:argox_printer/argox_printer.dart';

Future<void> printLabel() async {
  final printer = ArgoxPPLA();

  // Auto-connect to USB printer
  bool connected = await printer.usb.autoConnect();

  if (!connected) {
    print('Failed to connect to USB printer');
    return;
  }

  try {
    // Configure printer
    printer.A_Set_Unit('m');
    printer.A_Set_Darkness(12);
    printer.A_Clear_Memory();

    // Add content
    printer.A_Prn_Text(10, 10, 1, 3, 0, 2, 2, 'N', 0,
      Uint8List.fromList('PRODUCT LABEL'.codeUnits));

    printer.A_Prn_Barcode(10, 50, 1, 'E', 2, 2, 30, 'N', 0, 'SKU12345');

    printer.A_Bar2d_QR_A(120, 50, 1, 3, 3, 'N', 0, 'https://example.com');

    // Print
    int result = printer.A_Print_Out(1, 1, 1, 1);

    if (result == 0) {
      print('✓ Print successful!');
    } else {
      print('✗ Print failed: $result');
    }
  } finally {
    printer.A_ClosePrn();
  }
}
```

---

## Files Added/Modified

### New Files ✨
- ✅ `lib/src/usb_helper.dart` - USB helper class with auto-detection
- ✅ `example/lib/usb_helper_example.dart` - Usage examples
- ✅ `example/lib/get_usb_device_path.dart` - Device path diagnostic tool

### Modified Files 📝
- ✅ `lib/src/printer_drivers.dart` - Fixed A_EnumUSB() and A_GetUSBDeviceInfo()
- ✅ `lib/argox_printer.dart` - Export usb_helper
- ✅ `example/windows/runner/CMakeLists.txt` - DLL copy for debug builds

---

## Testing

Run the example to test:

```bash
cd example
flutter run -d windows lib/usb_helper_example.dart
```

You should see:
```
=== Example 1: Auto-Connect ===

✓ Connected successfully!
✓ Print completed!

=== Example 2: Manual Selection ===

Found 1 USB printer(s):

  1. ARGOX iX4-250 PPLA
     Path: \\?\USB#VID_1664&PID_2010#21GA0DA58205#{a5dcbf10-6530-11d2-901f-00c04fb951ed}

Connecting to: ARGOX iX4-250 PPLA...
✓ Connected!
✓ Print completed!
```

---

## Why A_EnumUSB() Returns 0

When printers are managed through Windows print spooler (normal installation):
- ✅ `A_CreatePrn(12, devicePath)` **works** (via device path)
- ✅ `A_CreatePort(11, index, '')` **works** (via index)
- ⚠️ `A_EnumUSB()` **returns 0** (expected - not a bug!)

The helper handles this by:
1. Trying DLL enumeration first
2. Falling back to Windows WMI query
3. Using index-based connection as last resort

---

## Summary

✅ **Problem**: USB connection not working, enumeration returning 0
✅ **Root Cause**: DLL enumeration doesn't work with Windows-managed printers
✅ **Solution**: USB helper with Windows WMI query + device path connection
✅ **Result**: Automatic USB printer detection and connection working!

**Status: FULLY RESOLVED** 🎉

**Tested On**: Windows 10/11 with Argox iX4-250 PPLA
**DLL Version**: 4.11-4.12 AW (64-bit)
**Connection Methods**: All 4 methods verified working
