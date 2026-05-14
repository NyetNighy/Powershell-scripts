$AdminUrl = "https://YOURTENANT-admin.sharepoint.com"
$ClientId = "YOUR-CLIENT-ID"
$AdminUser = "365AdminUser"

# Connect once
$AdminConnection = Connect-PnPOnline `
    -Url $AdminUrl `
    -Interactive `
    -ClientId $ClientId `
    -ReturnConnection

# Get OneDrive sites
$OneDriveSites = Get-PnPTenantSite `
    -IncludeOneDriveSites `
    -Connection $AdminConnection `
    -Filter "Url -like '-my.sharepoint.com/personal/'"

foreach ($Site in $OneDriveSites)
{
    Write-Host "Processing $($Site.Url)" -ForegroundColor Cyan

    try
    {
        # Add yourself as Site Collection Admin
        Set-PnPTenantSite `
            -Identity $Site.Url `
            -Owners $AdminUser `
            -Connection $AdminConnection

        # Connect to OneDrive
        $ODConnection = Connect-PnPOnline `
            -Url $Site.Url `
            -Interactive `
            -ClientId $ClientId `
            -ReturnConnection

        # Get web
        $Web = Get-PnPWeb -Connection $ODConnection

        # Regional settings
        $Web.RegionalSettings.LocaleId = 2057
        $Web.Update()

        Invoke-PnPQuery -Connection $ODConnection

        Write-Host "Updated successfully" -ForegroundColor Green
    }
    catch
    {
        Write-Host "Failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}