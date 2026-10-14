#Requires -Version 5.1
<#
.SYNOPSIS
    Restrict Microsoft 365 groups so they only accept mail from approved senders.
    Adds one sender to AcceptMessagesOnlyFrom for one or more groups.
#>

$ErrorActionPreference = "Stop"

try {
    $adminUPN = Read-Host "Enter your Exchange Online admin UPN (e.g., admin@domain.com)"
    $newSender = Read-Host "Enter the email address or identity of the sender to allow"
    $groupInput = Read-Host "Enter the Microsoft 365 group email addresses (comma-separated)"

    if ([string]::IsNullOrWhiteSpace($adminUPN) -or [string]::IsNullOrWhiteSpace($newSender) -or [string]::IsNullOrWhiteSpace($groupInput)) {
        Write-Host "Admin UPN, sender, and at least one group are required. Exiting." -ForegroundColor Yellow
        exit 1
    }

    $groups = $groupInput -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ }

    Write-Host "`nWill add sender '$newSender' to AcceptMessagesOnlyFrom on $($groups.Count) group(s):" -ForegroundColor Cyan
    $groups | ForEach-Object { Write-Host "  - $_" }

    $confirm = Read-Host "`nProceed? (Y/N)"
    if ($confirm -notmatch '^[Yy]$') {
        Write-Host "Cancelled." -ForegroundColor Yellow
        return
    }

    if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
        Write-Host "Installing ExchangeOnlineManagement module..." -ForegroundColor Yellow
        Install-Module -Name ExchangeOnlineManagement -Force -AllowClobber -Scope CurrentUser -ErrorAction Stop
    }
    Import-Module ExchangeOnlineManagement -Force -ErrorAction Stop

    Write-Host "Connecting to Exchange Online..." -ForegroundColor Cyan
    Connect-ExchangeOnline -UserPrincipalName $adminUPN -ShowBanner:$false -ErrorAction Stop

    $senderRecipient = Get-Recipient $newSender -ErrorAction SilentlyContinue
    if (-not $senderRecipient) {
        Write-Host "Sender not found: $newSender" -ForegroundColor Red
        return
    }

    $ok = 0
    $skipped = 0
    $failed = @()

    foreach ($group in $groups) {
        Write-Host "`nProcessing M365 Group: $group" -ForegroundColor Cyan

        try {
            $ug = Get-UnifiedGroup $group -ErrorAction Stop
        }
        catch {
            Write-Host "Group not found: $group — $($_.Exception.Message)" -ForegroundColor Red
            $failed += $group
            continue
        }

        $currentSenders = @($ug.AcceptMessagesOnlyFrom)

        if ($currentSenders -contains $senderRecipient) {
            Write-Host "$newSender is already allowed for $group" -ForegroundColor Yellow
            $skipped++
            continue
        }

        try {
            $updatedList = $currentSenders + $senderRecipient
            Set-UnifiedGroup $group -AcceptMessagesOnlyFrom $updatedList -ErrorAction Stop
            Write-Host "Added $newSender to AcceptMessagesOnlyFrom for $group" -ForegroundColor Green
            $ok++
        }
        catch {
            Write-Host "Failed to update $group: $($_.Exception.Message)" -ForegroundColor Red
            $failed += $group
        }
    }

    Write-Host "`nDone. Updated: $ok | Already allowed: $skipped | Failed: $($failed.Count)" -ForegroundColor Cyan
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}
finally {
    try { Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue } catch { }
}
