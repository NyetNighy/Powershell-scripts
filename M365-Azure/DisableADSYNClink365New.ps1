#Requires -Version 5.1
<#
.SYNOPSIS
    Disable directory sync in Microsoft 365 (Graph) and optionally stop Azure AD Connect on the local server.
    Requires Administrator elevation for server-side steps and explicit confirmation before changes.
#>

$ErrorActionPreference = "Stop"

$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "This script must be run as Administrator for server-side ADSync steps." -ForegroundColor Red
    Write-Host "Cloud-only disable will still be offered after elevation check fails if you re-run elevated." -ForegroundColor Yellow
    exit 1
}

try {
    Write-Host "Checking for Microsoft Graph modules..." -ForegroundColor Yellow
    if (-not (Get-Module -ListAvailable -Name Microsoft.Graph)) {
        Install-Module Microsoft.Graph -Force -Scope AllUsers -ErrorAction Stop
    }
    Write-Host "Microsoft Graph modules are available." -ForegroundColor Green

    Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
    Connect-MgGraph -Scopes "Organization.ReadWrite.All", "Directory.ReadWrite.All" -NoWelcome -ErrorAction Stop

    $org = Get-MgOrganization -ErrorAction Stop
    $syncStatus = $org.OnPremisesSyncEnabled
    Write-Host "Tenant: $($org.DisplayName)" -ForegroundColor Cyan
    Write-Host "Current OnPremisesSyncEnabled: $syncStatus" -ForegroundColor Cyan

    if ($syncStatus -eq $true) {
        Write-Host "`nWARNING: Disabling directory sync is a major tenant change (up to 72h to fully process)." -ForegroundColor Red
        $confirmCloud = Read-Host "Disable directory synchronization in Microsoft 365? (Y/N)"
        if ($confirmCloud -match '^[Yy]$') {
            $params = @{ onPremisesSyncEnabled = $false }
            Update-MgOrganization -OrganizationId $org.Id -BodyParameter $params -ErrorAction Stop
            Write-Host "Directory synchronization disabled in Microsoft 365." -ForegroundColor Green

            $newSyncStatus = (Get-MgOrganization).OnPremisesSyncEnabled
            Write-Host "Verified OnPremisesSyncEnabled: $newSyncStatus" -ForegroundColor Cyan
        }
        else {
            Write-Host "Cloud sync disable skipped." -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "Directory synchronization is already disabled in Microsoft 365." -ForegroundColor Green
    }

    Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null

    if (Get-Module -ListAvailable -Name ADSync) {
        $confirmServer = Read-Host "`nStop Azure AD Connect scheduler and ADSync service on this server? (Y/N)"
        if ($confirmServer -match '^[Yy]$') {
            Import-Module ADSync -ErrorAction Stop
            Write-Host "Stopping Azure AD Sync Scheduler..." -ForegroundColor Yellow
            Set-ADSyncScheduler -SyncCycleEnabled $false
            Write-Host "Stopping ADSync service..." -ForegroundColor Yellow
            Stop-Service -Name "ADSync" -Force -ErrorAction Stop

            $schedulerStatus = Get-ADSyncScheduler
            if ($schedulerStatus.SyncCycleEnabled -eq $false) {
                Write-Host "Server synchronization disabled." -ForegroundColor Green
            }
            else {
                Write-Host "Could not verify scheduler is disabled." -ForegroundColor Red
            }
        }
        else {
            Write-Host "Server-side steps skipped." -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "ADSync module not found on this machine. Skipping server-side steps." -ForegroundColor Yellow
    }

    Write-Host "`nNext steps:" -ForegroundColor Cyan
    Write-Host "1. Wait up to 72 hours for Microsoft to fully process the directory sync disablement."
    Write-Host "2. Verify in Microsoft 365 Admin Center (Settings > Org settings > Microsoft Entra Connect)."
    Write-Host "3. Optionally uninstall Azure AD Connect from the server after backing up its configuration."
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    try { Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null } catch { }
}
