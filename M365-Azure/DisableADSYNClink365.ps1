#Requires -Version 5.1
<#
.SYNOPSIS
    Disable directory (Azure AD Connect / Entra Connect) sync in Microsoft 365 via Microsoft Graph.
    Prefer DisableADSYNClink365New.ps1 for the fuller cloud + server workflow.
    Requires explicit confirmation before changing tenant sync status.
#>

$ErrorActionPreference = "Stop"

try {
    if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Identity.DirectoryManagement) -and
        -not (Get-Module -ListAvailable -Name Microsoft.Graph)) {
        Write-Host "Installing Microsoft.Graph..." -ForegroundColor Yellow
        Install-Module Microsoft.Graph -Force -Scope CurrentUser -ErrorAction Stop
    }

    Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
    Connect-MgGraph -Scopes "Organization.ReadWrite.All", "Directory.ReadWrite.All" -NoWelcome -ErrorAction Stop

    $org = Get-MgOrganization -ErrorAction Stop
    $current = $org.OnPremisesSyncEnabled
    Write-Host "Tenant: $($org.DisplayName)" -ForegroundColor Cyan
    Write-Host "Current OnPremisesSyncEnabled: $current" -ForegroundColor Cyan

    if ($current -ne $true) {
        Write-Host "Directory synchronization is already disabled. Nothing to do." -ForegroundColor Yellow
        return
    }

    Write-Host "`nWARNING: Disabling directory sync is a major tenant change." -ForegroundColor Red
    Write-Host "Objects may take up to 72 hours to become fully cloud-managed." -ForegroundColor Yellow
    $confirm = Read-Host "Disable OnPremisesSyncEnabled for this tenant? (Y/N)"
    if ($confirm -notmatch '^[Yy]$') {
        Write-Host "Cancelled." -ForegroundColor Yellow
        return
    }

    $params = @{ onPremisesSyncEnabled = $false }
    Update-MgOrganization -OrganizationId $org.Id -BodyParameter $params -ErrorAction Stop
    Write-Host "Directory synchronization disabled." -ForegroundColor Green

    $updated = Get-MgOrganization -ErrorAction Stop
    Write-Host "Verified OnPremisesSyncEnabled: $($updated.OnPremisesSyncEnabled)" -ForegroundColor Cyan
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    try { Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null } catch { }
}
