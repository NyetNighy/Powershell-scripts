# Report Windows build/version for enabled AD computers and export to CSV.

function ConvertWindowsBuild {
    [CmdletBinding()]
    param(
        [string] $OperatingSystem,
        [string] $OperatingSystemVersion
    )
    if (($OperatingSystem -like '*Windows 10*') -or ($OperatingSystem -like 'Windows 11*')) {
        $WinBuilds = @{
            '10.0 (22621)' = "Windows 11 22H2"
            '10.0 (19045)' = "Windows 10 22H2"
            '10.0 (22000)' = "Windows 11 21H2"
            '10.0 (19044)' = "Windows 10 21H2"
            '10.0 (19043)' = "Windows 10 21H1"
            '10.0 (19042)' = "Windows 10 20H2"
            '10.0 (18362)' = "Windows 10 1903"
            '10.0 (17763)' = "Windows 10 1809"
            '10.0 (17134)' = "Windows 10 1803"
            '10.0 (16299)' = "Windows 10 1709"
            '10.0 (15063)' = "Windows 10 1703"
            '10.0 (14393)' = "Windows 10 1607"
            '10.0 (10586)' = "Windows 10 1511"
            '10.0 (10240)' = "Windows 10 1507"
            '10.0 (18898)' = 'Windows 10 Insider Preview'
        }
        $WinBuild = $WinBuilds[$OperatingSystemVersion]
    }
    else {
        $WinBuild = $OperatingSystem
    }
    if ($WinBuild) { $WinBuild } else { 'Unknown' }
}

$exportPath = "$env:USERPROFILE\Documents\windows_version_report.csv"

try {
    if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
        Write-Host "ActiveDirectory module not found. Install RSAT AD tools." -ForegroundColor Red
        exit 1
    }
    Import-Module ActiveDirectory -ErrorAction Stop

    $Comps = Get-ADComputer -Filter { Enabled -eq $True } `
        -Properties Name, IPv4Address, OperatingSystem, OperatingSystemVersion, LastLogonDate -ErrorAction Stop

    $CompList = foreach ($Comp in $Comps) {
        [PSCustomObject]@{
            Name            = $Comp.Name
            IPv4Address     = $Comp.IPv4Address
            OperatingSystem = $Comp.OperatingSystem
            Build           = ConvertWindowsBuild -OperatingSystem $Comp.OperatingSystem -OperatingSystemVersion $Comp.OperatingSystemVersion
            LastLogonDate   = $Comp.LastLogonDate
        }
    }

    $exportDir = Split-Path -Parent $exportPath
    if ($exportDir -and -not (Test-Path -LiteralPath $exportDir)) {
        New-Item -ItemType Directory -Path $exportDir -Force -ErrorAction Stop | Out-Null
    }

    $CompList | Export-Csv -Path $exportPath -NoTypeInformation -Encoding UTF8 -ErrorAction Stop
    Write-Host "Exported $($CompList.Count) computer(s) to: $exportPath" -ForegroundColor Green
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
