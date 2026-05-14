# Connect to Exchange Online
$adminUPN = Read-Host "Enter your Exchange Online admin UPN (e.g., admin@domain.com)"
Connect-ExchangeOnline -UserPrincipalName $adminUPN

# Ask for the sender to add
$newSender = Read-Host "Enter the email address or identity of the sender to allow"

# Ask for group names (comma-separated)
$groupInput = Read-Host "Enter the Microsoft 365 group email addresses (comma-separated)"
$groups = $groupInput -split "," | ForEach-Object { $_.Trim() }

foreach ($group in $groups) {
    Write-Host "`nProcessing M365 Group: $group" -ForegroundColor Cyan

    # Get the group object
    $ug = Get-UnifiedGroup $group -ErrorAction SilentlyContinue
    if (-not $ug) {
        Write-Host "❌ Group not found: $group" -ForegroundColor Red
        continue
    }

    # Get current allowed senders
    $currentSenders = $ug.AcceptMessagesOnlyFrom

    # Check if sender is already in list
    $senderRecipient = Get-Recipient $newSender -ErrorAction SilentlyContinue
    if (-not $senderRecipient) {
        Write-Host "❌ Sender not found: $newSender" -ForegroundColor Red
        continue
    }

    if ($currentSenders -contains $senderRecipient) {
        Write-Host "⚠️ $newSender is already allowed for $group" -ForegroundColor Yellow
    } else {
        # Add new sender
        $updatedList = $currentSenders + $senderRecipient
        Set-UnifiedGroup $group -AcceptMessagesOnlyFrom $updatedList
        Write-Host "✅ Added $newSender to AcceptMessagesOnlyFrom for $group" -ForegroundColor Green
    }
}

# Disconnect session
Disconnect-ExchangeOnline -Confirm:$false
Write-Host "`nAll done!" -ForegroundColor Cyan

