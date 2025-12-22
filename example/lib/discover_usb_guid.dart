import 'dart:io';

/// Discover USB device interface GUID from Windows
void main() async {
  print('=== USB Interface GUID Discovery ===\n');

  await discoverFromDeviceClasses();
  await discoverFromDevice();
  await showCommonGUIDs();
}

/// Method 1: Query device interface classes
Future<void> discoverFromDeviceClasses() async {
  print('Method 1: Device Interface Classes');
  print('-' * 50);

  try {
    final result = await Process.run(
      'powershell',
      [
        '-NoProfile',
        '-Command',
        r'''
        # Get USB printer device
        $device = Get-PnpDevice | Where-Object {
          $_.FriendlyName -like '*Argox*' -and $_.Class -eq 'USB'
        } | Select-Object -First 1

        if ($device) {
          Write-Output "Device: $($device.FriendlyName)"
          Write-Output "Instance ID: $($device.InstanceId)"
          Write-Output ""

          # List all interface GUIDs in registry
          $guidPattern = '\{[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\}'

          # Check device classes registry
          $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceClasses"
          Get-ChildItem $regPath -ErrorAction SilentlyContinue | ForEach-Object {
            $guid = $_.PSChildName
            if ($guid -match $guidPattern) {
              # Check if this GUID has entries related to our device
              $hasDevice = Get-ChildItem "$regPath\$guid" -ErrorAction SilentlyContinue |
                Where-Object { $_.PSChildName -like "*$($device.InstanceId.Split('\')[0])*" }

              if ($hasDevice) {
                Write-Output "Found GUID: $guid"
              }
            }
          }
        } else {
          Write-Output "No Argox USB device found"
        }
        ''',
      ],
    );

    if (result.exitCode == 0) {
      print(result.stdout);
    } else {
      print('Error: ${result.stderr}\n');
    }
  } catch (e) {
    print('Error: $e\n');
  }
}

/// Method 2: Query from specific device
Future<void> discoverFromDevice() async {
  print('\nMethod 2: Device Properties');
  print('-' * 50);

  try {
    final result = await Process.run(
      'powershell',
      [
        '-NoProfile',
        '-Command',
        r'''
        $device = Get-PnpDevice | Where-Object {
          $_.FriendlyName -like '*Argox*' -and $_.Class -eq 'USB'
        } | Select-Object -First 1

        if ($device) {
          # Get all device properties
          $props = Get-PnpDeviceProperty -InstanceId $device.InstanceId

          # Filter for interface-related properties
          $props | Where-Object {
            $_.KeyName -like "*Interface*" -or
            $_.KeyName -like "*GUID*" -or
            $_.KeyName -like "*Class*"
          } | Format-Table KeyName, Data -AutoSize | Out-String
        }
        ''',
      ],
    );

    if (result.exitCode == 0 && result.stdout.toString().trim().isNotEmpty) {
      print(result.stdout);
    } else {
      print('No interface properties found\n');
    }
  } catch (e) {
    print('Error: $e\n');
  }
}

/// Method 3: Show common Windows device interface GUIDs
Future<void> showCommonGUIDs() async {
  print('\nCommon Windows Device Interface GUIDs');
  print('-' * 50);

  print('''
USB Device GUIDs (Standard Windows Constants):

1. USB Printing Support (GUID_DEVINTERFACE_USB_DEVICE)
   {a5dcbf10-6530-11d2-901f-00c04fb951ed}
   ↑ This is used for USB printers

2. USB Hub Interface
   {f18a0e88-c30c-11d0-8815-00a0c906bed8}

3. USB Host Controller
   {3abf6f2d-71c4-462a-8a92-1e6861e6af27}

4. WinUSB Device Interface
   {dee824ef-729b-4a0e-9c14-b7117d33a817}

5. Printer Device Class
   {4d36e979-e325-11ce-bfc1-08002be10318}

The GUID we use ({a5dcbf10-6530-11d2-901f-00c04fb951ed}) is the
standard Windows USB Printing Support interface GUID.

This GUID is:
- Defined in Windows SDK (usbprint.h)
- A system constant (never changes)
- Required for USB printer device paths

Source: Microsoft Windows Driver Kit (WDK) documentation
''');
}
