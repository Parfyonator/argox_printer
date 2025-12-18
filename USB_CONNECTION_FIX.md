# USB Connection Fix - Summary

## Problems Identified

Your USB connection wasn't working due to **three critical bugs** in the FFI implementation:

### 1. ❌ `A_EnumUSB()` - Fixed Buffer Allocation Issue
**Location**: [lib/src/printer_drivers.dart:1649-1667](lib/src/printer_drivers.dart#L1649-L1667)

**Problem**:
- Hard-coded 128-byte buffer that was too small for multiple USB devices
- Didn't check buffer requirements before allocation

**Fix**:
```dart
String A_EnumUSB() {
  // Get the required buffer size first
  final bufferLen = A_GetUSBBufferLen();
  if (bufferLen <= 0) {
    throw ArgoxException(4001); // No USB Printer Connect
  }

  // Allocate buffer with enough space
  final pbuf = calloc<ffi.Int8>(bufferLen + 1);
  final result = _A_EnumUSB(pbuf);
  final ret = pbuf.cast<Utf8>().toDartString();
  calloc.free(pbuf);

  if (result != 0) {
    throw ArgoxException(result);
  }
  return ret;
}
```

### 2. ❌ `A_GetUSBDeviceInfo()` - Completely Broken Implementation
**Location**: [lib/src/printer_drivers.dart:2013-2065](lib/src/printer_drivers.dart#L2013-L2065)

**Problem**:
- Function was trying to **send** string data instead of **receiving** it
- Parameters were input strings instead of output buffers
- Incorrect pointer conversion (`toString().toNativeUtf8().cast<ffi.Int32>()`)

**Old (Broken) Code**:
```dart
int A_GetUSBDeviceInfo(
  int nPort,
  String pDeviceName,      // ❌ Should be output buffer
  int pDeviceNameLen,      // ❌ Should be pointer
  String pDevicePath,      // ❌ Should be output buffer
  int pDevicePathLen,      // ❌ Should be pointer
) {
  return _A_GetUSBDeviceInfo(
    nPort,
    pDeviceName.toNativeUtf8().cast<ffi.Int8>(),  // ❌ Wrong!
    pDeviceNameLen.toString().toNativeUtf8().cast<ffi.Int32>(),  // ❌ Wrong!
    // ...
  );
}
```

**New (Fixed) Code**:
```dart
Map<String, String> A_GetUSBDeviceInfo(int nPort) {
  const int maxNameLen = 256;
  const int maxPathLen = 512;

  // Allocate output buffers
  final pDeviceName = calloc<ffi.Int8>(maxNameLen);
  final pDeviceNameLen = calloc<ffi.Int32>();
  pDeviceNameLen.value = maxNameLen;

  final pDevicePath = calloc<ffi.Int8>(maxPathLen);
  final pDevicePathLen = calloc<ffi.Int32>();
  pDevicePathLen.value = maxPathLen;

  try {
    final result = _A_GetUSBDeviceInfo(
      nPort,
      pDeviceName,
      pDeviceNameLen,
      pDevicePath,
      pDevicePathLen,
    );

    if (result != 0) {
      throw ArgoxException(result);
    }

    return {
      'deviceName': pDeviceName.cast<Utf8>().toDartString(),
      'devicePath': pDevicePath.cast<Utf8>().toDartString(),
    };
  } finally {
    // Always free allocated memory
    calloc.free(pDeviceName);
    calloc.free(pDeviceNameLen);
    calloc.free(pDevicePath);
    calloc.free(pDevicePathLen);
  }
}
```

### 3. ℹ️ Unclear USB Connection Methods

The library provides **multiple ways** to connect via USB, which wasn't documented clearly.

---

## How to Use USB Connections (Fixed)

### Method 1: Simple Connection by Index (Recommended)

```dart
final printer = ArgoxPPLA();

try {
  // Connect to first USB printer
  printer.A_CreateUSBPort(1);  // Index starts from 1

  // Print something
  printer.A_Set_Unit('m');
  printer.A_Clear_Memory();
  printer.A_Prn_Text(10, 10, 1, 2, 0, 1, 1, 'N', 0,
    Uint8List.fromList('Hello USB!'.codeUnits));
  printer.A_Print_Out(1, 1, 1, 1);

  printer.A_ClosePrn();
} catch (e) {
  print('Error: $e');
}
```

### Method 2: Enumerate First, Then Connect

```dart
final printer = ArgoxPPLA();

try {
  // Check if USB printers exist
  int bufferLen = printer.A_GetUSBBufferLen();

  if (bufferLen > 0) {
    // Get list of USB printers
    String usbPrinters = printer.A_EnumUSB();
    print('Found: $usbPrinters');

    // Parse printer list (separated by \r\n)
    List<String> printers = usbPrinters
      .split('\r\n')
      .where((s) => s.isNotEmpty)
      .toList();

    print('Available printers:');
    for (int i = 0; i < printers.length; i++) {
      print('  [$i] ${printers[i]}');
    }

    // Connect to first printer
    printer.A_CreateUSBPort(1);
    print('Connected to: ${printers[0]}');

    // ... your printing code ...

    printer.A_ClosePrn();
  } else {
    print('No USB printers found');
  }
} catch (e) {
  print('Error: $e');
}
```

### Method 3: Get Detailed Device Info

```dart
final printer = ArgoxPPLA();

try {
  int bufferLen = printer.A_GetUSBBufferLen();

  if (bufferLen > 0) {
    String usbList = printer.A_EnumUSB();
    List<String> printers = usbList.split('\r\n').where((s) => s.isNotEmpty).toList();

    // Get detailed info for each printer
    for (int i = 1; i <= printers.length; i++) {
      Map<String, String> info = printer.A_GetUSBDeviceInfo(i);
      print('Printer $i:');
      print('  Name: ${info['deviceName']}');
      print('  Path: ${info['devicePath']}');
    }

    // Connect using device path (alternative method)
    Map<String, String> firstPrinter = printer.A_GetUSBDeviceInfo(1);
    printer.A_CreatePrn(12, firstPrinter['devicePath']!);

    // ... your printing code ...

    printer.A_ClosePrn();
  }
} catch (e) {
  print('Error: $e');
}
```

### Method 4: Using A_CreatePrn (Alternative)

```dart
final printer = ArgoxPPLA();

// Option A: USB by index
printer.A_CreatePrn(11, '1');  // Connect to first USB printer

// Option B: USB by device path
printer.A_CreatePrn(12, 'USB_DEVICE_PATH_HERE');

// ... your printing code ...

printer.A_ClosePrn();
```

### Method 5: Using A_CreatePort (Unified Method)

```dart
final printer = ArgoxPPLA();

// nPortType = 11 for USB by index
// nPort = printer index (1, 2, 3...)
printer.A_CreatePort(11, 1, '');

// ... your printing code ...

printer.A_ClosePrn();
```

---

## Common Error Codes

| Code | Error | Solution |
|------|-------|----------|
| 4001 | No USB Printer Connect | Check USB cable, install drivers |
| 4002 | USB port number out of range | Use valid index (1, 2, 3...) |
| 2042 | Memory allocation failed | Reduce buffer size or free memory |
| 118 | USB printer does not exist | Verify printer is powered on |
| 119 | Specified USB port not found | Check port index is valid |

---

## Testing Your Fix

Run the comprehensive example:

```bash
cd example
flutter run -d windows
```

Or run the USB-specific example:

```dart
// See example/lib/usb_example.dart for full code
import 'package:argox_printer/argox_printer.dart';

void main() {
  final printer = ArgoxPPLA();

  try {
    printer.A_CreateUSBPort(1);
    printer.A_Set_Unit('m');
    printer.A_Clear_Memory();

    final text = Uint8List.fromList('USB Test'.codeUnits);
    printer.A_Prn_Text(10, 10, 1, 2, 0, 1, 1, 'N', 0, text);
    printer.A_Print_Out(1, 1, 1, 1);

    printer.A_ClosePrn();
    print('✓ Print successful!');
  } catch (e) {
    print('✗ Error: $e');
  }
}
```

---

## Why Network and LPT Worked But USB Didn't

### Network Connection
- Uses `A_CreatePrn(13, '192.168.1.100')` or `A_CreateNetPort(1)`
- Simple string parameter (IP address)
- No complex buffer management needed ✅

### LPT (Parallel) Connection
- Uses `A_CreatePrn(1, '')` for LPT1
- No device enumeration required
- Direct port access ✅

### USB Connection (Was Broken)
- Required enumeration: `A_EnumUSB()`
- Needed buffer size check: `A_GetUSBBufferLen()`
- Device info retrieval was broken: `A_GetUSBDeviceInfo()`
- Buffer management had bugs ❌

---

## Files Modified

1. **[lib/src/printer_drivers.dart](lib/src/printer_drivers.dart)**
   - Fixed `A_EnumUSB()` buffer allocation
   - Completely rewrote `A_GetUSBDeviceInfo()`

2. **[example/lib/usb_example.dart](example/lib/usb_example.dart)** (NEW)
   - Comprehensive USB connection examples
   - All 5 connection methods demonstrated
   - Error handling examples

---

## Next Steps

1. **Test the fixes** with your actual USB printer
2. **Try different connection methods** to see which works best
3. **Report results** - does it work now?

If you still have issues, please share:
- Error codes/messages
- Which connection method you're using
- Output of `A_EnumUSB()` and `A_GetUSBBufferLen()`
