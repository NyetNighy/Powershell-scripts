#Requires -Version 5.1
<#
.SYNOPSIS
    Add users from a CSV to an existing Microsoft 365 / Security group.
    Prompts for Group Object ID and CSV path.
#>

$ErrorActionPreference = "Stop"

try {
    # --- Prompts ---
    $GroupId = Read-Host "Enter the Group Object ID (GUID)"
    if ([string]::IsNullOrWhiteSpace($GroupId)) {
        throw "Group Object ID is required."
    }
    $GroupId = $GroupId.Trim()

    $CsvPath = Read-Host "Enter the full path to the CSV file"
    if ([string]::IsNullOrWhiteSpace($CsvPath)) {
        throw "CSV path is required."
    }
    $CsvPath = $CsvPath.Trim().Trim('"')

    # --- Ensure PSResourceGet is available ---
    if (-not (Get-Command Install-PSResource -ErrorAction SilentlyContinue)) {
        Write-Host "Installing Microsoft.PowerShell.PSResourceGet..." -ForegroundColor Yellow
        # Bootstrap: older hosts may only have Install-Module
        Install-Module Microsoft.PowerShell.PSResourceGet -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
        Import-Module Microsoft.PowerShell.PSResourceGet -Force -ErrorAction Stop
    }

    # --- Modules (Authentication must load before Groups/Users) ---
    $requiredModules = @(
        "Microsoft.Graph.Authentication",
        "Microsoft.Graph.Groups",
        "Microsoft.Graph.Users"
    )

    foreach ($mod in $requiredModules) {
        if (-not (Get-Module -ListAvailable -Name $mod)) {
            Write-Host "Installing $mod via Install-PSResource..." -ForegroundColor Yellow
            Install-PSResource -Name $mod -Scope CurrentUser -TrustRepository -Reinstall -ErrorAction Stop
        }
    }

    Import-Module Microsoft.Graph.Authentication -Force -ErrorAction Stop
    Import-Module Microsoft.Graph.Groups -Force -ErrorAction Stop
    Import-Module Microsoft.Graph.Users -Force -ErrorAction Stop

    # --- CSV ---
    if (-not (Test-Path -LiteralPath $CsvPath)) {
        throw "CSV not found: $CsvPath"
    }

    $rows = Import-Csv -Path $CsvPath -ErrorAction Stop
    if (-not $rows -or $rows.Count -eq 0) {
        throw "CSV is empty: $CsvPath"
    }

    $upnProperty = $rows[0].PSObject.Properties.Name |
        Where-Object { $_ -match '^(UserPrincipalName|Mail|Email|UPN)$' } |
        Select-Object -First 1

    if (-not $upnProperty) {
        throw "CSV must have a column named UserPrincipalName, Mail, Email, or UPN."
    }

    $memberUpns = $rows |
        ForEach-Object { $_.$upnProperty } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        ForEach-Object { $_.Trim() } |
        Select-Object -Unique

    if ($memberUpns.Count -eq 0) {
        throw "No valid user identities found in column '$upnProperty'."
    }

    Write-Host "Found $($memberUpns.Count) unique user(s) in CSV." -ForegroundColor Cyan

    # --- Connect ---
    Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
    Connect-MgGraph -Scopes "Group.ReadWrite.All", "User.Read.All", "Directory.Read.All" -NoWelcome -ErrorAction Stop

    # --- Resolve group ---
    $group = Get-MgGroup -GroupId $GroupId -ErrorAction Stop
    Write-Host "Target group: $($group.DisplayName) ($($group.Id))" -ForegroundColor Cyan
    if ($group.Mail) {
        Write-Host "  Mail: $($group.Mail)" -ForegroundColor Gray
    }

    $confirm = Read-Host "Add $($memberUpns.Count) user(s) to this group? (Y/N)"
    if ($confirm -notmatch '^[Yy]$') {
        Write-Host "Cancelled." -ForegroundColor Yellow
        return
    }

    # --- Add members ---
    $added = 0
    $already = 0
    $failed = @()

    foreach ($upn in $memberUpns) {
        try {
            $user = Get-MgUser -Filter "userPrincipalName eq '$upn'" -ErrorAction SilentlyContinue
            if (-not $user) {
                $user = Get-MgUser -Filter "mail eq '$upn'" -ErrorAction SilentlyContinue
            }
            if (-not $user) {
                throw "User not found: $upn"
            }

            New-MgGroupMember -GroupId $group.Id -DirectoryObjectId $user.Id -ErrorAction Stop
            Write-Host "  Added: $upn" -ForegroundColor Green
            $added++
        }
        catch {
            if ($_.Exception.Message -match 'already exist|One or more added object references already exist') {
                Write-Host "  Already member: $upn" -ForegroundColor Yellow
                $already++
            }
            else {
                Write-Host "  Failed: $upn — $($_.Exception.Message)" -ForegroundColor Red
                $failed += $upn
            }
        }
    }

    Write-Host "`nDone." -ForegroundColor Cyan
    Write-Host "  Group:           $($group.DisplayName)"
    Write-Host "  Newly added:     $added"
    Write-Host "  Already members: $already"
    Write-Host "  Failed:          $($failed.Count)"
    if ($failed.Count -gt 0) {
        Write-Host "  Failed users:" -ForegroundColor Red
        $failed | ForEach-Object { Write-Host "    - $_" -ForegroundColor Red }
    }
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    try {
        Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
    }
    catch { }
}