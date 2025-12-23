# USB Investigation Summary

## Investigation Timeline

### Initial Problem
- USB connection not working in Flutter package
- `A_EnumUSB()` and `A_GetUSBBufferLen()` returning 0
- Network (LPT) connections work fine

### Bugs Found and Fixed

#### 1. `A_EnumUSB()` Buffer Allocation Bug ✅
**Location**: [lib/src/printer_drivers.dart:1649-1667](lib/src/printer_drivers.dart#L1649-L1667)

**Problem**: Hard-coded 128-byte buffer, should be dynamic based on `A_GetUSBBufferLen()`

**Before**:
```dart
String A_EnumUSB() {
  final pbuf = calloc<ffi.Int8>(128);  // ❌ Fixed size
  // ...
}
```

**After**:
```dart
String A_EnumUSB() {
  final bufferLen = A_GetUSBBufferLen();
  if (bufferLen <= 0) {
    throw ArgoxException(4001);  // No USB printers
  }
  final pbuf = calloc<ffi.Int8>(bufferLen + 1);  // ✓ Dynamic
  // ...
}
```

#### 2. `A_GetUSBDeviceInfo()` Completely Broken ✅
**Location**: [lib/src/printer_drivers.dart:2013-2065](lib/src/printer_drivers.dart#L2013-L2065)

**Problem**: Function was trying to SEND data instead of RECEIVE data from DLL

**Before**:
```dart
int A_GetUSBDeviceInfo(
  int nPort,
  String pDeviceName,     // ❌ Input parameter
  int pDeviceNameLen,     // ❌ Input parameter
  // ...
) {
  return _A_GetUSBDeviceInfo(
    nPort,
    pDeviceName.toNativeUtf8().cast<ffi.Int8>(),  // ❌ Sending data!
    // ...
  );
}
```

**After**:
```dart
Map<String, String> A_GetUSBDeviceInfo(int nPort) {
  const int maxNameLen = 256;
  const int maxPathLen = 512;

  // ✓ Allocate OUTPUT buffers
  final pDeviceName = calloc<ffi.Int8>(maxNameLen);
  final pDeviceNameLen = calloc<ffi.Int32>();
  pDeviceNameLen.value = maxNameLen;

  final pDevicePath = calloc<ffi.Int8>(maxPathLen);
  final pDevicePathLen = calloc<ffi.Int32>();
  pDevicePathLen.value = maxPathLen;

  try {
    final result = _A_GetUSBDeviceInfo(
      nPort,
      pDeviceName,      // ✓ Receive buffer
      pDeviceNameLen,   // ✓ Receive buffer
      pDevicePath,      // ✓ Receive buffer
      pDevicePathLen    // ✓ Receive buffer
    );

    if (result != 0) throw ArgoxException(result);

    return {
      'deviceName': pDeviceName.cast<Utf8>().toDartString(),
      'devicePath': pDevicePath.cast<Utf8>().toDartString(),
    };
  } finally {
    calloc.free(pDeviceName);
    calloc.free(pDeviceNameLen);
    calloc.free(pDevicePath);
    calloc.free(pDevicePathLen);
  }
}
```

### Discovery: Working Connection Methods

Even though `A_GetUSBBufferLen()` returns 0, we discovered these methods **DO work**:

#### Method 1: Index-based Connection ✅
```dart
int result = printer.A_CreatePort(11, 1, '');
// Result: 0 (success!)
```

#### Method 2: Device Path Connection ✅
```dart
String devicePath = r'\\?\USB#VID_1664&PID_2010#21GA0DA58205#{a5dcbf10-6530-11d2-901f-00c04fb951ed}';
int result = printer.A_CreatePrn(12, devicePath);
// Result: 0 (success!)
```

### Solution: USB Helper Class

Created [lib/src/usb_helper.dart](lib/src/usb_helper.dart) that provides:

```dart
// Auto-connect (easiest method)
bool connected = await printer.usb.autoConnect();

// List available printers
List<UsbDeviceInfo> devices = await printer.usb.getUsbPrinters();

// Connect by device path
bool connected = printer.usb.connectByDevicePath(devicePath);

// Connect by index (fallback)
bool connected = printer.usb.connectByIndex(1);
```

**How it works**:
1. Tries DLL enumeration first (`A_GetUSBDeviceInfo`)
2. Falls back to Windows PowerShell/WMI query
3. Converts Windows PnP Instance ID to USB device path format
4. Connects using device path or index

**PowerShell Query**:
```powershell
Get-PnpDevice | Where-Object {
  $_.FriendlyName -like '*Argox*' -and
  ($_.Class -eq 'Printer' -or $_.Class -eq 'USB')
}

# For USBPRINT devices, gets the USB parent:
$usbParent = Get-PnpDevice | Where-Object {
  $_.InstanceId -like 'USB\VID_1664*' -and
  $_.FriendlyName -like '*USB Printing Support*'
}

# Converts to device path:
$devicePath = "\\?\$($usbId.Replace('\', '#'))#{a5dcbf10-6530-11d2-901f-00c04fb951ed}"
```

## Root Cause Analysis

### Why `A_GetUSBBufferLen()` Returns 0

**Short Answer**: The DLL's internal enumeration only sees "raw" USB devices, but your printer is managed by Windows Print Spooler (USBPRINT class).

**Details**: See [USB_ENUMERATION_ROOT_CAUSE.md](USB_ENUMERATION_ROOT_CAUSE.md)

### Windows Device Structure

When printer is installed normally:

```
Windows Device Manager shows:

1. ARGOX iX4-250 PPLA
   Class: Printer
   InstanceId: USBPRINT\ARGOX_IX4-250_PPLA\...
   ↑ This is what you print to

2. USB Printing Support
   Class: USB
   InstanceId: USB\VID_1664&PID_2010\21GA0DA58205
   ↑ This is the actual USB hardware
```

### DLL Behavior

| Function | Uses Internal Enum | Finds USBPRINT Devices | Works With Your Setup |
|----------|-------------------|------------------------|----------------------|
| `A_GetUSBBufferLen()` | ✓ Yes | ❌ No | ❌ Returns 0 |
| `A_EnumUSB()` | ✓ Yes | ❌ No | ❌ Returns empty |
| `A_GetUSBDeviceInfo()` | ✓ Yes | ❌ No | ❌ Fails |
| `A_CreatePort(11, i, '')` | ❌ No (uses Windows API) | ✓ Yes | ✓ Works! |
| `A_CreatePrn(12, path)` | ❌ No (uses Windows API) | ✓ Yes | ✓ Works! |
| `A_CreateUSBPort(i)` | ✓ Partial | ❌ No | ❌ Fails |

**Key Insight**: The DLL has **two separate code paths**:
1. **Enumeration** - DLL's internal method (limited, only sees raw USB)
2. **Connection** - Windows API calls (comprehensive, sees all devices)

## Files Created/Modified

### New Files ✨
- ✅ [lib/src/usb_helper.dart](lib/src/usb_helper.dart) - USB helper with auto-detection
- ✅ [example/lib/usb_helper_example.dart](example/lib/usb_helper_example.dart) - Usage examples
- ✅ [example/lib/get_usb_device_path.dart](example/lib/get_usb_device_path.dart) - Device path tool
- ✅ [example/lib/deep_usb_diagnostic.dart](example/lib/deep_usb_diagnostic.dart) - Deep diagnostic
- ✅ [example/lib/discover_usb_guid.dart](example/lib/discover_usb_guid.dart) - GUID discovery
- ✅ [example/lib/simple_usb_test.dart](example/lib/simple_usb_test.dart) - Simple test
- ✅ [USB_FINAL_SOLUTION.md](USB_FINAL_SOLUTION.md) - User guide
- ✅ [USB_ENUMERATION_ROOT_CAUSE.md](USB_ENUMERATION_ROOT_CAUSE.md) - Technical analysis

### Modified Files 📝
- ✅ [lib/src/printer_drivers.dart](lib/src/printer_drivers.dart) - Fixed A_EnumUSB() and A_GetUSBDeviceInfo()
- ✅ [lib/argox_printer.dart](lib/argox_printer.dart) - Export usb_helper
- ✅ [example/windows/runner/CMakeLists.txt](example/windows/runner/CMakeLists.txt) - DLL copy

## Usage Examples

### Example 1: Auto-Connect (Recommended)
```dart
import 'package:argox_printer/argox_printer.dart';

final printer = ArgoxPPLA();

// Automatically find and connect
if (await printer.usb.autoConnect()) {
  printer.A_Set_Unit('m');
  printer.A_Clear_Memory();
  printer.A_Prn_Text(10, 10, 1, 2, 0, 1, 1, 'N', 0,
    Uint8List.fromList('Hello!'.codeUnits));
  printer.A_Print_Out(1, 1, 1, 1);
  printer.A_ClosePrn();
}
```

### Example 2: List and Select
```dart
List<UsbDeviceInfo> devices = await printer.usb.getUsbPrinters();

if (devices.isNotEmpty) {
  for (var device in devices) {
    print('${device.index}. ${device.name}');
  }

  // Connect to first
  printer.usb.connectByDevicePath(devices.first.path);
}
```

### Example 3: Direct Path
```dart
String path = r'\\?\USB#VID_1664&PID_2010#21GA0DA58205#{a5dcbf10-6530-11d2-901f-00c04fb951ed}';
printer.usb.connectByDevicePath(path);
```

### Example 4: Index Fallback
```dart
// Try connecting to first 3 printers
for (int i = 1; i <= 3; i++) {
  if (printer.usb.connectByIndex(i)) {
    print('Connected to printer $i');
    break;
  }
}
```

## Testing

Run the examples:

```bash
cd example

# Auto-connect example
flutter run -d windows lib/usb_helper_example.dart

# Get device path
flutter run -d windows lib/get_usb_device_path.dart

# Deep diagnostic
flutter run -d windows lib/deep_usb_diagnostic.dart

# Simple test
flutter run -d windows lib/simple_usb_test.dart
```

## Key Takeaways

### For Users
1. ✅ USB connection **does work** - use `printer.usb.autoConnect()`
2. ✅ Enumeration returning 0 is **expected** - not a bug
3. ✅ The solution works around the limitation automatically
4. ✅ No special printer setup required

### For Developers
1. ❌ Don't rely on `A_GetUSBBufferLen()` for device detection
2. ✅ Use `A_CreatePort(11, index, '')` for reliable connection
3. ✅ Use the USB helper class for automatic device path detection
4. ✅ PowerShell/WMI queries provide more reliable enumeration than DLL

### Technical Understanding
1. The DLL has two separate code paths (enumeration vs connection)
2. Enumeration uses internal logic (limited to raw USB devices)
3. Connection uses Windows API (works with all device types)
4. Windows Print Spooler creates USBPRINT devices, not USB devices
5. The limitation is by design, not a bug to fix

## Status

**✅ INVESTIGATION COMPLETE**

- **Original Issue**: USB not working, enumeration returning 0
- **Root Cause**: DLL enumeration limited to raw USB devices
- **Solution**: USB helper with Windows API fallback
- **Result**: Fully working USB connection with auto-detection

**Tested On**: Windows 10/11 with Argox iX4-250 PPLA
**DLL Version**: 4.11-4.12 AW (64-bit)
**Connection Methods**: All 4 methods verified
