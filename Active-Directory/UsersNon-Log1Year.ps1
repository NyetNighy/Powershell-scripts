# Find enabled AD users with no logon in the last year and export to CSV.

$exportPath = "C:\Temp\InactiveUsers_Over1Year.csv"

try {
    if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
        Write-Host "ActiveDirectory module not found. Install RSAT AD tools." -ForegroundColor Red
        exit 1
    }
    Import-Module ActiveDirectory -ErrorAction Stop

    $CutoffDate = (Get-Date).AddDays(-365)

    $report = Get-ADUser -Filter {
        LastLogonTimeStamp -lt $CutoffDate -and
        Enabled -eq $true
    } -Properties LastLogonTimeStamp, whenCreated, Description -ErrorAction Stop |
        Select-Object Name,
            SamAccountName,
            UserPrincipalName,
            Enabled,
            @{Name = 'Last Logon'; Expression = {
                if ($_.LastLogonTimeStamp) {
                    [DateTime]::FromFileTime($_.LastLogonTimeStamp)
                }
                else { "Never" }
            }},
            @{Name = 'Account Created'; Expression = { $_.whenCreated }},
            Description |
        Sort-Object 'Last Logon'

    $report | Format-Table -AutoSize

    $exportDir = Split-Path -Parent $exportPath
    if ($exportDir -and -not (Test-Path -LiteralPath $exportDir)) {
        New-Item -ItemType Directory -Path $exportDir -Force -ErrorAction Stop | Out-Null
    }

    $report | Export-Csv -Path $exportPath -NoTypeInformation -Encoding UTF8 -ErrorAction Stop
    Write-Host "Exported $($report.Count) user(s) to: $exportPath" -ForegroundColor Green
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
