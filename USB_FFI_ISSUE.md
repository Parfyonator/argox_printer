# USB FFI Issue & Workaround

## Summary

**Issue:** `A_GetUSBBufferLen()` and `A_GetUSBDeviceInfo()` return 0/fail in Dart FFI even when Argox printer is connected, but work correctly in C/C++.

**Root Cause:** Calling convention mismatch - DLL uses `__cdecl` convention, Dart FFI defaults to `__stdcall` on Windows.

**Solution:** Implemented workaround in `usb_helper.dart` using Windows WMI queries as fallback.

**Status:** ✅ Resolved via workaround. USB functionality works perfectly.

## The Problem

### What Doesn't Work

When calling these DLL functions from Dart FFI:

```dart
int bufferLen = printer.A_GetUSBBufferLen();
// Expected: > 0 (size of device list buffer)
// Actual: 0 (always returns 0)

Map<String, String> info = printer.A_GetUSBDeviceInfo(1);
// Expected: Device name and path
// Actual: Throws exception
```

### What Works in C/C++

The same DLL functions work correctly in C/C++ code:

```cpp
int bufferLen = A_GetUSBBufferLen();
// Returns: 20 (or similar positive value)

char buf[bufferLen + 1];
A_EnumUSB(buf);
// Returns: "ARGOX iX4-250 PPLA\r\n"
```

## Technical Root Cause

### Calling Convention Mismatch

Windows DLLs can use different calling conventions:

| Convention | Stack Cleanup | Export Name | Dart FFI Default |
|------------|---------------|-------------|------------------|
| `__stdcall` | Callee cleans | `_FuncName@N` | ✅ Supported |
| `__cdecl` | Caller cleans | `FuncName` | ❌ Not default |

**The Argox DLL exports functions as undecorated names** (e.g., `A_GetUSBBufferLen`), indicating `__cdecl` convention.

**Dart FFI assumes `__stdcall`** by default on Windows, causing:
- Stack corruption
- Wrong return values (often 0)
- Parameter misalignment

### Affected Functions

FFI Issue confirmed in:
- ❌ `A_GetUSBBufferLen()` - Returns 0 instead of buffer size
- ❌ `A_EnumUSB()` - Cannot be called (depends on A_GetUSBBufferLen)
- ❌ `A_GetUSBDeviceInfo()` - Throws exception

Functions that work correctly:
- ✅ `A_CreatePort()` - Works
- ✅ `A_CreatePrn()` - Works
- ✅ `A_Print_Out()` - Works
- ✅ Most other DLL functions - Work

## The Workaround

### Implementation

Located in [lib/src/usb_helper.dart](lib/src/usb_helper.dart), the USB helper uses a multi-method fallback approach:

```dart
Future<List<UsbDeviceInfo>> getUsbPrinters() async {
  // Method 1: Try DLL enumeration (fails due to FFI issue)
  try {
    int bufferLen = _printer.A_GetUSBBufferLen();
    if (bufferLen > 0) {
      String usbList = _printer.A_EnumUSB();
      // Parse and return devices
    }
  } catch (_) {}

  // Method 2: Try A_GetUSBDeviceInfo directly (also fails due to FFI)
  try {
    for (int i = 1; i <= 5; i++) {
      Map<String, String> info = _printer.A_GetUSBDeviceInfo(i);
      // Add to device list
    }
  } catch (_) {}

  // Method 3: Windows WMI Query (THIS WORKS!)
  final result = await Process.run('powershell', [
    '-Command',
    '''
    Get-PnpDevice | Where-Object {
      $_.FriendlyName -like '*Argox*' -and
      ($_.Class -eq 'Printer' -or $_.Class -eq 'USB')
    }
    # Convert to device path format
    '''
  ]);
  // Parse and return devices
}
```

### Why This Works

The Windows PowerShell query:
1. ✅ Uses Windows native APIs (no DLL calls)
2. ✅ Finds all USB printers regardless of driver type
3. ✅ Returns correct device paths
4. ✅ No FFI issues

