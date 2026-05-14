# Import the Active Directory module
Import-Module ActiveDirectory

# Get all devices from Active Directory
$devices = Get-ADComputer -Filter * -Properties Name

# Count the number of devices
$deviceCount = $devices.Count

# Output the result
Write-Host "Total number of devices in Active Directory: $deviceCount"
