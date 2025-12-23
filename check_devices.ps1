Get-PnpDevice | Where-Object {
  $_.FriendlyName -like '*Argox*' -or $_.InstanceId -like '*VID_1664*'
} | Format-Table FriendlyName, Class, Status, InstanceId -AutoSize
