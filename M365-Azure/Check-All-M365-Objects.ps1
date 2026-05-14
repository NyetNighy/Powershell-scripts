# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "This script must be run as an Administrator. Please restart PowerShell as Administrator and try again." -ForegroundColor Red
    exit
}

# Initialize log file
$logFile = "M365-Sync-Check-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
Write-Host "Logging output to $logFile" -ForegroundColor Cyan
"Starting sync check at $(Get-Date)" | Out-File -FilePath $logFile -Append

# Install Microsoft Graph and Exchange Online modules if not already installed
try {
    Write-Host "Checking for required PowerShell modules..." -ForegroundColor Yellow
    if (-not (Get-Module -ListAvailable -Name Microsoft.Graph)) {
        Install-Module Microsoft.Graph -Force -Scope AllUsers -ErrorAction Stop
    }
    if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Beta)) {
        Install-Module Microsoft.Graph.Beta -AllowClobber -Force -Scope AllUsers -ErrorAction Stop
    }
    if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
        Install-Module ExchangeOnlineManagement -Force -Scope AllUsers -ErrorAction Stop
    }
    Write-Host "Required modules are available." -ForegroundColor Green
    "Modules verified: Microsoft.Graph, Microsoft.Graph.Beta, ExchangeOnlineManagement" | Out-File -FilePath $logFile -Append
}
catch {
    Write-Host "Failed to install required modules. Error: $_" -ForegroundColor Red
    "ERROR: Failed to install modules: $_" | Out-File -FilePath $logFile -Append
    exit
}

# Connect to Microsoft Graph
try {
    Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Yellow
    Connect-MgGraph -Scopes "Organization.ReadWrite.All", "Directory.ReadWrite.All", "Group.ReadWrite.All", "User.ReadWrite.All" -NoWelcome -ErrorAction Stop
    Write-Host "Connected to Microsoft Graph successfully." -ForegroundColor Green
    "Connected to Microsoft Graph" | Out-File -FilePath $logFile -Append
}
catch {
    Write-Host "Failed to connect to Microsoft Graph. Ensure you have the correct permissions. Error: $_" -ForegroundColor Red
    "ERROR: Failed to connect to Microsoft Graph: $_" | Out-File -FilePath $logFile -Append
    exit
}

# Check current directory sync status
Write-Host "Checking current directory sync status..." -ForegroundColor Yellow
$org = Get-MgOrganization
$syncStatus = $org.OnPremisesSyncEnabled
Write-Host "Current OnPremisesSyncEnabled status: $syncStatus" -ForegroundColor Cyan
"Directory sync status: $syncStatus" | Out-File -FilePath $logFile -Append

# Disable directory synchronization in Microsoft 365 if enabled
if ($syncStatus -eq $true) {
    try {
        Write-Host "Disabling directory synchronization in Microsoft 365..." -ForegroundColor Yellow
        $organizationId = $org.Id
        $params = @{ onPremisesSyncEnabled = $false }
        Update-MgOrganization -OrganizationId $organizationId -BodyParameter $params -ErrorAction Stop
        Write-Host "Directory synchronization disabled in Microsoft 365." -ForegroundColor Green
        "Directory synchronization disabled in Microsoft 365" | Out-File -FilePath $logFile -Append
    }
    catch {
        Write-Host "Failed to disable directory synchronization. Error: $_" -ForegroundColor Red
        "ERROR: Failed to disable directory synchronization: $_" | Out-File -FilePath $logFile -Append
        exit
    }

    # Verify sync status after update
    Write-Host "Verifying updated sync status..." -ForegroundColor Yellow
    $newSyncStatus = (Get-MgOrganization).OnPremisesSyncEnabled
    if ($newSyncStatus -eq $false) {
        Write-Host "Directory synchronization is confirmed disabled in Microsoft 365." -ForegroundColor Green
        "Directory synchronization confirmed disabled" | Out-File -FilePath $logFile -Append
    } else {
        Write-Host "Failed to confirm directory synchronization is disabled. Current status: $newSyncStatus" -ForegroundColor Red
        "ERROR: Failed to confirm directory sync disablement: $newSyncStatus" | Out-File -FilePath $logFile -Append
    }
} else {
    Write-Host "Directory synchronization is already disabled in Microsoft 365." -ForegroundColor Green
    "Directory synchronization already disabled" | Out-File -FilePath $logFile -Append
}

