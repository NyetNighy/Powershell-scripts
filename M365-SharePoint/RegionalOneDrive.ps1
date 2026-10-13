# Set OneDrive regional locale (UK) for all personal sites via PnP.
# Adds admin as site collection owner where needed.

$AdminUrl  = "https://YOUR_TENANT-admin.sharepoint.com"
$ClientId  = "YOUR_AZURE_AD_APP_CLIENT_ID"
$AdminUser = "admin@YOUR_TENANT.onmicrosoft.com"

try {
    if (-not (Get-Module -ListAvailable -Name PnP.PowerShell)) {
        Write-Host "Installing PnP.PowerShell..." -ForegroundColor Yellow
        Install-Module PnP.PowerShell -Force -Scope CurrentUser -ErrorAction Stop
    }
    Import-Module PnP.PowerShell -Force -ErrorAction Stop

    Write-Host "Connecting to tenant admin..." -ForegroundColor Cyan
    $AdminConnection = Connect-PnPOnline `
        -Url $AdminUrl `
        -Interactive `
        -ClientId $ClientId `
        -ReturnConnection -ErrorAction Stop

    $OneDriveSites = Get-PnPTenantSite `
        -IncludeOneDriveSites `
        -Connection $AdminConnection `
        -Filter "Url -like '-my.sharepoint.com/personal/'" -ErrorAction Stop

    $success = 0
    $failed = @()

    foreach ($Site in $OneDriveSites) {
        Write-Host "Processing $($Site.Url)" -ForegroundColor Cyan

        try {
            Set-PnPTenantSite `
                -Identity $Site.Url `
                -Owners $AdminUser `
                -Connection $AdminConnection -ErrorAction Stop

            $ODConnection = Connect-PnPOnline `
                -Url $Site.Url `
                -Interactive `
                -ClientId $ClientId `
                -ReturnConnection -ErrorAction Stop

            $Web = Get-PnPWeb -Connection $ODConnection -ErrorAction Stop
            $Web.RegionalSettings.LocaleId = 2057
            $Web.Update()
            Invoke-PnPQuery -Connection $ODConnection -ErrorAction Stop

            Write-Host "Updated successfully" -ForegroundColor Green
            $success++
        }
        catch {
            Write-Host "Failed: $($_.Exception.Message)" -ForegroundColor Red
            $failed += $Site.Url
        }
    }

    Write-Host "`nDone. Success: $success / $($OneDriveSites.Count)" -ForegroundColor Cyan
    if ($failed.Count -gt 0) {
        Write-Host "Failed ($($failed.Count)):" -ForegroundColor Red
        $failed | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    }
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    try {
        Disconnect-PnPOnline -ErrorAction SilentlyContinue
    }
    catch { }
}
