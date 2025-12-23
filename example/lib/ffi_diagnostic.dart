import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:argox_printer/argox_printer.dart';

/// Deep FFI diagnostic to understand why A_GetUSBBufferLen returns 0 in Dart
/// but works in C/C++
void main() {
  print('=== FFI Diagnostic for A_GetUSBBufferLen ===\n');

  print('Step 1: Verify DLL Loading');
  print('=' * 60);
  testDllLoading();

  print('\nStep 2: Direct FFI Call Test');
  print('=' * 60);
  testDirectFfiCall();

  print('\nStep 3: Test with ArgoxPPLA Wrapper');
  print('=' * 60);
  testWithWrapper();

  print('\nStep 4: Test Multiple Calls');
  print('=' * 60);
  testMultipleCalls();

  print('\nStep 5: Test After Other Operations');
  print('=' * 60);
  testAfterOtherOps();
}

void testDllLoading() {
  try {
    // Try to load the DLL directly
    final String dllPath = [Directory.current.path, 'windows', 'Winppla.dll'].join('\\');
    print('Attempting to load: $dllPath');

    ffi.DynamicLibrary? library;

    // Try multiple paths
    try {
      library = ffi.DynamicLibrary.open(dllPath);
      print('✓ Loaded from: $dllPath');
    } catch (e) {
      print('✗ Failed to load from: $dllPath');
      print('  Error: $e');

      try {
        library = ffi.DynamicLibrary.open('Winppla.dll');
        print('✓ Loaded from system path');
      } catch (e2) {
        print('✗ Failed to load from system path');
        print('  Error: $e2');
        return;
      }
    }

    // Try to lookup the function
    try {
      final funcPtr = library.lookup<ffi.NativeFunction<ffi.Int32 Function()>>('A_GetUSBBufferLen');
      print('✓ Function "A_GetUSBBufferLen" found in DLL');
      print('  Function pointer: $funcPtr');

      // Try calling it directly
      final func = funcPtr.asFunction<int Function()>();
      final result = func();
      print('✓ Direct call successful');
      print('  Result: $result');

      if (result == 0) {
        print('  ⚠️  Returns 0 - either no printer OR FFI issue');
      } else {
        print('  ✓ Returns $result - printer detected!');
      }
    } catch (e) {
      print('✗ Function lookup failed: $e');
    }
  } catch (e) {
    print('✗ Unexpected error: $e');
  }
}

void testDirectFfiCall() {
  try {
    // Load library
    ffi.DynamicLibrary library;
    try {
      final dllPath = [Directory.current.path, 'windows', 'Winppla.dll'].join('\\');
      library = ffi.DynamicLibrary.open(dllPath);
    } catch (e) {
      library = ffi.DynamicLibrary.open('Winppla.dll');
    }

    // Get function pointer
    final getBufferLenPtr = library.lookup<ffi.NativeFunction<ffi.Int32 Function()>>('A_GetUSBBufferLen');
    final getBufferLen = getBufferLenPtr.asFunction<int Function()>();

    // Call multiple times
    print('Calling A_GetUSBBufferLen() 5 times:');
    for (int i = 1; i <= 5; i++) {
      final result = getBufferLen();
      print('  Call $i: $result');
    }

    // Try with buffer allocation
    final bufLen = getBufferLen();
    print('\nBuffer length: $bufLen');

    if (bufLen > 0) {
      print('Attempting A_EnumUSB with buffer size $bufLen:');

      final enumUsbPtr = library.lookup<ffi.NativeFunction<ffi.Int32 Function(ffi.Pointer<ffi.Int8>)>>('A_EnumUSB');
      final enumUsb = enumUsbPtr.asFunction<int Function(ffi.Pointer<ffi.Int8>)>();

      final buffer = calloc<ffi.Int8>(bufLen + 1);
      final result = enumUsb(buffer);

      if (result == 0) {
        final deviceList = buffer.cast<Utf8>().toDartString();
        print('  ✓ Success! Devices: "$deviceList"');
      } else {
        print('  ✗ Failed with code: $result');
      }

      calloc.free(buffer);
    } else {
      print('Buffer length is 0, cannot call A_EnumUSB');
    }
  } catch (e) {
    print('✗ Error: $e');
    print('Stack trace:');
    print(StackTrace.current);
  }
}

void testWithWrapper() {
  try {
    final printer = ArgoxPPLA();

    print('Calling A_GetUSBBufferLen() via wrapper:');
    final result = printer.A_GetUSBBufferLen();
    print('  Result: $result');

    if (result == 0) {
      print('  ⚠️  Wrapper also returns 0');
      print('  This confirms the issue is not with the wrapper itself');
    } else {
      print('  ✓ Wrapper returns $result');
    }
  } catch (e) {
    print('✗ Error: $e');
  }
}

void testMultipleCalls() {
  try {
    final printer = ArgoxPPLA();

    print('Calling A_GetUSBBufferLen() 10 times rapidly:');
    final results = <int>[];

    for (int i = 0; i < 10; i++) {
      final result = printer.A_GetUSBBufferLen();
      results.add(result);
    }

    print('  Results: $results');

    final allSame = results.every((r) => r == results.first);
    if (allSame) {
      print('  ✓ All calls return same value: ${results.first}');
    } else {
      print('  ⚠️  Inconsistent results!');
    }
  } catch (e) {
    print('✗ Error: $e');
  }
}

void testAfterOtherOps() {
  try {
    final printer = ArgoxPPLA();

    // Try calling other DLL functions first
    print('Calling other DLL functions first:');

    try {
      final version = printer.A_Get_DLL_Version(0);
      print('  DLL Version: $version');
    } catch (e) {
      print('  DLL Version failed: $e');
    }

    // Now try A_GetUSBBufferLen
    print('\nNow calling A_GetUSBBufferLen():');
    final result = printer.A_GetUSBBufferLen();
    print('  Result: $result');

    // Try after attempting connection
    print('\nAfter attempting USB connection (will fail):');
    try {
      printer.A_CreateUSBPort(1);
    } catch (e) {
      print('  Connection failed (expected): $e');
    }

    final result2 = printer.A_GetUSBBufferLen();
    print('  A_GetUSBBufferLen after connection attempt: $result2');

  } catch (e) {
    print('✗ Error: $e');
  }
}
