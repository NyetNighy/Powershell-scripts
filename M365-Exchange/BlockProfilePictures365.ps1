# Import the Exchange Online module
Import-Module ExchangeOnlineManagement

# Connect to Exchange Online (will prompt for credentials)
Connect-ExchangeOnline

# Step 1: Create a new OWA Mailbox Policy with photo setting disabled
New-OwaMailboxPolicy -Name "NoPhotoPolicy"
Set-OwaMailboxPolicy -Identity "NoPhotoPolicy" -SetPhotoEnabled $false

Write-Host "OWA Mailbox Policy 'NoPhotoPolicy' created and configured to disable photo updates."

$users = Get-Mailbox -RecipientTypeDetails UserMailbox -ResultSize Unlimited | Where-Object { $_.IsLicensed -eq $true }

# Apply the policy
foreach ($user in $users) {
    Set-CASMailbox -Identity $user.UserPrincipalName -OwaMailboxPolicy "NoPhotoPolicy"
    Write-Host "Applied policy to: $($user.UserPrincipalName)"
}

Write-Host "Policy applied to $($users.Count) users."

# Optional: Disconnect session
Disconnect-ExchangeOnline -Confirm:$false

