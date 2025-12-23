# Action Plan: Fix A_GetUSBBufferLen FFI Issue

## Summary

**Problem:** `A_GetUSBBufferLen()` returns 0 in Dart FFI but works correctly in C/C++
**Impact:** USB enumeration doesn't work via DLL, but workarounds are in place
**Status:** Root cause unknown, needs diagnosis on system with printer

## What We Know

✅ **Confirmed Facts:**
1. C/C++ code calling DLL works correctly
2. `A_GetUSBBufferLen()` returns correct value in C/C++
3. `A_EnumUSB()` returns device list in C/C++
4. Dart FFI binding returns 0 for same function
5. Printer path from C++: `\\?\USB#VID_1664&PID_2010#21GA0DA58205#{a5dcbf10-6530-11d2-901f-00c04fb951ed}`

❓ **Unknown:**
1. Is this a calling convention issue?
2. Does DLL require specific initialization?
3. Is there a thread context issue?
4. Does `A_GetUSBDeviceInfo` work in Dart FFI when called directly?

## Immediate Actions (On System WITH Printer)

### Step 1: Run FFI Diagnostic

```bash
cd f:\Windows\Projects\argox_printer\example
flutter run -d windows lib\ffi_diagnostic.dart
```

**Expected Output:**
- DLL loading status
- Function pointer address
- Direct FFI call result
- Multiple call consistency

**What to Look For:**
- Does direct FFI call also return 0?
- Are results consistent across multiple calls?
- Does calling other functions first change the result?

### Step 2: Check DLL Exports (Calling Convention)

```cmd
cd f:\Windows\Projects\argox_printer\example\windows

# If you have Visual Studio installed:
dumpbin /EXPORTS Winppla.dll | findstr A_GetUSBBufferLen

# Save full export list:
dumpbin /EXPORTS Winppla.dll > exports.txt
```

**Look for:**
```
# __stdcall (expected):
_A_GetUSBBufferLen@0

# __cdecl (might be the issue):
A_GetUSBBufferLen

# __fastcall (unlikely):
@A_GetUSBBufferLen@0
```

### Step 3: Test A_GetUSBDeviceInfo Directly

Create a simple test file:

```dart
// test_direct_device_info.dart
import 'package:argox_printer/argox_printer.dart';

void main() {
  final printer = ArgoxPPLA();

  print('Testing A_GetUSBDeviceInfo directly...\n');

  // Skip A_GetUSBBufferLen completely
  for (int i = 1; i <= 5; i++) {
    try {
      print('Trying device index $i...');
      Map<String, String> info = printer.A_GetUSBDeviceInfo(i);

      print('  ✓ Found device!');
      print('  Name: ${info['deviceName']}');
      print('  Path: ${info['devicePath']}');
      print('');
    } catch (e) {
      print('  ✗ No device at index $i');
      print('  Error: $e');
      break;
    }
  }
}
```

Run:
```bash
flutter run -d windows test_direct_device_info.dart
```

**What This Tests:**
- Whether `A_GetUSBDeviceInfo` works independently
- Whether we can skip `A_GetUSBBufferLen` entirely

### Step 4: Compare with C++ Code

In your working C++ code, add detailed logging:

```cpp
printf("=== C++ DLL Call Test ===\n");
printf("Function address: %p\n", &A_GetUSBBufferLen);

int bufLen = A_GetUSBBufferLen();
printf("A_GetUSBBufferLen result: %d\n", bufLen);

if (bufLen > 0) {
    char *buf = new char[bufLen + 1];
    int result = A_EnumUSB(buf);
    printf("A_EnumUSB result: %d\n", result);
    printf("Device list: %s\n", buf);
    delete[] buf;
}
```

Compare output with Dart FFI diagnostic output.

## Potential Fixes

### Fix Option 1: Use A_GetUSBDeviceInfo Directly (Already Implemented)

I've already added a workaround in `usb_helper.dart` that tries calling `A_GetUSBDeviceInfo(1..5)` directly if `A_GetUSBBufferLen` returns 0.

**Test this first** - it might already work!

```dart
// This should work now:
final printer = ArgoxPPLA();
List<UsbDeviceInfo> devices = await printer.usb.getUsbPrinters();
print('Found ${devices.length} devices');
```

### Fix Option 2: Initialize DLL State First

If the DLL needs initialization:

```dart
class ArgoxPPLA extends ArgoxLibrary {
  bool _initialized = false;

  int A_GetUSBBufferLen() {
    // Ensure DLL is initialized
    if (!_initialized) {
      _initializeDll();
    }
    return _A_GetUSBBufferLen();
  }

  void _initializeDll() {
    try {
      // Try calling initialization functions
      A_Get_DLL_Version(0);
      _initialized = true;
    } catch (_) {
      // Initialization failed
    }
  }
}
```

### Fix Option 3: Create Wrapper DLL (Last Resort)

If calling convention is the issue and we can't fix it in Dart:

```cpp
// argox_wrapper.cpp
extern "C" {
  __declspec(dllexport) int __stdcall GetUSBBufferLen_Wrapper() {
    typedef int (__cdecl *FuncType)();
    HMODULE dll = LoadLibrary("Winppla.dll");
    FuncType func = (FuncType)GetProcAddress(dll, "A_GetUSBBufferLen");
    int result = func();
    FreeLibrary(dll);
    return result;
  }
}
```

Compile as DLL and use in Dart:
```dart
late final _A_GetUSBBufferLenPtr =
    _lookup<ffi.NativeFunction<ffi.Int32 Function()>>('GetUSBBufferLen_Wrapper');
```

## Testing Checklist

On system **WITH** Argox printer connected:

- [ ] Run `ffi_diagnostic.dart` and save output
- [ ] Check `dumpbin /EXPORTS` for calling convention
- [ ] Test `A_GetUSBDeviceInfo` directly
- [ ] Test updated `usb.getUsbPrinters()` with new workaround
- [ ] Compare C++ vs Dart output
- [ ] Test if calling other DLL functions first helps
- [ ] Test `usb.autoConnect()` - does it work now?

## Expected Results After Fix

Once we identify and fix the issue:

```dart
final printer = ArgoxPPLA();

// This should return > 0:
int bufferLen = printer.A_GetUSBBufferLen();
assert(bufferLen > 0);

// This should return device names:
String devices = printer.A_EnumUSB();
assert(devices.contains('ARGOX'));

// This should work:
Map<String, String> info = printer.A_GetUSBDeviceInfo(1);
assert(info['devicePath'] == r'\\?\USB#VID_1664&PID_2010#21GA0DA58205#{a5dcbf10-6530-11d2-901f-00c04fb951ed}');

// This should work:
List<UsbDeviceInfo> list = await printer.usb.getUsbPrinters();
assert(list.isNotEmpty);

// This should work:
bool connected = await printer.usb.autoConnect();
assert(connected);
```

## Files to Review

Diagnostic files created:
- [ffi_diagnostic.dart](example/lib/ffi_diagnostic.dart) - FFI call testing
- [FFI_ISSUE_ANALYSIS.md](FFI_ISSUE_ANALYSIS.md) - Detailed analysis
- [ACTION_PLAN.md](ACTION_PLAN.md) - This file

Code changes:
- [usb_helper.dart:65-89](lib/src/usb_helper.dart#L65-L89) - Added direct `A_GetUSBDeviceInfo` fallback

## Communication Plan

Once you run the diagnostics:

1. Share the output from `ffi_diagnostic.dart`
2. Share the `dumpbin /EXPORTS` output (if available)
3. Share whether `A_GetUSBDeviceInfo` works directly
4. Share whether the updated `usb_helper` works now

With this information, we can:
- Identify the exact root cause
- Implement the appropriate fix
- Potentially contact Argox support if it's a DLL issue

## Quick Test (Try This First!)

On the system with the printer:

```bash
cd f:\Windows\Projects\argox_printer\example
flutter run -d windows
```

Then in your app:
```dart
final printer = ArgoxPPLA();

// Test the updated helper
List<UsbDeviceInfo> devices = await printer.usb.getUsbPrinters();

if (devices.isNotEmpty) {
  print('✓ SUCCESS! Found ${devices.length} device(s)');
  for (var device in devices) {
    print('  - ${device.name}');
    print('    Path: ${device.path}');
  }

  // Try connecting
  if (await printer.usb.autoConnect()) {
    print('✓ Connected successfully!');
  }
} else {
  print('✗ Still not working - need more diagnostics');
}
```

**If this works**, the FFI issue is bypassed and you're done!

**If this doesn't work**, proceed with full diagnostics above.

---

**Priority:** High
**Blockers:** Need access to system with connected Argox printer
**Next Review:** After diagnostic results are available