# Disconnect from Microsoft Graph
Disconnect-MgGraph -ErrorAction SilentlyContinue
Write-Host "Disconnected from Microsoft Graph." -ForegroundColor Green
"Disconnected from Microsoft Graph" | Out-File -FilePath $logFile -Append

# Disable Azure AD Connect synchronization on the server
try {
    Write-Host "Checking for ADSync module..." -ForegroundColor Yellow
    if (Get-Module -ListAvailable -Name ADSync) {
        Import-Module ADSync -ErrorAction Stop
        Write-Host "ADSync module imported successfully." -ForegroundColor Green
        "ADSync module imported" | Out-File -FilePath $logFile -Append

        # Stop the Azure AD Sync Scheduler
        Write-Host "Stopping the Azure AD Sync Scheduler..." -ForegroundColor Yellow
        Set-ADSyncScheduler -SyncCycleEnabled $false
        Write-Host "Azure AD Sync Scheduler has been disabled." -ForegroundColor Green
        "Azure AD Sync Scheduler disabled" | Out-File -FilePath $logFile -Append

        # Stop the Azure AD Connect service
        Write-Host "Stopping the Azure AD Connect service..." -ForegroundColor Yellow
        Stop-Service -Name "ADSync" -Force
        Write-Host "Azure AD Connect service stopped." -ForegroundColor Green
        "Azure AD Connect service stopped" | Out-File -FilePath $logFile -Append

        # Verify scheduler status
        $schedulerStatus = Get-ADSyncScheduler
        if ($schedulerStatus.SyncCycleEnabled -eq $false) {
            Write-Host "Azure AD Connect synchronization is disabled on the server." -ForegroundColor Green
            "Server synchronization disabled" | Out-File -FilePath $logFile -Append
        } else {
            Write-Host "Failed to verify that server synchronization is disabled." -ForegroundColor Red
            "ERROR: Failed to verify server sync disablement" | Out-File -FilePath $logFile -Append
        }
    } else {
        Write-Host "ADSync module not found. Skipping server-side sync disablement." -ForegroundColor Yellow
        "ADSync module not found, skipping server-side steps" | Out-File -FilePath $logFile -Append
    }
}
catch {
    Write-Host "Failed to disable Azure AD Connect synchronization on the server. Error: $_" -ForegroundColor Red
    "ERROR: Failed to disable server sync: $_" | Out-File -FilePath $logFile -Append
}

# Connect to Exchange Online
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
    Write-Host "Skipping Exchange Online object checks." -ForegroundColor Yellow
    "Skipping Exchange Online checks" | Out-File -FilePath $logFile -Append
}

# Check all distribution groups
Write-Host "Checking all distribution groups for sync status..." -ForegroundColor Yellow
"Checking distribution groups" | Out-File -FilePath $logFile -Append
try {
    $groups = Get-DistributionGroup -ResultSize Unlimited -ErrorAction Stop
    $syncedGroups = @()
    foreach ($group in $groups) {
        if ($group.IsDirSynced -eq $true) {
            $syncedGroups += $group
            Write-Host "Group '$($group.DisplayName)' ($($group.PrimarySmtpAddress)) is directory-synced." -ForegroundColor Yellow
            "Synced group: $($group.DisplayName) ($($group.PrimarySmtpAddress))" | Out-File -FilePath $logFile -Append
            try {
                Write-Host "Attempting to convert group '$($group.DisplayName)' to cloud-only..." -ForegroundColor Yellow
                Set-DistributionGroup -Identity $group.PrimarySmtpAddress -BypassSecurityGroupManagerCheck -ErrorAction Stop
                $updatedGroup = Get-DistributionGroup -Identity $group.PrimarySmtpAddress
                if ($updatedGroup.IsDirSynced -eq $false) {
                    Write-Host "Group '$($group.DisplayName)' successfully converted to cloud-only." -ForegroundColor Green
                    "Group converted to cloud-only: $($group.DisplayName)" | Out-File -FilePath $logFile -Append
                } else {
                    Write-Host "Failed to convert group '$($group.DisplayName)' to cloud-only." -ForegroundColor Red
                    "ERROR: Failed to convert group: $($group.DisplayName)" | Out-File -FilePath $logFile -Append
                }
            }
            catch {
                Write-Host "Failed to update group '$($group.DisplayName)'. Error: $_" -ForegroundColor Red
                "ERROR: Failed to update group '$($group.DisplayName)': $_" | Out-File -FilePath $logFile -Append
            }
        }
    }
    if ($syncedGroups.Count -eq 0) {
        Write-Host "No directory-synced distribution groups found." -ForegroundColor Green
        "No synced distribution groups found" | Out-File -FilePath $logFile -Append
    } else {
        Write-Host "Found $($syncedGroups.Count) directory-synced groups." -ForegroundColor Cyan
        "Found $($syncedGroups.Count) synced groups" | Out-File -FilePath $logFile -Append
    }
}
catch {
    Write-Host "Failed to retrieve distribution groups. Error: $_" -ForegroundColor Red
    "ERROR: Failed to retrieve groups: $_" | Out-File -FilePath $logFile -Append
}

