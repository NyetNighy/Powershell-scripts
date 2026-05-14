# === CONFIGURATION ===
$adminUrl = "https://bcteccouk-admin.sharepoint.com/"   # <-- CHANGE THIS
$localeId   = 2057      # 2057 = English (United Kingdom)
$timeZoneId = 2         # 2 = GMT Standard Time (UK). Run Get-PnPTimeZoneId to see all

# Connect to Tenant Admin Center
Connect-PnPOnline -Url $adminUrl -Interactive

# Get all OneDrive sites
$oneDriveSites = Get-PnPTenantSite -IncludeOneDriveSites `
                    -Filter "Url -like '-my.sharepoint.com/personal/'" `
                    -Limit All

Write-Host "Found $($oneDriveSites.Count) OneDrive sites" -ForegroundColor Cyan

foreach ($site in $oneDriveSites) {
    try {
        Connect-PnPOnline -Url $site.Url -Interactive -ErrorAction Stop
        
        $web = Get-PnPWeb -Includes "RegionalSettings.TimeZones"
        
        # Set Locale
        $web.RegionalSettings.LocaleId = $localeId
        
        # Set Time Zone
        $tz = $web.RegionalSettings.TimeZones | Where-Object { $_.Id -eq $timeZoneId }
        if ($tz) {
            $web.RegionalSettings.TimeZone = $tz
        }
        
        $web.Update()
        Invoke-PnPQuery
        
        Write-Host "✅ Updated: $($site.Url)" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Failed: $($site.Url) - $($_.Exception.Message)" -ForegroundColor Red
    }
}