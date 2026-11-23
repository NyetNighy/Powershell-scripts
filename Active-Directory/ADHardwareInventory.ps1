Import-Module ActiveDirectory

# Configuration
$DaysBack   = 90
$OutputFile = "C:\Temp\DomainHardwareInventory.csv"
$CutOffDate = (Get-Date).AddDays(-$DaysBack)

Write-Host "Getting active computers from AD..." -ForegroundColor Green

$Computers = Get-ADComputer `
    -Filter 'Enabled -eq $true' `
    -Properties OperatingSystem, LastLogonDate |
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
        -Activity "Querying Hardware Inventory" `
        -Status "$counter of $total - $($Computer.Name)" `
        -PercentComplete (($counter / $total) * 100)

    Write-Host "[$counter/$total] Querying $($Computer.Name)..." -ForegroundColor Cyan

    try {
        # Computer System (Model + RAM)
        $CS = Get-CimInstance -ClassName Win32_ComputerSystem -ComputerName $Computer.Name -ErrorAction Stop

        # BIOS (Serial)
        $BIOS = Get-CimInstance -ClassName Win32_BIOS -ComputerName $Computer.Name -ErrorAction Stop

        # CPU
        $CPU = Get-CimInstance -ClassName Win32_Processor -ComputerName $Computer.Name -ErrorAction Stop | Select-Object -First 1

        # Logical Disks (C: drive focus + total)
        $Disks = Get-CimInstance -ClassName Win32_LogicalDisk -ComputerName $Computer.Name -Filter "DriveType=3" -ErrorAction Stop
        $CDrive = $Disks | Where-Object { $_.DeviceID -eq "C:" }

        [PSCustomObject]@{
            ComputerName     = $Computer.Name
            OperatingSystem  = $Computer.OperatingSystem
            LastLogonDate    = $Computer.LastLogonDate
            Manufacturer     = $CS.Manufacturer
            Model            = $CS.Model
            SerialNumber     = $BIOS.SerialNumber
            RAM_GB           = [math]::Round(($CS.TotalPhysicalMemory / 1GB), 2)
            CPU_Name         = $CPU.Name
            CPU_Cores        = $CPU.NumberOfCores
            CPU_Logical      = $CPU.NumberOfLogicalProcessors
            CPU_MaxClockMHz  = $CPU.MaxClockSpeed
            C_Total_GB       = if ($CDrive) { [math]::Round(($CDrive.Size / 1GB), 2) } else { $null }
            C_Free_GB        = if ($CDrive) { [math]::Round(($CDrive.FreeSpace / 1GB), 2) } else { $null }
            C_FreePercent    = if ($CDrive -and $CDrive.Size -gt 0) { 
                                  [math]::Round(($CDrive.FreeSpace / $CDrive.Size * 100), 1) 
                               } else { $null }
            Online           = $true
            Error            = $null
        }
    }
    catch {
        [PSCustomObject]@{
            ComputerName     = $Computer.Name
            OperatingSystem  = $Computer.OperatingSystem
            LastLogonDate    = $Computer.LastLogonDate
            Manufacturer     = $null
            Model            = $null
            SerialNumber     = $null
            RAM_GB           = $null
            CPU_Name         = $null
            CPU_Cores        = $null
            CPU_Logical      = $null
            CPU_MaxClockMHz  = $null
            C_Total_GB       = $null
            C_Free_GB        = $null
            C_FreePercent    = $null
            Online           = $false
            Error            = $_.Exception.Message
        }
    }
}

Write-Progress -Activity "Querying Hardware Inventory" -Completed

$Results |
    Sort-Object OperatingSystem, ComputerName |
    Export-Csv $OutputFile -NoTypeInformation -Encoding UTF8

$Success = ($Results | Where-Object Online).Count
$Failed  = ($Results | Where-Object { -not $_.Online }).Count

Write-Host ""
Write-Host "========== SUMMARY ==========" -ForegroundColor Green
Write-Host "Total Computers : $($Results.Count)"
Write-Host "Successful      : $Success"
Write-Host "Failed          : $Failed"
Write-Host ""
Write-Host "Report Saved To:"
Write-Host $OutputFile -ForegroundColor Yellow
