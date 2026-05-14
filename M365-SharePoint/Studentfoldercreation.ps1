
$SiteUrl     = "https://yourdoamin.sharepoint.com/sites/PupilFilesNew"
$LibraryName = "Shared Documents"          # Exact name of your document library
$CSVPath     = "C:\Powershell\students.csv"

$Subfolders = @(
    "FOLDERNAME", "FOLDERNAME", "FOLDERNAME", "FOLDERNAME"
)

$TenantId = "YOUR_TENANT.onmicrosoft.com"   

$Body = @{
    client_id = "14d82eec-204b-4c2f-b7e8-296a70dab67e"   # Well-known PowerShell Graph client ID
    scope     = "https://graph.microsoft.com/.default"
    tenant    = $TenantId
}

Write-Host "Opening device login. Go to https://microsoft.com/devicelogin and enter the code shown below..." -ForegroundColor Yellow
$DeviceCodeRequest = Invoke-RestMethod -Method POST -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/devicecode" -Body $Body -ContentType "application/x-www-form-urlencoded"

Write-Host "Device Code: $($DeviceCodeRequest.user_code)" -ForegroundColor Cyan
Write-Host $DeviceCodeRequest.message -ForegroundColor White

# Poll for token
$TokenBody = @{
    grant_type  = "urn:ietf:params:oauth:grant-type:device_code"
    client_id   = $Body.client_id
    device_code = $DeviceCodeRequest.device_code
    tenant      = $TenantId
}

do {
    Start-Sleep -Seconds 3
    try {
        $TokenResponse = Invoke-RestMethod -Method POST -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" -Body $TokenBody -ContentType "application/x-www-form-urlencoded"
    } catch {
        $ErrorMessage = $_.ErrorDetails.Message | ConvertFrom-Json
        if ($ErrorMessage.error -ne "authorization_pending") { throw }
    }
} while (-not $TokenResponse.access_token)

$Token = $TokenResponse.access_token
$Headers = @{ Authorization = "Bearer $Token"; "Content-Type" = "application/json" }

Write-Host "Successfully authenticated!" -ForegroundColor Green

$SiteRelative = $SiteUrl -replace "https://[^/]+", ""
$Site = Invoke-RestMethod -Method GET -Uri "https://graph.microsoft.com/v1.0/sites/root:$SiteRelative" -Headers $Headers
$Drive = Invoke-RestMethod -Method GET -Uri "https://graph.microsoft.com/v1.0/sites/$($Site.id)/drives" -Headers $Headers | 
         Select-Object -ExpandProperty value | Where-Object { $_.name -eq $LibraryName -or $_.name -eq "Documents" }

if (-not $Drive) { Write-Error "Could not find library '$LibraryName'"; exit }

Write-Host "Connected to library: $($Drive.name)" -ForegroundColor Green


$People = Import-Csv -Path $CSVPath

foreach ($Person in $People) {
    $Surname  = ($Person.Surname  ?? "").Trim()
    $Forename = ($Person.Forname ?? "").Trim()

    if ([string]::IsNullOrWhiteSpace($Surname) -or [string]::IsNullOrWhiteSpace($Forename)) {
        Write-Warning "Skipping row with missing name"
        continue
    }

    $PersonFolderName = "$Surname, $Forename"
    Write-Host "`nProcessing: $PersonFolderName" -ForegroundColor Cyan

    # Create main person folder
    $BodyMain = @{ 
        name = $PersonFolderName
        folder = @{}
        "@microsoft.graph.conflictBehavior" = "rename"
    } | ConvertTo-Json

    try {
        $null = Invoke-RestMethod -Method GET -Uri "https://graph.microsoft.com/v1.0/drives/$($Drive.id)/root:/$([uri]::EscapeDataString($PersonFolderName))" -Headers $Headers -ErrorAction Stop
        Write-Host "   Already exists" -ForegroundColor Yellow
    } catch {
        $null = Invoke-RestMethod -Method POST -Uri "https://graph.microsoft.com/v1.0/drives/$($Drive.id)/root/children" -Headers $Headers -Body $BodyMain
        Write-Host "   Created folder: $PersonFolderName" -ForegroundColor Green
    }


    foreach ($Sub in $Subfolders) {
        $BodySub = @{ 
            name = $Sub
            folder = @{}
            "@microsoft.graph.conflictBehavior" = "rename"
        } | ConvertTo-Json

        try {
            $null = Invoke-RestMethod -Method GET -Uri "https://graph.microsoft.com/v1.0/drives/$($Drive.id)/root:/$([uri]::EscapeDataString($PersonFolderName))/$([uri]::EscapeDataString($Sub))" -Headers $Headers -ErrorAction Stop
            Write-Host "      Already exists: $Sub" -ForegroundColor Gray
        } catch {
            $null = Invoke-RestMethod -Method POST -Uri "https://graph.microsoft.com/v1.0/drives/$($Drive.id)/root:/$([uri]::EscapeDataString($PersonFolderName)):/children" -Headers $Headers -Body $BodySub
            Write-Host "      Created: $Sub" -ForegroundColor Green
        }
    }
}

Write-Host "`n=== All done! ===" -ForegroundColor Magenta