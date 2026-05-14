# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "This script must be run as an Administrator. Please restart PowerShell as Administrator and try again." -ForegroundColor Red
    exit
}

# Install Microsoft Graph modules if not already installed
try {
    Write-Host "Checking for Microsoft Graph modules..." -ForegroundColor Yellow
    if (-not (Get-Module -ListAvailable -Name Microsoft.Graph)) {
        Install-Module Microsoft.Graph -Force -Scope AllUsers -ErrorAction Stop
    }
    if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Beta)) {
        Install-Module Microsoft.Graph.Beta -AllowClobber -Force -Scope AllUsers -ErrorAction Stop
    }
    Write-Host "Microsoft Graph modules are available." -ForegroundColor Green
}
catch {
    Write-Host "Failed to install Microsoft Graph modules. Error: $_" -ForegroundColor Red
    exit
}

# Connect to Microsoft Graph
try {
    Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Yellow
    Connect-MgGraph -Scopes "Organization.ReadWrite.All", "Directory.ReadWrite.All" -NoWelcome -ErrorAction Stop
    Write-Host "Connected to Microsoft Graph successfully." -ForegroundColor Green
}
catch {
    Write-Host "Failed to connect to Microsoft Graph. Ensure you have the correct permissions. Error: $_" -ForegroundColor Red
    exit
}

# Check current sync status
Write-Host "Checking current directory sync status..." -ForegroundColor Yellow
$syncStatus = (Get-MgOrganization).OnPremisesSyncEnabled
Write-Host "Current OnPremisesSyncEnabled status: $syncStatus" -ForegroundColor Cyan

# Disable directory synchronization in Microsoft 365
if ($syncStatus -eq $true) {
    try {
        Write-Host "Disabling directory synchronization in Microsoft 365..." -ForegroundColor Yellow
        $organizationId = (Get-MgOrganization).Id
        $params = @{ onPremisesSyncEnabled = $false }
        Update-MgOrganization -OrganizationId $organizationId -BodyParameter $params -ErrorAction Stop
        Write-Host "Directory synchronization disabled in Microsoft 365." -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to disable directory synchronization. Error: $_" -ForegroundColor Red
        exit
    }
} else {
    Write-Host "Directory synchronization is already disabled in Microsoft 365." -ForegroundColor Green
}

# Verify sync status after update
Write-Host "Verifying updated sync status..." -ForegroundColor Yellow
$newSyncStatus = (Get-MgOrganization).OnPremisesSyncEnabled
if ($newSyncStatus -eq $false) {
    Write-Host "Directory synchronization is confirmed disabled in Microsoft 365." -ForegroundColor Green
} else {
    Write-Host "Failed to confirm directory synchronization is disabled. Current status: $newSyncStatus" -ForegroundColor Red
}

# Disconnect from Microsoft Graph
Disconnect-MgGraph -ErrorAction SilentlyContinue
Write-Host "Disconnected from Microsoft Graph." -ForegroundColor Green

# Disable Azure AD Connect synchronization on the server
try {
    Write-Host "Checking for ADSync module..." -ForegroundColor Yellow
    if (Get-Module -ListAvailable -Name ADSync) {
        Import-Module ADSync -ErrorAction Stop
        Write-Host "ADSync module imported successfully." -ForegroundColor Green

        # Stop the Azure AD Sync Scheduler
        Write-Host "Stopping the Azure AD Sync Scheduler..." -ForegroundColor Yellow
        Set-ADSyncScheduler -SyncCycleEnabled $false
        Write-Host "Azure AD Sync Scheduler has been disabled." -ForegroundColor Green

        # Stop the Azure AD Connect service
        Write-Host "Stopping the Azure AD Connect service..." -ForegroundColor Yellow
        Stop-Service -Name "ADSync" -Force
        Write-Host "Azure AD Connect service stopped." -ForegroundColor Green

        # Verify scheduler status
        $schedulerStatus = Get-ADSyncScheduler
        if ($schedulerStatus.SyncCycleEnabled -eq $false) {
            Write-Host "Azure AD Connect synchronization is disabled on the server." -ForegroundColor Green
        } else {
            Write-Host "Failed to verify that server synchronization is disabled." -ForegroundColor Red
        }
    } else {
        Write-Host "ADSync module not found. Skipping server-side sync disablement." -ForegroundColor Yellow
    }
}
catch {
    Write-Host "Failed to disable Azure AD Connect synchronization on the server. Error: $_" -ForegroundColor Red
}

Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Wait up to 72 hours for Microsoft to fully process the directory sync disablement."
Write-Host "2. Verify in Microsoft 365 Admin Center (Settings > Org settings > Azure AD Connect)."
Write-Host "3. Optionally, uninstall Azure AD Connect from the server via 'Add or Remove Programs'."
Write-Host "WARNING: Back up your Azure AD Connect configuration before uninstalling." -ForegroundColor Yellow