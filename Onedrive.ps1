# Connect to Office 365
Connect-MicrosoftTeams

# Get all users in the tenancy
$users = Get-MsolUser -All

# Iterate through each user
foreach ($user in $users) {
    $displayName = $user.DisplayName
    $email = $user.UserPrincipalName

    # Check OneDrive space
    $oneDriveUsage = Get-SPOSite -Identity "https://$($user.Domain)/personal/$($user.UserPrincipalName)" |
        Select-Object -ExpandProperty Usage |
        Select-Object -ExpandProperty Storage

    Write-Host "User: $displayName ($email)"
    Write-Host "OneDrive Space Used: $($oneDriveUsage.Used/1GB) GB"
    Write-Host "OneDrive Space Allocated: $($oneDriveUsage.Allocated/1GB) GB"

    # Check licenses
    $licenses = Get-MsolUserLicense -UserPrincipalName $email |
        Select-Object -ExpandProperty AccountSkuId

    Write-Host "Licenses:"
    foreach ($license in $licenses) {
        Write-Host "- $license"
    }

    Write-Host
}

# Disconnect from Office 365
Disconnect-MicrosoftTeams