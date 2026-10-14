#Requires -Version 5.1
<#
.SYNOPSIS
    Bulk-set OneDrive regional settings (locale + timezone) for all personal sites via PnP.
    Prompts for admin URL, locale, and timezone; requires confirmation before looping sites.
#>

$ErrorActionPreference = "Stop"

try {
    $adminUrl = Read-Host "SharePoint admin URL (e.g. https://contoso-admin.sharepoint.com)"
    if ([string]::IsNullOrWhiteSpace($adminUrl)) { throw "Admin URL is required." }
    $adminUrl = $adminUrl.Trim().TrimEnd('/') + "/"

    Write-Host "`nCommon locale IDs: 2057 = English (UK), 1033 = English (US), 3081 = English (AU)" -ForegroundColor Gray
    $localeInput = Read-Host "Locale ID (default: 2057 UK)"
    $localeId = 2057
    if (-not [string]::IsNullOrWhiteSpace($localeInput)) {
        if (-not [int]::TryParse($localeInput.Trim(), [ref]$localeId)) {
            throw "Invalid locale ID."
        }
    }

    Write-Host "Common timezone IDs: 2 = GMT (UK), 13 = Eastern (US), 4 = Pacific (US). Run Get-PnPTimeZoneId after connect for full list." -ForegroundColor Gray
    $tzInput = Read-Host "Time zone ID (default: 2 GMT)"
    $timeZoneId = 2
    if (-not [string]::IsNullOrWhiteSpace($tzInput)) {
        if (-not [int]::TryParse($tzInput.Trim(), [ref]$timeZoneId)) {
            throw "Invalid time zone ID."
        }
    }

    Write-Host "`nWill set LocaleId=$localeId and TimeZoneId=$timeZoneId on all OneDrive personal sites under:" -ForegroundColor Yellow
    Write-Host "  $adminUrl"
    $confirm = Read-Host "Proceed? (Y/N)"
    if ($confirm -notmatch '^[Yy]$') {
        Write-Host "Cancelled." -ForegroundColor Yellow
        return
    }

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

    if ($oneDriveSites.Count -eq 0) {
        Write-Host "Nothing to update." -ForegroundColor Yellow
        return
    }

    $confirm2 = Read-Host "Update regional settings on $($oneDriveSites.Count) site(s)? (Y/N)"
    if ($confirm2 -notmatch '^[Yy]$') {
        Write-Host "Cancelled." -ForegroundColor Yellow
        return
    }

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
    try { Disconnect-PnPOnline -ErrorAction SilentlyContinue } catch { }
}
