#Requires -Version 5.1
<#
.SYNOPSIS
    Optionally disable directory sync, then report/convert directory-synced distribution groups and mailboxes to cloud-only.
    Destructive steps require explicit confirmation.
#>

$ErrorActionPreference = "Continue"

$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "This script must be run as an Administrator. Please restart PowerShell as Administrator and try again." -ForegroundColor Red
    exit 1
}

$logFile = "M365-Sync-Check-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
Write-Host "Logging output to $logFile" -ForegroundColor Cyan
"Starting sync check at $(Get-Date)" | Out-File -FilePath $logFile -Append

try {
    Write-Host "Checking for required PowerShell modules..." -ForegroundColor Yellow
    if (-not (Get-Module -ListAvailable -Name Microsoft.Graph)) {
        Install-Module Microsoft.Graph -Force -Scope AllUsers -ErrorAction Stop
    }
    if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
        Install-Module ExchangeOnlineManagement -Force -Scope AllUsers -ErrorAction Stop
    }
    Write-Host "Required modules are available." -ForegroundColor Green
    "Modules verified" | Out-File -FilePath $logFile -Append
}
catch {
    Write-Host "Failed to install required modules. Error: $_" -ForegroundColor Red
    "ERROR: Failed to install modules: $_" | Out-File -FilePath $logFile -Append
    exit 1
}

try {
    Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Yellow
    Connect-MgGraph -Scopes "Organization.ReadWrite.All", "Directory.ReadWrite.All", "Group.ReadWrite.All", "User.ReadWrite.All" -NoWelcome -ErrorAction Stop
    Write-Host "Connected to Microsoft Graph successfully." -ForegroundColor Green
    "Connected to Microsoft Graph" | Out-File -FilePath $logFile -Append
}
catch {
    Write-Host "Failed to connect to Microsoft Graph. Error: $_" -ForegroundColor Red
    "ERROR: Failed to connect to Microsoft Graph: $_" | Out-File -FilePath $logFile -Append
    exit 1
}

Write-Host "Checking current directory sync status..." -ForegroundColor Yellow
$org = Get-MgOrganization
$syncStatus = $org.OnPremisesSyncEnabled
Write-Host "Tenant: $($org.DisplayName)" -ForegroundColor Cyan
Write-Host "Current OnPremisesSyncEnabled status: $syncStatus" -ForegroundColor Cyan
"Directory sync status: $syncStatus" | Out-File -FilePath $logFile -Append

if ($syncStatus -eq $true) {
    Write-Host "`nWARNING: Disabling directory sync is a major tenant change (up to 72 hours to fully process)." -ForegroundColor Red
    $confirmSync = Read-Host "Disable directory synchronization in Microsoft 365 now? (Y/N)"
    if ($confirmSync -match '^[Yy]$') {
        try {
            Write-Host "Disabling directory synchronization in Microsoft 365..." -ForegroundColor Yellow
            $params = @{ onPremisesSyncEnabled = $false }
            Update-MgOrganization -OrganizationId $org.Id -BodyParameter $params -ErrorAction Stop
            Write-Host "Directory synchronization disabled in Microsoft 365." -ForegroundColor Green
            "Directory synchronization disabled in Microsoft 365" | Out-File -FilePath $logFile -Append

            $newSyncStatus = (Get-MgOrganization).OnPremisesSyncEnabled
            Write-Host "Verified OnPremisesSyncEnabled: $newSyncStatus" -ForegroundColor Cyan
        }
catch {
            Write-Host "Failed to disable directory synchronization. Error: $_" -ForegroundColor Red
            "ERROR: Failed to disable directory synchronization: $_" | Out-File -FilePath $logFile -Append
        }
    }
    else {
        Write-Host "Cloud sync disable skipped." -ForegroundColor Yellow
        "Cloud sync disable skipped by user" | Out-File -FilePath $logFile -Append
    }
}
else {
    Write-Host "Directory synchronization is already disabled in Microsoft 365." -ForegroundColor Green
    "Directory synchronization already disabled" | Out-File -FilePath $logFile -Append
}

Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
Write-Host "Disconnected from Microsoft Graph." -ForegroundColor Green

