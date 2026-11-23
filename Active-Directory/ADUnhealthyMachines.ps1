Import-Module ActiveDirectory

# Configuration
$DaysBack          = 90          # Only look at machines that logged on in the last X days
$StaleBootDays     = 30          # Flag if last boot is older than this
$LowDiskPercent    = 15          # Flag if C: free space is below this %
$OutputFile        = "C:\Temp\DomainUnhealthyMachines.csv"
$CutOffDate        = (Get-Date).AddDays(-$DaysBack)

Write-Host "Getting active computers from AD..." -ForegroundColor Green

$Computers = Get-ADComputer `
    -Filter 'Enabled -eq $true' `
    -Properties OperatingSystem, LastLogonDate, OperatingSystemVersion |
    Where-Object {
        $_.LastLogonDate -and
        $_.LastLogonDate -gt $CutOffDate
    } |
    Sort-Object Name

$total   = $Computers.Count
$counter = 0

Write-Host "Found $total active computers logged on within the last $DaysBack days." -ForegroundColor Green

$Results = foreach ($Computer in $Computers) {

    $counter++

    Write-Progress `
        -Activity "Checking Machine Health" `
        -Status "$counter of $total - $($Computer.Name)" `
        -PercentComplete (($counter / $total) * 100)

    Write-Host "[$counter/$total] Checking $($Computer.Name)..." -ForegroundColor Cyan

    try {
        $OS = Get-CimInstance -ClassName Win32_OperatingSystem -ComputerName $Computer.Name -ErrorAction Stop
        $CS = Get-CimInstance -ClassName Win32_ComputerSystem -ComputerName $Computer.Name -ErrorAction Stop
        $Disks = Get-CimInstance -ClassName Win32_LogicalDisk -ComputerName $Computer.Name -Filter "DriveType=3" -ErrorAction Stop
        $CDrive = $Disks | Where-Object { $_.DeviceID -eq "C:" }

        $LastBoot     = $OS.LastBootUpTime
        $UptimeDays   = [math]::Round(((Get-Date) - $LastBoot).TotalDays, 1)
        $FreePercent  = if ($CDrive -and $CDrive.Size -gt 0) { 
                            [math]::Round(($CDrive.FreeSpace / $CDrive.Size * 100), 1) 
                        } else { $null }

        # Health flags
        $Flags = @()
        if ($UptimeDays -ge $StaleBootDays) { $Flags += "LongUptime" }
        if ($FreePercent -ne $null -and $FreePercent -lt $LowDiskPercent) { $Flags += "LowDisk" }
        if ($OS.Version -match "^6\.") { $Flags += "OldOS" }   # Windows 7 / Server 2008 R2 era

        [PSCustomObject]@{
            ComputerName      = $Computer.Name
            OperatingSystem   = $Computer.OperatingSystem
            OSVersion         = $OS.Version
            LastLogonDate     = $Computer.LastLogonDate
            LastBootTime      = $LastBoot
            UptimeDays        = $UptimeDays
            RAM_GB            = [math]::Round(($CS.TotalPhysicalMemory / 1GB), 2)
            C_Free_GB         = if ($CDrive) { [math]::Round(($CDrive.FreeSpace / 1GB), 2) } else { $null }
            C_FreePercent     = $FreePercent
            HealthFlags       = ($Flags -join ", ")
            IsUnhealthy       = ($Flags.Count -gt 0)
            Online            = $true
            Error             = $null
        }
    }
    catch {
        [PSCustomObject]@{
            ComputerName      = $Computer.Name
            OperatingSystem   = $Computer.OperatingSystem
            OSVersion         = $null
            LastLogonDate     = $Computer.LastLogonDate
            LastBootTime      = $null
            UptimeDays        = $null
            RAM_GB            = $null
            C_Free_GB         = $null
            C_FreePercent     = $null
            HealthFlags       = "Unreachable"
            IsUnhealthy       = $true
            Online            = $false
            Error             = $_.Exception.Message
        }
    }
}

Write-Progress -Activity "Checking Machine Health" -Completed

$Results |
    Sort-Object @{ Expression = 'IsUnhealthy'; Descending = $true }, ComputerName |
    Export-Csv $OutputFile -NoTypeInformation -Encoding UTF8

$Success   = ($Results | Where-Object Online).Count
$Failed    = ($Results | Where-Object { -not $_.Online }).Count
$Unhealthy = ($Results | Where-Object IsUnhealthy).Count

Write-Host ""
Write-Host "========== SUMMARY ==========" -ForegroundColor Green
Write-Host "Total Computers : $($Results.Count)"
Write-Host "Successful      : $Success"
Write-Host "Failed          : $Failed"
Write-Host "Flagged Unhealthy: $Unhealthy"
Write-Host ""
Write-Host "Report Saved To:"
Write-Host $OutputFile -ForegroundColor Yellow
