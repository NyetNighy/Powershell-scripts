#Requires -Version 5.1
<#
.SYNOPSIS
    Create student folders (and optional subfolders) in a SharePoint document library from a CSV.
    CSV columns: Surname, Forname (or Forename).
    All site/library/CSV values are prompted interactively.
#>

$ErrorActionPreference = "Stop"

try {
    $SiteUrl = Read-Host "SharePoint site URL (e.g. https://contoso.sharepoint.com/sites/PupilFiles)"
    if ([string]::IsNullOrWhiteSpace($SiteUrl)) { throw "Site URL is required." }
    $SiteUrl = $SiteUrl.Trim().TrimEnd('/')

    $LibraryName = Read-Host "Document library name (default: Shared Documents)"
    if ([string]::IsNullOrWhiteSpace($LibraryName)) { $LibraryName = "Shared Documents" }
    $LibraryName = $LibraryName.Trim()

    $CsvPath = Read-Host "Full path to students CSV (columns: Surname, Forname/Forename)"
    if ([string]::IsNullOrWhiteSpace($CsvPath)) { throw "CSV path is required." }
    $CsvPath = $CsvPath.Trim().Trim('"')

    if (-not (Test-Path -LiteralPath $CsvPath)) {
        throw "CSV not found: $CsvPath"
    }

    $subInput = Read-Host "Subfolder names to create under each student (comma-separated, or leave blank for none)"
    $Subfolders = @()
    if (-not [string]::IsNullOrWhiteSpace($subInput)) {
        $Subfolders = $subInput -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    }

    $TenantId = Read-Host "Tenant domain (e.g. contoso.onmicrosoft.com)"
    if ([string]::IsNullOrWhiteSpace($TenantId)) { throw "Tenant domain is required." }
    $TenantId = $TenantId.Trim()

    $People = Import-Csv -Path $CsvPath -ErrorAction Stop
    if (-not $People -or $People.Count -eq 0) {
        throw "CSV is empty."
    }

    Write-Host "`nSummary:" -ForegroundColor Cyan
    Write-Host "  Site:     $SiteUrl"
    Write-Host "  Library:  $LibraryName"
    Write-Host "  CSV rows: $($People.Count)"
    Write-Host "  Subfolders: $(if ($Subfolders.Count) { $Subfolders -join ', ' } else { '(none)' })"

    $confirm = Read-Host "`nCreate folders for these students? (Y/N)"
    if ($confirm -notmatch '^[Yy]$') {
        Write-Host "Cancelled." -ForegroundColor Yellow
        return
    }

    $Body = @{
        client_id = "14d82eec-204b-4c2f-b7e8-296a70dab67e"
        scope     = "https://graph.microsoft.com/.default"
        tenant    = $TenantId
    }

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
        Where-Object { $_.name -eq $LibraryName -or $_.name -eq "Documents" } |
        Select-Object -First 1

    if (-not $Drive) {
        throw "Could not find library '$LibraryName'."
    }

    Write-Host "Connected to library: $($Drive.name)" -ForegroundColor Green

    $created = 0
    $skipped = 0
    $errors = 0

    foreach ($Person in $People) {
        $Surname  = ("$($Person.Surname)").Trim()
        $Forename = if ($Person.Forname) { ("$($Person.Forname)").Trim() }
                    elseif ($Person.Forename) { ("$($Person.Forename)").Trim() }
                    else { "" }

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
