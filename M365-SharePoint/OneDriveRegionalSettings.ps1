# Bulk-set OneDrive regional settings (locale + timezone) for all personal sites.

$adminUrl   = "https://YOUR_TENANT-admin.sharepoint.com/"   # <-- CHANGE THIS
$localeId   = 2057      # 2057 = English (United Kingdom)
$timeZoneId = 2         # 2 = GMT Standard Time (UK). Run Get-PnPTimeZoneId to see all

try {
    if (-not (Get-Module -ListAvailable -Name PnP.PowerShell)) {
        Write-Host "Installing PnP.PowerShell..." -ForegroundColor Yellow
        Install-Module PnP.PowerShell -Force -Scope CurrentUser -ErrorAction Stop
    }
    Import-Module PnP.PowerShell -Force -ErrorAction Stop

    Write-Host "Connecting to tenant admin: $adminUrl" -ForegroundColor Cyan
    Connect-PnPOnline -Url $adminUrl -Interactive -ErrorAction Stop

    $oneDriveSites = Get-PnPTenantSite -IncludeOneDriveSites `
        -Filter "Url -like '-my.sharepoint.com/personal/'" `
        -Limit All -ErrorAction Stop

    Write-Host "Found $($oneDriveSites.Count) OneDrive sites" -ForegroundColor Cyan

    $success = 0
    $failed = @()

    foreach ($site in $oneDriveSites) {
        try {
            Connect-PnPOnline -Url $site.Url -Interactive -ErrorAction Stop

            $web = Get-PnPWeb -Includes "RegionalSettings.TimeZones" -ErrorAction Stop

            $web.RegionalSettings.LocaleId = $localeId

            $tz = $web.RegionalSettings.TimeZones | Where-Object { $_.Id -eq $timeZoneId }
            if ($tz) {
                $web.RegionalSettings.TimeZone = $tz
            }

            $web.Update()
            Invoke-PnPQuery -ErrorAction Stop

            Write-Host "Updated: $($site.Url)" -ForegroundColor Green
            $success++
        }
        catch {
            Write-Host "Failed: $($site.Url) - $($_.Exception.Message)" -ForegroundColor Red
            $failed += $site.Url
        }
    }

    Write-Host "`nDone. Success: $success / $($oneDriveSites.Count)" -ForegroundColor Cyan
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
