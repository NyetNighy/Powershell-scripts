#Requires -Version 5.1
<#
.SYNOPSIS
    Create an OWA mailbox policy that disables photo updates and apply it to licensed user mailboxes.
    Prompts for policy name, scope, and confirmation before applying.
#>

$ErrorActionPreference = "Stop"

try {
    if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
        Write-Host "Installing ExchangeOnlineManagement module..." -ForegroundColor Yellow
        Install-Module -Name ExchangeOnlineManagement -Force -AllowClobber -Scope CurrentUser -ErrorAction Stop
    }
    Import-Module ExchangeOnlineManagement -Force -ErrorAction Stop

    Write-Host "Connecting to Exchange Online..." -ForegroundColor Cyan
    Connect-ExchangeOnline -ShowBanner:$false -ErrorAction Stop

    $policyName = Read-Host "OWA policy name (default: NoPhotoPolicy)"
    if ([string]::IsNullOrWhiteSpace($policyName)) { $policyName = "NoPhotoPolicy" }
    $policyName = $policyName.Trim()

    Write-Host "`nScope:" -ForegroundColor Cyan
    Write-Host "  1 = All licensed user mailboxes"
    Write-Host "  2 = Single mailbox (by UPN/email)"
    $scope = Read-Host "Enter 1 or 2"
    if ($scope -notin @("1", "2")) {
        Write-Host "Invalid choice. Cancelled." -ForegroundColor Yellow
        return
    }

    $singleId = $null
    if ($scope -eq "2") {
        $singleId = Read-Host "Enter mailbox UPN or email"
        if ([string]::IsNullOrWhiteSpace($singleId)) { throw "Mailbox identity is required." }
        $singleId = $singleId.Trim()
    }

    $existing = Get-OwaMailboxPolicy -Identity $policyName -ErrorAction SilentlyContinue
    if (-not $existing) {
        Write-Host "Policy '$policyName' does not exist yet; it will be created." -ForegroundColor Yellow
    }
    else {
        Write-Host "Policy '$policyName' already exists; SetPhotoEnabled will be set to false." -ForegroundColor Yellow
    }

    if ($scope -eq "1") {
        Write-Host "Retrieving licensed user mailboxes (count only)..." -ForegroundColor Cyan
        $users = Get-Mailbox -RecipientTypeDetails UserMailbox -ResultSize Unlimited -ErrorAction Stop |
            Where-Object { $_.IsLicensed -eq $true }
        $count = @($users).Count
    }
    else {
        $mbx = Get-Mailbox -Identity $singleId -ErrorAction Stop
        $users = @($mbx)
        $count = 1
        Write-Host "Target: $($mbx.UserPrincipalName)" -ForegroundColor Cyan
    }

    if ($count -eq 0) {
        Write-Host "No mailboxes to process." -ForegroundColor Yellow
        return
    }

    Write-Host "`nWill apply policy '$policyName' (SetPhotoEnabled = false) to $count mailbox(es)." -ForegroundColor Yellow
    $confirm = Read-Host "Proceed? (Y/N)"
    if ($confirm -notmatch '^[Yy]$') {
        Write-Host "Cancelled." -ForegroundColor Yellow
        return
    }

    if (-not $existing) {
        New-OwaMailboxPolicy -Name $policyName -ErrorAction Stop | Out-Null
        Write-Host "Created OWA Mailbox Policy '$policyName'." -ForegroundColor Green
    }

    Set-OwaMailboxPolicy -Identity $policyName -SetPhotoEnabled $false -ErrorAction Stop
    Write-Host "Policy configured: SetPhotoEnabled = false." -ForegroundColor Green

    $success = 0
    $failed = @()

    foreach ($user in $users) {
        try {
            Set-CASMailbox -Identity $user.UserPrincipalName -OwaMailboxPolicy $policyName -ErrorAction Stop
            Write-Host "  Applied: $($user.UserPrincipalName)" -ForegroundColor Green
            $success++
        }
        catch {
            Write-Host "  Failed: $($user.UserPrincipalName) — $($_.Exception.Message)" -ForegroundColor Red
            $failed += $user.UserPrincipalName
        }
    }

    Write-Host "`nDone. Applied to $success of $count." -ForegroundColor Cyan
    if ($failed.Count -gt 0) {
        Write-Host "Failed:" -ForegroundColor Red
        $failed | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    }
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}
finally {
    try { Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue } catch { }
}
