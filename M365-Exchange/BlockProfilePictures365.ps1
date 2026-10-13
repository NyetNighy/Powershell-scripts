# Requires: ExchangeOnlineManagement module
# Creates an OWA mailbox policy that disables photo updates and applies it to all licensed user mailboxes.

try {
    if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
        Write-Host "Installing ExchangeOnlineManagement module..." -ForegroundColor Yellow
        Install-Module -Name ExchangeOnlineManagement -Force -AllowClobber -Scope CurrentUser -ErrorAction Stop
    }
    Import-Module ExchangeOnlineManagement -Force -ErrorAction Stop

    Write-Host "Connecting to Exchange Online..." -ForegroundColor Cyan
    Connect-ExchangeOnline -ShowBanner:$false -ErrorAction Stop

    $policyName = "NoPhotoPolicy"

    $existing = Get-OwaMailboxPolicy -Identity $policyName -ErrorAction SilentlyContinue
    if (-not $existing) {
        New-OwaMailboxPolicy -Name $policyName -ErrorAction Stop
        Write-Host "Created OWA Mailbox Policy '$policyName'." -ForegroundColor Green
    }
    else {
        Write-Host "OWA Mailbox Policy '$policyName' already exists." -ForegroundColor Yellow
    }

    Set-OwaMailboxPolicy -Identity $policyName -SetPhotoEnabled $false -ErrorAction Stop
    Write-Host "Policy configured: SetPhotoEnabled = false." -ForegroundColor Green

    Write-Host "Retrieving licensed user mailboxes..." -ForegroundColor Cyan
    $users = Get-Mailbox -RecipientTypeDetails UserMailbox -ResultSize Unlimited -ErrorAction Stop |
        Where-Object { $_.IsLicensed -eq $true }

    if (-not $users -or $users.Count -eq 0) {
        Write-Host "No licensed user mailboxes found." -ForegroundColor Yellow
        return
    }

    $success = 0
    $failed = @()

    foreach ($user in $users) {
        try {
            Set-CASMailbox -Identity $user.UserPrincipalName -OwaMailboxPolicy $policyName -ErrorAction Stop
            Write-Host "Applied policy to: $($user.UserPrincipalName)" -ForegroundColor Green
            $success++
        }
        catch {
            Write-Host "Failed: $($user.UserPrincipalName) — $($_.Exception.Message)" -ForegroundColor Red
            $failed += $user.UserPrincipalName
        }
    }

    Write-Host "`nDone. Applied to $success of $($users.Count) users." -ForegroundColor Cyan
    if ($failed.Count -gt 0) {
        Write-Host "Failed ($($failed.Count)):" -ForegroundColor Red
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
