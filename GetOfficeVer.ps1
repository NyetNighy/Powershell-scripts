function Get-OfficeVersion {
    try {
        $officeSoftware = Get-CimInstance -Query "SELECT * FROM Win32_Product WHERE Name LIKE 'Microsoft Office%'" | Select-Object -First 1 -ErrorAction Stop
        $officeVersion = $officeSoftware.Version
        $officeVersion
    } catch {
        Write-Host "Error getting Office version: $_"
        'Office Version Not Found'
    }
}

function Get-ADComputer {
    param (
        [string]$Filter
    )

    $root = [ADSI]""
    $searcher = [adsisearcher]$root
    $searcher.Filter = "(&(objectClass=computer)$Filter)"
    $searcher.FindAll() | ForEach-Object {
        [PSCustomObject]@{
            Name          = $_.Properties['name'][0]
            IPv4Address   = $_.Properties['ipv4Address'][0]
            LastLogonDate = $_.Properties['lastLogon'][0]
            OperatingSystem = $_.Properties['operatingSystem'][0]
        }
    }
}

try {
    Write-Host "Script Start"
    
    # Use ADSI to query Active Directory
    $Comps = Get-ADComputer -Filter "(operatingSystem=*)"
    Write-Host "AD Query Completed"
    
    $CompList = foreach ($Comp in $Comps) {
        Write-Host "Processing Computer: $($Comp.Name)"
        [PSCustomObject]@{
            Name           = $Comp.Name
            IPv4Address    = $Comp.IPv4Address
            LastLogonDate  = $Comp.LastLogonDate
            OfficeVersion  = Get-OfficeVersion
        }
    }

    Write-Host "Exporting to CSV"
    $CompList | Export-Csv -Path C:\Users\Control\Desktop\combined_results.csv -NoTypeInformation

    Write-Host "Script Completed"
} catch {
    Write-Host "Error: $_"
}
