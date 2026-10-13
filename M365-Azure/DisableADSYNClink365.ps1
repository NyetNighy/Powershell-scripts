# Disable directory (Azure AD Connect) sync in Microsoft 365 via Microsoft Graph.
# Prefer DisableADSYNClink365New.ps1 for the fuller (cloud + server) workflow.

try {
    if (-not (Get-Module -ListAvailable -Name Microsoft.Graph)) {
        Write-Host "Installing Microsoft.Graph..." -ForegroundColor Yellow
        Install-Module Microsoft.Graph -Force -Scope CurrentUser -ErrorAction Stop
    }
    if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Beta)) {
        Write-Host "Installing Microsoft.Graph.Beta..." -ForegroundColor Yellow
        Install-Module Microsoft.Graph.Beta -AllowClobber -Force -Scope CurrentUser -ErrorAction Stop
    }

    Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
    Connect-MgGraph -Scopes "Organization.ReadWrite.All", "Directory.ReadWrite.All" -NoWelcome -ErrorAction Stop

    $org = Get-MgOrganization -ErrorAction Stop
    Write-Host "Current OnPremisesSyncEnabled: $($org.OnPremisesSyncEnabled)" -ForegroundColor Cyan

    if ($org.OnPremisesSyncEnabled -eq $true) {
        $params = @{ onPremisesSyncEnabled = $false }
        Update-MgOrganization -OrganizationId $org.Id -BodyParameter $params -ErrorAction Stop
        Write-Host "Directory synchronization disabled." -ForegroundColor Green
    }
    else {
        Write-Host "Directory synchronization is already disabled." -ForegroundColor Yellow
    }

    $updated = Get-MgOrganization -ErrorAction Stop
    Write-Host "Verified OnPremisesSyncEnabled: $($updated.OnPremisesSyncEnabled)" -ForegroundColor Cyan
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    try {
        Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
    }
    catch { }
}
