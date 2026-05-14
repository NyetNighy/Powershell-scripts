Import-Module ActiveDirectory
$CutoffDate = (Get-Date).AddDays(-365)
$report = Get-ADUser -Filter {
    LastLogonTimeStamp -lt $CutoffDate -and 
    Enabled -eq $true
} -Properties LastLogonTimeStamp, whenCreated, Description |
    Select-Object Name, 
                  SamAccountName, 
                  UserPrincipalName,
                  Enabled,
                  @{Name = 'Last Logon'; Expression = {
                      if ($_.LastLogonTimeStamp) {
                          [DateTime]::FromFileTime($_.LastLogonTimeStamp)
                      } else { "Never" }
                  }},
                  @{Name = 'Account Created'; Expression = { $_.whenCreated }},
                  Description |
    Sort-Object 'Last Logon'
$report | Format-Table -AutoSize
$report | Export-Csv "C:\Temp\InactiveUsers_Over1Year.csv" -NoTypeInformation -Encoding UTF8