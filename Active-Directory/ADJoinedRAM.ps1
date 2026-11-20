Import-Module ActiveDirectory

# Configuration
$DaysBack = 90
$OutputFile = "C:\Temp\DomainComputerRAM.csv"
$CutOffDate = (Get-Date).AddDays(-$DaysBack)

Write-Host "Getting active computers from AD..." -ForegroundColor Green

# Get active computers only
$Computers = Get-ADComputer `
    -Filter 'Enabled -eq $true' `
    -Properties OperatingSystem, LastLogonDate |
    Where-Object {
        $_.LastLogonDate -and
        $_.LastLogonDate -gt $CutOffDate
    } |
    Sort-Object Name

$total = $Computers.Count
$counter = 0

Write-Host "Found $total active computers logged on within the last $DaysBack days." -ForegroundColor Green

$Results = foreach ($Computer in $Computers) {

    $counter++

    Write-Progress `
        -Activity "Querying Computer RAM" `
        -Status "$counter of $total - $($Computer.Name)" `
        -PercentComplete (($counter / $total) * 100)

    Write-Host "[$counter/$total] Querying $($Computer.Name)..." -ForegroundColor Cyan

    try {

        $WMI = Get-WmiObject `
            -Class Win32_ComputerSystem `
            -ComputerName $Computer.Name `
            -ErrorAction Stop

        [PSCustomObject]@{
            ComputerName    = $Computer.Name
            OperatingSystem = $Computer.OperatingSystem
            LastLogonDate   = $Computer.LastLogonDate
            RAM_GB          = [math]::Round(($WMI.TotalPhysicalMemory / 1GB), 2)
            Online          = $true
            Error           = $null
        }
    }
    catch {

        [PSCustomObject]@{
            ComputerName    = $Computer.Name
            OperatingSystem = $Computer.OperatingSystem
            LastLogonDate   = $Computer.LastLogonDate
            RAM_GB          = $null
            Online          = $false
            Error           = $_.Exception.Message
        }
    }
}

Write-Progress -Activity "Querying Computer RAM" -Completed

# Export report
$Results |
    Sort-Object OperatingSystem, ComputerName |
    Export-Csv $OutputFile -NoTypeInformation -Encoding UTF8

# Summary
$Success = ($Results | Where-Object Online).Count
$Failed = ($Results | Where-Object {-not $_.Online}).Count

Write-Host ""
Write-Host "========== SUMMARY ========== " -ForegroundColor Green
Write-Host "Total Computers : $($Results.Count)"
Write-Host "Successful      : $Success"
Write-Host "Failed          : $Failed"
Write-Host ""
Write-Host "Report Saved To:"
Write-Host $OutputFile -ForegroundColor Yellow
