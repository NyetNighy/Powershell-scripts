# Requires Active Directory module (RSAT tools)
# Run with domain admin or equivalent rights to read computer objects and msFVE-RecoveryInformation

Import-Module ActiveDirectory

# Define "active in last year" — adjust days if needed (365 for a full year)
$daysActive = 365
$cutoffDate = (Get-Date).AddDays(-$daysActive)

# Get only enabled computers that have logged on to the domain in the last year
# LastLogonDate is replicated and reliable for this purpose
$activeComputers = Get-ADComputer -Filter {Enabled -eq $true -and LastLogonDate -ge $cutoffDate} `
                                 -Properties LastLogonDate, DistinguishedName

Write-Output "Found $($activeComputers.Count) active computers in the last $daysActive days."

$enabledCount = 0
$disabledCount = 0

foreach ($computer in $activeComputers) {
    # Check for BitLocker recovery objects directly under the computer object
    $recoveryObjects = Get-ADObject -Filter {objectClass -eq "msFVE-RecoveryInformation"} `
                                    -SearchBase $computer.DistinguishedName `
                                    -SearchScope OneLevel `
                                    -ErrorAction SilentlyContinue
    
    if ($recoveryObjects) {
        $enabledCount++
    } else {
        $disabledCount++
    }
}

# Output results
Write-Output ""
Write-Output "Among active computers (last logon within last $daysActive days):"
Write-Output "  Computers with BitLocker entries (enabled & backed up to AD): $enabledCount"
Write-Output "  Computers without BitLocker entries (likely disabled or not backed up): $disabledCount"
Write-Output "  Ratio (BitLocker enabled)/(BitLocker disabled) = $enabledCount / $disabledCount"

if ($enabledCount + $disabledCount -gt 0) {
    $percentage = [math]::Round(($enabledCount / ($enabledCount + $disabledCount)) * 100, 2)
    Write-Output "  Percentage with BitLocker enabled: $percentage%"
}