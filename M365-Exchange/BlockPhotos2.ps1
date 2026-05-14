# Import the Exchange Online module
Import-Module ExchangeOnlineManagement

# Connect to Exchange Online (will prompt for credentials)
Connect-ExchangeOnline

# Step 1: Check the current SetPhotoEnabled status
$policy = Get-OwaMailboxPolicy -Identity "OwaMailboxPolicy-Default"
Write-Host "Current SetPhotoEnabled status for OwaMailboxPolicy-Default: $($policy.SetPhotoEnabled)"

# Step 2: Set SetPhotoEnabled to $false (if not already set)
if ($policy.SetPhotoEnabled -eq $true) {
    Set-OwaMailboxPolicy -Identity "OwaMailboxPolicy-Default" -SetPhotoEnabled $false
    Write-Host "Updated OwaMailboxPolicy-Default to disable profile picture changes."
} else {
    Write-Host "No changes needed: SetPhotoEnabled is already set to False."
}

# Step 3: Verify the policy setting after attempting to set it
$updatedPolicy = Get-OwaMailboxPolicy -Identity "OwaMailboxPolicy-Default"
Write-Host "Verified SetPhotoEnabled status: $($updatedPolicy.SetPhotoEnabled)"

# Step 4: Check which users are assigned to the default policy
$users = Get-CASMailbox -ResultSize Unlimited | Where-Object { $_.OwaMailboxPolicy -eq "OwaMailboxPolicy-Default" }
Write-Host "Users assigned to OwaMailboxPolicy-Default: $($users.Count)"
foreach ($user in $users) {
    Write-Host " - $($user.UserPrincipalName)"
}

# Optional: Disconnect session
Disconnect-ExchangeOnline -Confirm:$false