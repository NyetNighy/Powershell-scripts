# ===== Check and install module if needed =====
if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
    Write-Host "Installing ExchangeOnlineManagement module..." -ForegroundColor Yellow
    Install-Module -Name ExchangeOnlineManagement -Force -AllowClobber -Scope CurrentUser
}

Import-Module ExchangeOnlineManagement -Force

# Connect to Exchange Online
Connect-ExchangeOnline -ShowBanner:$false

# Ask for the user who will receive Full Access
$UserToGrant = Read-Host "Enter the email address of the user/mailbox that will get Full Access"

# Ask how many target mailboxes
$count = Read-Host "How many target mailboxes do you want to grant access to?"
$count = [int]$count

$TargetMailboxes = @()
for ($i = 1; $i -le $count; $i++) {
    $mbx = Read-Host "Enter target mailbox #$i email address"
    $TargetMailboxes += $mbx
}

# Ask about AutoMapping
$autoMapInput = Read-Host "Enable AutoMapping? (Y/N) - Recommended: Y"
$AutoMapping = $autoMapInput -match '^[Yy]'

Write-Host "`nGranting Full Access to '$UserToGrant' on these mailboxes:" -ForegroundColor Cyan
$TargetMailboxes | ForEach-Object { Write-Host "  - $_" }

$confirm = Read-Host "`nProceed? (Y/N)"
if ($confirm -notmatch '^[Yy]') {
    Write-Host "Cancelled." -ForegroundColor Yellow
    return
}

foreach ($Mailbox in $TargetMailboxes) {
    try {
        Add-MailboxPermission -Identity $Mailbox `
                              -User $UserToGrant `
                              -AccessRights FullAccess `
                              -InheritanceType All `
                              -AutoMapping:$AutoMapping `
                              -ErrorAction Stop

        Write-Host "✓ Successfully granted Full Access on $Mailbox" -ForegroundColor Green
    }
    catch {
        Write-Host "✗ Failed on $Mailbox : $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`nDone." -ForegroundColor Cyan