param(
    [string]$InputFile,

    [string]$OutputFolder
)

if (-not $InputFile) {
    Add-Type -AssemblyName System.Windows.Forms
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Filter = 'CSV files (*.csv)|*.csv|All files (*.*)|*.*'
    $dialog.Title = 'Select sign-in logs CSV'
    $dialog.InitialDirectory = [Environment]::GetFolderPath('UserProfile') + '\Downloads'

    if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        Write-Host 'No file selected. Exiting.' -ForegroundColor Yellow
        return
    }
    $InputFile = $dialog.FileName
}

if (-not (Test-Path $InputFile)) {
    Write-Error "File not found: $InputFile"
    return
}

if (-not $OutputFolder) {
    $OutputFolder = Split-Path $InputFile -Parent
}

Write-Host "Loading CSV: $InputFile" -ForegroundColor Cyan

# Handle portal CSVs that have duplicate column names (e.g. "Incoming token type")
$raw = Get-Content -Path $InputFile -Encoding UTF8
$headerLine = $raw[0]
$headers = $headerLine -split '","' | ForEach-Object { $_.Trim('"') }

$uniqueHeaders = @()
$seen = @{}
foreach ($h in $headers) {
    if ($seen.ContainsKey($h)) {
        $seen[$h]++
        $uniqueHeaders += "$h`_$($seen[$h])"
    } else {
        $seen[$h] = 1
        $uniqueHeaders += $h
    }
}

$cleanHeader = '"' + ($uniqueHeaders -join '","') + '"'
$cleanCsv = @($cleanHeader) + $raw[1..($raw.Count - 1)]
$logs = $cleanCsv | ConvertFrom-Csv

Write-Host "Loaded $($logs.Count) rows`n" -ForegroundColor Green

# Detect format: portal export vs ExportSignLogs.ps1 format
$isPortalFormat = $null -ne ($logs[0].PSObject.Properties.Name | Where-Object { $_ -eq 'Status' -or $_ -eq 'Date (UTC)' })
$isGraphFormat  = $null -ne ($logs[0].PSObject.Properties.Name | Where-Object { $_ -eq 'StatusErrorCode' -or $_ -eq 'Country' })

if ($isPortalFormat) {
    $abroadSuccess = $logs | Where-Object {
        $_.Status -eq 'Success' -and
        $_.Location -and
        $_.Location -notlike '*, GB'
    }

    $results = $abroadSuccess | ForEach-Object {
        $parts = $_.Location -split ',\s*'
        $country = if ($parts.Count -ge 1) { $parts[-1].Trim() } else { 'Unknown' }

        [PSCustomObject]@{
            DateUTC           = $_.'Date (UTC)'
            User              = $_.User
            Username          = $_.Username
            IPAddress         = $_.'IP address'
            Location          = $_.Location
            Country           = $country
            Application       = $_.Application
            ClientApp         = $_.'Client app'
            Browser           = $_.Browser
            OperatingSystem   = $_.'Operating System'
            DeviceID          = $_.'Device ID'
            ConditionalAccess = $_.'Conditional Access'
            MFAResult         = $_.'Multifactor authentication result'
        }
    }
}
elseif ($isGraphFormat) {
    $abroadSuccess = $logs | Where-Object {
        ($_.StatusErrorCode -eq 0 -or [string]::IsNullOrWhiteSpace($_.StatusErrorCode)) -and
        $_.Country -and
        $_.Country -notin @('GB', 'United Kingdom', 'UK')
    }

    $results = $abroadSuccess | ForEach-Object {
        [PSCustomObject]@{
            DateUTC           = $_.CreatedDateTime
            User              = $_.UserDisplayName
            Username          = $_.UserPrincipalName
            IPAddress         = $_.IPAddress
            Location          = "$($_.City), $($_.State), $($_.Country)"
            Country           = $_.Country
            Application       = $_.AppDisplayName
            ClientApp         = $_.ClientAppUsed
            Browser           = $_.DeviceBrowser
            OperatingSystem   = $_.DeviceOS
            DeviceID          = $_.DeviceId
            ConditionalAccess = $_.ConditionalAccessStatus
            MFAResult         = $_.MFA_Result
        }
    }
}
else {
    Write-Error "Unrecognised CSV format. Expected portal InteractiveSignIns export or ExportSignLogs.ps1 output."
    return
}

Write-Host "Successful sign-ins from outside the UK: $($results.Count)" -ForegroundColor Yellow

if ($results.Count -eq 0) {
    Write-Host "None found." -ForegroundColor Green
} else {
    $results | Sort-Object DateUTC -Descending |
        Format-Table DateUTC, User, Username, Country, IPAddress, Application, ClientApp -AutoSize

    Write-Host "`nBy Country:" -ForegroundColor Cyan
    $results | Group-Object Country | Sort-Object Count -Descending |
        Select-Object Name, Count | Format-Table -AutoSize

    Write-Host "By User:" -ForegroundColor Cyan
    $results | Group-Object Username | Sort-Object Count -Descending |
        Select-Object Name, Count | Format-Table -AutoSize

    $exportPath = Join-Path $OutputFolder ("Successful_Abroad_{0:yyyyMMdd-HHmmss}.csv" -f (Get-Date))
    $results | Export-Csv -Path $exportPath -NoTypeInformation -Encoding UTF8
    Write-Host "`nExported to: $exportPath" -ForegroundColor Green
}