if (Get-Module -ListAvailable -Name ADSync) {
    $confirmServer = Read-Host "`nStop Azure AD Connect scheduler and ADSync service on this server? (Y/N)"
    if ($confirmServer -match '^[Yy]$') {
        try {
            Import-Module ADSync -ErrorAction Stop
            Set-ADSyncScheduler -SyncCycleEnabled $false
            Stop-Service -Name "ADSync" -Force -ErrorAction Stop
            Write-Host "Server synchronization disabled." -ForegroundColor Green
            "Server synchronization disabled" | Out-File -FilePath $logFile -Append
        }
        catch {
            Write-Host "Failed to disable server sync. Error: $_" -ForegroundColor Red
            "ERROR: Failed to disable server sync: $_" | Out-File -FilePath $logFile -Append
        }
    }
    else {
        Write-Host "Server-side steps skipped." -ForegroundColor Yellow
    }
}
else {
    Write-Host "ADSync module not found. Skipping server-side sync disablement." -ForegroundColor Yellow
}

$doExchange = Read-Host "`nCheck Exchange distribution groups and mailboxes for IsDirSynced and attempt cloud-only conversion? (Y/N)"
if ($doExchange -notmatch '^[Yy]$') {
    Write-Host "Exchange object checks skipped." -ForegroundColor Yellow
    "Exchange checks skipped by user" | Out-File -FilePath $logFile -Append
    Write-Host "Script completed. Check the log file '$logFile' for details." -ForegroundColor Green
    return
}

try {
    Write-Host "Connecting to Exchange Online..." -ForegroundColor Yellow
    Import-Module ExchangeOnlineManagement -ErrorAction Stop
    Connect-ExchangeOnline -ShowBanner:$false -ErrorAction Stop
    Write-Host "Connected to Exchange Online successfully." -ForegroundColor Green
    "Connected to Exchange Online" | Out-File -FilePath $logFile -Append
}
catch {
    Write-Host "Failed to connect to Exchange Online. Error: $_" -ForegroundColor Red
    "ERROR: Failed to connect to Exchange Online: $_" | Out-File -FilePath $logFile -Append
    Write-Host "Script completed. Check the log file '$logFile' for details." -ForegroundColor Green
    return
}

