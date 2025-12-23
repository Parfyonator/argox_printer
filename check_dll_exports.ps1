# PowerShell script to check DLL exports without dumpbin
param([string]$DllPath = ".\example\windows\Winppla.dll")

Write-Host "=== Checking DLL Exports ===" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $DllPath)) {
    Write-Host "Error: DLL not found at $DllPath" -ForegroundColor Red
    exit 1
}

Write-Host "DLL Path: $DllPath" -ForegroundColor Yellow
Write-Host ""

try {
    # Load DLL checking functions
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class DllExports {
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr LoadLibrary(string lpFileName);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr GetProcAddress(IntPtr hModule, string lpProcName);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool FreeLibrary(IntPtr hModule);
}
"@

    $fullPath = Resolve-Path $DllPath
    Write-Host "Loading DLL: $fullPath" -ForegroundColor Yellow

    $hModule = [DllExports]::LoadLibrary($fullPath)

    if ($hModule -eq [IntPtr]::Zero) {
        Write-Host "Failed to load DLL" -ForegroundColor Red
        exit 1
    }

    Write-Host "Success: DLL loaded" -ForegroundColor Green
    Write-Host ""
    Write-Host "Checking function exports:" -ForegroundColor Cyan
    Write-Host ""

    # Check for specific functions
    $functionsToCheck = @(
        "A_GetUSBBufferLen",
        "_A_GetUSBBufferLen@0",
        "A_EnumUSB",
        "_A_EnumUSB@4",
        "A_GetUSBDeviceInfo",
        "_A_GetUSBDeviceInfo@20"
    )

    $found = @{}

    foreach ($funcName in $functionsToCheck) {
        $addr = [DllExports]::GetProcAddress($hModule, $funcName)
        if ($addr -ne [IntPtr]::Zero) {
            Write-Host "  Found: $funcName" -ForegroundColor Green
            Write-Host "    Address: 0x$($addr.ToString('X'))" -ForegroundColor Gray
            $found[$funcName] = $addr
        }
    }

    Write-Host ""
    Write-Host "Analysis:" -ForegroundColor Cyan
    Write-Host ""

    if ($found.ContainsKey("A_GetUSBBufferLen")) {
        Write-Host "  A_GetUSBBufferLen found (undecorated)" -ForegroundColor Green
        Write-Host "  This suggests __cdecl calling convention" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  POTENTIAL ISSUE:" -ForegroundColor Red
        Write-Host "    Dart FFI defaults to __stdcall on Windows" -ForegroundColor Yellow
        Write-Host "    DLL uses __cdecl" -ForegroundColor Yellow
        Write-Host "    This mismatch could cause wrong return values" -ForegroundColor Yellow
    } elseif ($found.ContainsKey("_A_GetUSBBufferLen@0")) {
        Write-Host "  _A_GetUSBBufferLen@0 found (decorated)" -ForegroundColor Green
        Write-Host "  This indicates __stdcall calling convention" -ForegroundColor Yellow
        Write-Host "  Dart FFI should work correctly" -ForegroundColor Green
    } else {
        Write-Host "  A_GetUSBBufferLen not found" -ForegroundColor Red
    }

    [void][DllExports]::FreeLibrary($hModule)

} catch {
    Write-Host "Error: $_" -ForegroundColor Red
}

Write-Host ""
