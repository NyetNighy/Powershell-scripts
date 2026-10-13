# Export all Teams names, owners, and members to CSV.

$exportPath = "C:\temp\TeamsData.csv"

try {
    if (-not (Get-Module -ListAvailable -Name MicrosoftTeams)) {
        Write-Host "Installing MicrosoftTeams module..." -ForegroundColor Yellow
        Install-Module -Name MicrosoftTeams -Force -AllowClobber -Scope CurrentUser -ErrorAction Stop
    }
    Import-Module MicrosoftTeams -Force -ErrorAction Stop

    Write-Host "Connecting to Microsoft Teams..." -ForegroundColor Cyan
    Connect-MicrosoftTeams -ErrorAction Stop

    Write-Host "Retrieving all Teams..." -ForegroundColor Cyan
    $AllTeams = Get-Team -ErrorAction Stop

    if (-not $AllTeams -or $AllTeams.Count -eq 0) {
        Write-Host "No Teams found." -ForegroundColor Yellow
        return
    }

    $TeamList = @()
    $failed = @()

    foreach ($Team in $AllTeams) {
        try {
            $TeamGUID = $Team.GroupId
            $TeamName = $Team.DisplayName

            $users = Get-TeamUser -GroupId $Team.GroupId -ErrorAction Stop
            $TeamOwners = ($users | Where-Object { $_.Role -eq 'Owner' }).Name -join ', '
            $TeamMembers = ($users | Where-Object { $_.Role -eq 'Member' }).Name -join ', '

            $TeamList += [PSCustomObject]@{
                TeamName     = $TeamName
                TeamObjectID = $TeamGUID
                TeamOwners   = $TeamOwners
                TeamMembers  = $TeamMembers
            }
            Write-Host "OK: $TeamName" -ForegroundColor Green
        }
        catch {
            Write-Host "Failed: $($Team.DisplayName) — $($_.Exception.Message)" -ForegroundColor Red
            $failed += $Team.DisplayName
        }
    }

    $exportDir = Split-Path -Parent $exportPath
    if ($exportDir -and -not (Test-Path -LiteralPath $exportDir)) {
        New-Item -ItemType Directory -Path $exportDir -Force -ErrorAction Stop | Out-Null
    }

    $TeamList | Export-Csv -Path $exportPath -NoTypeInformation -Encoding UTF8 -ErrorAction Stop
    Write-Host "`nExported $($TeamList.Count) team(s) to: $exportPath" -ForegroundColor Cyan

    if ($failed.Count -gt 0) {
        Write-Host "Failed teams ($($failed.Count)):" -ForegroundColor Red
        $failed | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    }
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}
finally {
    try {
        Disconnect-MicrosoftTeams -ErrorAction SilentlyContinue | Out-Null
    }
    catch { }
}
