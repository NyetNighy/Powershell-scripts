# Count active AD computers with BitLocker recovery info backed up to AD.
# Requires Active Directory module (RSAT) and rights to read computer objects / msFVE-RecoveryInformation.

try {
    if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
        Write-Host "ActiveDirectory module not found. Install RSAT AD tools." -ForegroundColor Red
        exit 1
    }
    Import-Module ActiveDirectory -ErrorAction Stop

    $daysActive = 365
    $cutoffDate = (Get-Date).AddDays(-$daysActive)

    Write-Host "Querying enabled computers with last logon within $daysActive days..." -ForegroundColor Cyan
    $activeComputers = Get-ADComputer -Filter { Enabled -eq $true -and LastLogonDate -ge $cutoffDate } `
        -Properties LastLogonDate, DistinguishedName -ErrorAction Stop

    Write-Output "Found $($activeComputers.Count) active computers in the last $daysActive days."

    $enabledCount = 0
    $disabledCount = 0

    foreach ($computer in $activeComputers) {
        $recoveryObjects = Get-ADObject -Filter { objectClass -eq "msFVE-RecoveryInformation" } `
            -SearchBase $computer.DistinguishedName `
            -SearchScope OneLevel `
            -ErrorAction SilentlyContinue

        if ($recoveryObjects) {
            $enabledCount++
        }
        else {
            $disabledCount++
        }
    }

    Write-Output ""
    Write-Output "Among active computers (last logon within last $daysActive days):"
    Write-Output "  Computers with BitLocker entries (enabled & backed up to AD): $enabledCount"
    Write-Output "  Computers without BitLocker entries (likely disabled or not backed up): $disabledCount"
    Write-Output "  Ratio (BitLocker enabled)/(BitLocker disabled) = $enabledCount / $disabledCount"

    if ($enabledCount + $disabledCount -gt 0) {
        $percentage = [math]::Round(($enabledCount / ($enabledCount + $disabledCount)) * 100, 2)
        Write-Output "  Percentage with BitLocker enabled: $percentage%"
    }
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
