$AdminUrl = "https://YOUR_TENANT-admin.sharepoint.com"
$ClientId = "YOUR_AZURE_AD_APP_CLIENT_ID"
$AdminUser = "admin@YOUR_TENANT.onmicrosoft.com"

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