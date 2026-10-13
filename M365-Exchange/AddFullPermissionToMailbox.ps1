# Grant Full Access (optional AutoMapping) to one user on one or more target mailboxes.

try {
    if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
        Write-Host "Installing ExchangeOnlineManagement module..." -ForegroundColor Yellow
        Install-Module -Name ExchangeOnlineManagement -Force -AllowClobber -Scope CurrentUser -ErrorAction Stop
    }
    Import-Module ExchangeOnlineManagement -Force -ErrorAction Stop

    Write-Host "Connecting to Exchange Online..." -ForegroundColor Cyan
    Connect-ExchangeOnline -ShowBanner:$false -ErrorAction Stop

    $UserToGrant = Read-Host "Enter the email address of the user/mailbox that will get Full Access"
    if ([string]::IsNullOrWhiteSpace($UserToGrant)) {
        Write-Host "No user specified. Cancelled." -ForegroundColor Yellow
        return
    }

    $countInput = Read-Host "How many target mailboxes do you want to grant access to?"
    $count = 0
    if (-not [int]::TryParse($countInput, [ref]$count) -or $count -lt 1) {
        Write-Host "Invalid count. Cancelled." -ForegroundColor Yellow
        return
    }

    $TargetMailboxes = @()
    for ($i = 1; $i -le $count; $i++) {
        $mbx = Read-Host "Enter target mailbox #$i email address"
        if (-not [string]::IsNullOrWhiteSpace($mbx)) {
            $TargetMailboxes += $mbx.Trim()
        }
    }

    if ($TargetMailboxes.Count -eq 0) {
        Write-Host "No target mailboxes entered. Cancelled." -ForegroundColor Yellow
        return
    }

    $autoMapInput = Read-Host "Enable AutoMapping? (Y/N) - Recommended: Y"
    $AutoMapping = $autoMapInput -match '^[Yy]'

    Write-Host "`nGranting Full Access to '$UserToGrant' on these mailboxes:" -ForegroundColor Cyan
    $TargetMailboxes | ForEach-Object { Write-Host "  - $_" }

    $confirm = Read-Host "`nProceed? (Y/N)"
    if ($confirm -notmatch '^[Yy]') {
        Write-Host "Cancelled." -ForegroundColor Yellow
        return
    }

    $success = 0
    $failed = @()

    foreach ($Mailbox in $TargetMailboxes) {
        try {
            Add-MailboxPermission -Identity $Mailbox `
                                  -User $UserToGrant `
                                  -AccessRights FullAccess `
                                  -InheritanceType All `
                                  -AutoMapping:$AutoMapping `
                                  -ErrorAction Stop

            Write-Host "Successfully granted Full Access on $Mailbox" -ForegroundColor Green
            $success++
        }
        catch {
            Write-Host "Failed on $Mailbox : $($_.Exception.Message)" -ForegroundColor Red
            $failed += $Mailbox
        }
    }

    Write-Host "`nDone. Success: $success / $($TargetMailboxes.Count)" -ForegroundColor Cyan
    if ($failed.Count -gt 0) {
        Write-Host "Failed:" -ForegroundColor Red
        $failed | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    }
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}
finally {
    try {
        Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
    }
    catch { }
}
