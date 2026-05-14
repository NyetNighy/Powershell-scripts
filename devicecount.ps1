# Import the Active Directory module
Import-Module ActiveDirectory

# Get all devices from Active Directory
$devices = Get-ADComputer -Filter * -Properties Name

# Count the number of devices
$deviceCount = $devices.Count

# Output the total number of devices
Write-Host "Total number of devices in Active Directory: $deviceCount"

# Display all devices with numbers
Write-Host "List of Devices:"
for ($i = 0; $i -lt $deviceCount; $i++) {
    Write-Host "$($i+1). $($devices[$i].Name)"
}

# Pause to keep the window open
Pause