# Check all mailboxes (users)
Write-Host "Checking all mailboxes for sync status..." -ForegroundColor Yellow
"Checking mailboxes" | Out-File -FilePath $logFile -Append
try {
    $mailboxes = Get-Mailbox -ResultSize Unlimited -ErrorAction Stop
    $syncedMailboxes = @()
    foreach ($mailbox in $mailboxes) {
        if ($mailbox.IsDirSynced -eq $true) {
            $syncedMailboxes += $mailbox
            Write-Host "Mailbox '$($mailbox.DisplayName)' ($($mailbox.PrimarySmtpAddress)) is directory-synced." -ForegroundColor Yellow
            "Synced mailbox: $($mailbox.DisplayName) ($($mailbox.PrimarySmtpAddress))" | Out-File -FilePath $logFile -Append
            try {
                Write-Host "Attempting to convert mailbox '$($mailbox.DisplayName)' to cloud-only..." -ForegroundColor Yellow
                Set-Mailbox -Identity $mailbox.PrimarySmtpAddress -BypassSecurityGroupManagerCheck -ErrorAction Stop
                $updatedMailbox = Get-Mailbox -Identity $mailbox.PrimarySmtpAddress
                if ($updatedMailbox.IsDirSynced -eq $false) {
                    Write-Host "Mailbox '$($mailbox.DisplayName)' successfully converted to cloud-only." -ForegroundColor Green
                    "Mailbox converted to cloud-only: $($mailbox.DisplayName)" | Out-File -FilePath $logFile -Append
                } else {
                    Write-Host "Failed to convert mailbox '$($mailbox.DisplayName)' to cloud-only." -ForegroundColor Red
                    "ERROR: Failed to convert mailbox: $($mailbox.DisplayName)" | Out-File -FilePath $logFile -Append
                }
            }
            catch {
                Write-Host "Failed to update mailbox '$($mailbox.DisplayName)'. Error: $_" -ForegroundColor Red
                "ERROR: Failed to update mailbox '$($mailbox.DisplayName)': $_" | Out-File -FilePath $logFile -Append
            }
        }
    }
    if ($syncedMailboxes.Count -eq 0) {
        Write-Host "No directory-synced mailboxes found." -ForegroundColor Green
        "No synced mailboxes found" | Out-File -FilePath $logFile -Append
    } else {
        Write-Host "Found $($syncedMailboxes.Count) directory-synced mailboxes." -ForegroundColor Cyan
        "Found $($syncedMailboxes.Count) synced mailboxes" | Out-File -FilePath $logFile -Append
    }
}
catch {
    Write-Host "Failed to retrieve mailboxes. Error: $_" -ForegroundColor Red
    "ERROR: Failed to retrieve mailboxes: $_" | Out-File -FilePath $logFile -Append
}

# Disconnect from Exchange Online
Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
Write-Host "Disconnected from Exchange Online." -ForegroundColor Green
"Disconnected from Exchange Online" | Out-File -FilePath $logFile -Append

Write-Host "Script completed. Check the log file '$logFile' for details." -ForegroundColor Green
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Review the log file for any objects that failed to convert to cloud-only."
Write-Host "2. Wait up to 72 hours for Microsoft to fully process the directory sync disablement."
Write-Host "3. Verify in Microsoft 365 Admin Center (Settings > Org settings > Azure AD Connect) that sync is disabled."
Write-Host "4. For objects that failed to convert, check on-premises AD and delete or update them using Active Directory Users and Computers."
Write-Host "5. Optionally, uninstall Azure AD Connect from the server via 'Add or Remove Programs' after confirming sync is disabled."
Write-Host "WARNING: Back up your Azure AD Connect configuration before uninstalling." -ForegroundColor Yellow
"Next steps provided in console output" | Out-File -FilePath $logFile -Append