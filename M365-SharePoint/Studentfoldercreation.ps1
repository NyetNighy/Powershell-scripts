# Create student folders (and subfolders) in a SharePoint document library from a CSV.
# CSV columns expected: Surname, Forname (or Forename).

$SiteUrl     = "https://yourdoamin.sharepoint.com/sites/PupilFilesNew"
$LibraryName = "Shared Documents"
$CSVPath     = "C:\Powershell\students.csv"

$Subfolders = @(
    "FOLDERNAME", "FOLDERNAME", "FOLDERNAME", "FOLDERNAME"
)

$TenantId = "YOUR_TENANT.onmicrosoft.com"

if (-not (Test-Path -LiteralPath $CSVPath)) {
    Write-Host "CSV not found: $CSVPath" -ForegroundColor Red
    exit 1
}

$Body = @{
    client_id = "14d82eec-204b-4c2f-b7e8-296a70dab67e"
    scope     = "https://graph.microsoft.com/.default"
    tenant    = $TenantId
}

try {
    Write-Host "Opening device login. Go to https://microsoft.com/devicelogin and enter the code shown below..." -ForegroundColor Yellow
    $DeviceCodeRequest = Invoke-RestMethod -Method POST `
        -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/devicecode" `
        -Body $Body -ContentType "application/x-www-form-urlencoded" -ErrorAction Stop

    Write-Host "Device Code: $($DeviceCodeRequest.user_code)" -ForegroundColor Cyan
    Write-Host $DeviceCodeRequest.message -ForegroundColor White

    $TokenBody = @{
        grant_type  = "urn:ietf:params:oauth:grant-type:device_code"
        client_id   = $Body.client_id
        device_code = $DeviceCodeRequest.device_code
        tenant      = $TenantId
    }

    $TokenResponse = $null
    $maxAttempts = 40
    $attempt = 0
    do {
        Start-Sleep -Seconds 3
        $attempt++
        try {
            $TokenResponse = Invoke-RestMethod -Method POST `
                -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" `
                -Body $TokenBody -ContentType "application/x-www-form-urlencoded" -ErrorAction Stop
        }
        catch {
            $errBody = $null
            try { $errBody = $_.ErrorDetails.Message | ConvertFrom-Json } catch { }
            if ($errBody -and $errBody.error -eq "authorization_pending") {
                if ($attempt -ge $maxAttempts) { throw "Device login timed out." }
                continue
            }
            throw
        }
    } while (-not $TokenResponse.access_token)

    $Token = $TokenResponse.access_token
    $Headers = @{ Authorization = "Bearer $Token"; "Content-Type" = "application/json" }
    Write-Host "Successfully authenticated!" -ForegroundColor Green

    $SiteRelative = $SiteUrl -replace "https://[^/]+", ""
    $Site = Invoke-RestMethod -Method GET `
        -Uri "https://graph.microsoft.com/v1.0/sites/root:$SiteRelative" `
        -Headers $Headers -ErrorAction Stop

    $Drive = Invoke-RestMethod -Method GET `
        -Uri "https://graph.microsoft.com/v1.0/sites/$($Site.id)/drives" `
        -Headers $Headers -ErrorAction Stop |
        Select-Object -ExpandProperty value |
        Where-Object { $_.name -eq $LibraryName -or $_.name -eq "Documents" }

    if (-not $Drive) {
        Write-Host "Could not find library '$LibraryName'." -ForegroundColor Red
        exit 1
    }

    Write-Host "Connected to library: $($Drive.name)" -ForegroundColor Green

    $People = Import-Csv -Path $CSVPath -ErrorAction Stop
    $created = 0
    $skipped = 0
    $errors = 0

    foreach ($Person in $People) {
        $Surname  = ($Person.Surname  ?? "").Trim()
        $Forename = if ($Person.Forname) { ($Person.Forname).Trim() } elseif ($Person.Forename) { ($Person.Forename).Trim() } else { "" }

        if ([string]::IsNullOrWhiteSpace($Surname) -or [string]::IsNullOrWhiteSpace($Forename)) {
            Write-Warning "Skipping row with missing name"
            $skipped++
            continue
        }

        $PersonFolderName = "$Surname, $Forename"
        Write-Host "`nProcessing: $PersonFolderName" -ForegroundColor Cyan

        $BodyMain = @{
            name = $PersonFolderName
            folder = @{}
            "@microsoft.graph.conflictBehavior" = "rename"
        } | ConvertTo-Json

        try {
            $null = Invoke-RestMethod -Method GET `
                -Uri "https://graph.microsoft.com/v1.0/drives/$($Drive.id)/root:/$([uri]::EscapeDataString($PersonFolderName))" `
                -Headers $Headers -ErrorAction Stop
            Write-Host "   Already exists" -ForegroundColor Yellow
        }
        catch {
            try {
                $null = Invoke-RestMethod -Method POST `
                    -Uri "https://graph.microsoft.com/v1.0/drives/$($Drive.id)/root/children" `
                    -Headers $Headers -Body $BodyMain -ErrorAction Stop
                Write-Host "   Created folder: $PersonFolderName" -ForegroundColor Green
                $created++
            }
            catch {
                Write-Host "   Failed to create folder: $($_.Exception.Message)" -ForegroundColor Red
                $errors++
                continue
            }
        }

        foreach ($Sub in $Subfolders) {
            $BodySub = @{
                name = $Sub
                folder = @{}
                "@microsoft.graph.conflictBehavior" = "rename"
            } | ConvertTo-Json

            try {
                $null = Invoke-RestMethod -Method GET `
                    -Uri "https://graph.microsoft.com/v1.0/drives/$($Drive.id)/root:/$([uri]::EscapeDataString($PersonFolderName))/$([uri]::EscapeDataString($Sub))" `
                    -Headers $Headers -ErrorAction Stop
                Write-Host "      Already exists: $Sub" -ForegroundColor Gray
            }
            catch {
                try {
                    $null = Invoke-RestMethod -Method POST `
                        -Uri "https://graph.microsoft.com/v1.0/drives/$($Drive.id)/root:/$([uri]::EscapeDataString($PersonFolderName)):/children" `
                        -Headers $Headers -Body $BodySub -ErrorAction Stop
                    Write-Host "      Created: $Sub" -ForegroundColor Green
                }
                catch {
                    Write-Host "      Failed subfolder '$Sub': $($_.Exception.Message)" -ForegroundColor Red
                    $errors++
                }
            }
        }
    }

    Write-Host "`n=== Done. Created: $created | Skipped rows: $skipped | Errors: $errors ===" -ForegroundColor Magenta
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