Write-Host "Checking all distribution groups for sync status..." -ForegroundColor Yellow
"Checking distribution groups" | Out-File -FilePath $logFile -Append
try {
    $groups = Get-DistributionGroup -ResultSize Unlimited -ErrorAction Stop
    $syncedGroups = @($groups | Where-Object { $_.IsDirSynced -eq $true })
    Write-Host "Found $($syncedGroups.Count) directory-synced distribution group(s)." -ForegroundColor Cyan

    if ($syncedGroups.Count -gt 0) {
        $syncedGroups | ForEach-Object {
            Write-Host "  $($_.DisplayName) ($($_.PrimarySmtpAddress))"
            "Synced group: $($_.DisplayName) ($($_.PrimarySmtpAddress))" | Out-File -FilePath $logFile -Append
        }
        $confirmGroups = Read-Host "Attempt to convert these $($syncedGroups.Count) group(s) toward cloud-only? (Y/N)"
        if ($confirmGroups -match '^[Yy]$') {
            foreach ($group in $syncedGroups) {
                try {
                    Write-Host "Attempting to convert group '$($group.DisplayName)'..." -ForegroundColor Yellow
                    Set-DistributionGroup -Identity $group.PrimarySmtpAddress -BypassSecurityGroupManagerCheck -ErrorAction Stop
                    $updatedGroup = Get-DistributionGroup -Identity $group.PrimarySmtpAddress
                    if ($updatedGroup.IsDirSynced -eq $false) {
                        Write-Host "  Converted: $($group.DisplayName)" -ForegroundColor Green
                        "Group converted: $($group.DisplayName)" | Out-File -FilePath $logFile -Append
                    }
                    else {
                        Write-Host "  Still marked synced: $($group.DisplayName)" -ForegroundColor Yellow
                        "Group still synced: $($group.DisplayName)" | Out-File -FilePath $logFile -Append
                    }
                }
                catch {
                    Write-Host "  Failed: $($group.DisplayName) — $_" -ForegroundColor Red
                    "ERROR: Failed to update group '$($group.DisplayName)': $_" | Out-File -FilePath $logFile -Append
                }
            }
        }
        else {
            Write-Host "Group conversion skipped." -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "No directory-synced distribution groups found." -ForegroundColor Green
    }
}
catch {
    Write-Host "Failed to retrieve distribution groups. Error: $_" -ForegroundColor Red
    "ERROR: Failed to retrieve groups: $_" | Out-File -FilePath $logFile -Append
}

Write-Host "Checking all mailboxes for sync status..." -ForegroundColor Yellow
"Checking mailboxes" | Out-File -FilePath $logFile -Append
try {
    $mailboxes = Get-Mailbox -ResultSize Unlimited -ErrorAction Stop
    $syncedMailboxes = @($mailboxes | Where-Object { $_.IsDirSynced -eq $true })
    Write-Host "Found $($syncedMailboxes.Count) directory-synced mailbox(es)." -ForegroundColor Cyan

    if ($syncedMailboxes.Count -gt 0) {
        $syncedMailboxes | Select-Object -First 20 | ForEach-Object {
            Write-Host "  $($_.DisplayName) ($($_.PrimarySmtpAddress))"
        }
        if ($syncedMailboxes.Count -gt 20) {
            Write-Host "  ... and $($syncedMailboxes.Count - 20) more"
        }
        $syncedMailboxes | ForEach-Object {
            "Synced mailbox: $($_.DisplayName) ($($_.PrimarySmtpAddress))" | Out-File -FilePath $logFile -Append
        }

        $confirmMb = Read-Host "Attempt to convert these $($syncedMailboxes.Count) mailbox(es) toward cloud-only? (Y/N)"
        if ($confirmMb -match '^[Yy]$') {
            foreach ($mailbox in $syncedMailboxes) {
                try {
                    Write-Host "Attempting to convert mailbox '$($mailbox.DisplayName)'..." -ForegroundColor Yellow
                    Set-Mailbox -Identity $mailbox.PrimarySmtpAddress -BypassSecurityGroupManagerCheck -ErrorAction Stop
                    $updatedMailbox = Get-Mailbox -Identity $mailbox.PrimarySmtpAddress
                    if ($updatedMailbox.IsDirSynced -eq $false) {
                        Write-Host "  Converted: $($mailbox.DisplayName)" -ForegroundColor Green
                        "Mailbox converted: $($mailbox.DisplayName)" | Out-File -FilePath $logFile -Append
                    }
                    else {
                        Write-Host "  Still marked synced: $($mailbox.DisplayName)" -ForegroundColor Yellow
                        "Mailbox still synced: $($mailbox.DisplayName)" | Out-File -FilePath $logFile -Append
                    }
                }
                catch {
                    Write-Host "  Failed: $($mailbox.DisplayName) — $_" -ForegroundColor Red
                    "ERROR: Failed to update mailbox '$($mailbox.DisplayName)': $_" | Out-File -FilePath $logFile -Append
                }
            }
        }
        else {
            Write-Host "Mailbox conversion skipped." -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "No directory-synced mailboxes found." -ForegroundColor Green
    }
}
catch {
    Write-Host "Failed to retrieve mailboxes. Error: $_" -ForegroundColor Red
    "ERROR: Failed to retrieve mailboxes: $_" | Out-File -FilePath $logFile -Append
}

Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
Write-Host "Disconnected from Exchange Online." -ForegroundColor Green

Write-Host "Script completed. Check the log file '$logFile' for details." -ForegroundColor Green
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Review the log file for any objects that failed to convert to cloud-only."
Write-Host "2. Wait up to 72 hours for Microsoft to fully process the directory sync disablement."
Write-Host "3. Verify in Microsoft 365 Admin Center (Settings > Org settings > Microsoft Entra Connect)."
Write-Host "4. For objects that failed to convert, check on-premises AD."
Write-Host "WARNING: Back up Azure AD Connect configuration before uninstalling." -ForegroundColor Yellow
"Completed at $(Get-Date)" | Out-File -FilePath $logFile -Append