### Usage

Users don't need to know about the FFI issue - it's handled transparently:

```dart
final printer = ArgoxPPLA();

// Automatically uses workaround
bool connected = await printer.usb.autoConnect();

if (connected) {
  // Print normally
  printer.A_Print_Out(1, 1, 1, 1);
  printer.A_ClosePrn();
}
```

## Test Results

### System Configuration
- **OS:** Windows 10/11
- **Printer:** Argox iX4-250 PPLA connected via USB
- **DLL Version:** 4.12 AW (64-bit)

### Test Results

| Test | Result | Details |
|------|--------|---------|
| `A_GetUSBBufferLen()` | ❌ Returns 0 | FFI issue confirmed |
| `A_GetUSBDeviceInfo()` | ❌ Exception | FFI issue confirmed |
| `usb.getUsbPrinters()` | ✅ Success | Found 1 device via PowerShell |
| `usb.autoConnect()` | ✅ Success | Connected successfully |
| Printing | ✅ Success | Label printed correctly |

**Conclusion:** Workaround is fully functional. USB operations work perfectly despite DLL enumeration issues.

## Future Fix (Optional)

If you want to fix the DLL enumeration (not necessary, but possible):

### Option 1: Wrapper DLL

Create a thin C++ wrapper that translates calling conventions:

```cpp
// argox_wrapper.cpp
extern "C" {
    // Export with __stdcall for Dart
    __declspec(dllexport) int __stdcall A_GetUSBBufferLen_Wrapper() {
        // Load original DLL
        HMODULE hDll = LoadLibrary("Winppla.dll");

        // Get function with __cdecl convention
        typedef int (__cdecl *GetUSBBufferLen_cdecl)();
        GetUSBBufferLen_cdecl func =
            (GetUSBBufferLen_cdecl)GetProcAddress(hDll, "A_GetUSBBufferLen");

        // Call and return
        int result = func();
        FreeLibrary(hDll);
        return result;  // Now returned via __stdcall
    }
}
```

Compile and use in Dart:
```dart
late final _A_GetUSBBufferLen =
    _lookup<ffi.NativeFunction<ffi.Int32 Function()>>('A_GetUSBBufferLen_Wrapper');
```

### Option 2: Contact Argox

Request an updated DLL with:
- `__stdcall` calling convention for better Windows FFI compatibility
- Or explicitly decorated exports for both conventions

### Option 3: Keep Current Workaround (Recommended)

The PowerShell workaround:
- ✅ Works reliably
- ✅ No additional dependencies
- ✅ No compilation needed
- ✅ Easier to maintain

## Diagnostic Tools

If you need to investigate similar FFI issues in the future:

### Check DLL Exports

```powershell
# If Visual Studio installed:
dumpbin /EXPORTS Winppla.dll | findstr A_GetUSBBufferLen

# Look for:
#   A_GetUSBBufferLen          → __cdecl (causes FFI issues)
#   _A_GetUSBBufferLen@0       → __stdcall (works with FFI)
```

### Test FFI Calls

Run the diagnostic tool (located in example/lib):

```bash
cd example
flutter run -d windows -t lib/ffi_diagnostic.dart
```

This tests:
- DLL loading
- Function pointer validity
- Direct FFI call results
- Consistency across multiple calls

## Related Files

### Implementation
- [lib/src/usb_helper.dart](lib/src/usb_helper.dart) - USB helper with workaround
- [lib/src/printer_drivers.dart](lib/src/printer_drivers.dart) - FFI bindings

### Documentation
- [README.md](README.md#usb-printer-auto-detection-recommended) - Usage examples
- [DOCUMENTATION.md](DOCUMENTATION.md) - Complete API reference

### Diagnostics (example/lib)
- `ffi_diagnostic.dart` - FFI call testing tool

---

**Document Version:** 1.0
**Last Updated:** 2025-12-23
**Status:** Issue resolved via workaround. Optional future fix available if needed.
