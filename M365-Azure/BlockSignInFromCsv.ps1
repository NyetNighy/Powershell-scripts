#Requires -Version 5.1
<#
.SYNOPSIS
    Disable sign-in (AccountEnabled = false) for users listed in a CSV.
    Replaces the old General-Reference/Emaildisable.ps1 (AzureAD module).
    CSV column: Email, EmailAddress, UserPrincipalName, UPN, or Mail.
#>

$ErrorActionPreference = "Stop"

try {
    $CsvPath = Read-Host "Enter the full path to the CSV file"
    if ([string]::IsNullOrWhiteSpace($CsvPath)) { throw "CSV path is required." }
    $CsvPath = $CsvPath.Trim().Trim('"')

    if (-not (Test-Path -LiteralPath $CsvPath)) {
        throw "CSV not found: $CsvPath"
    }

    $rows = Import-Csv -Path $CsvPath -ErrorAction Stop
    if (-not $rows -or $rows.Count -eq 0) {
        throw "CSV is empty."
    }

    $idCol = $rows[0].PSObject.Properties.Name |
        Where-Object { $_ -match '^(UserPrincipalName|UPN|Mail|Email|EmailAddress)$' } |
        Select-Object -First 1

    if (-not $idCol) {
        throw "CSV must have a column named UserPrincipalName, UPN, Mail, Email, or EmailAddress."
    }

    $idents = $rows |
        ForEach-Object { ($_.$idCol ?? "").Trim() } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Select-Object -Unique

    if ($idents.Count -eq 0) {
        throw "No valid identities found in column '$idCol'."
    }

    Write-Host "`nFound $($idents.Count) unique identity(ies). Preview (first 15):" -ForegroundColor Cyan
    $idents | Select-Object -First 15 | ForEach-Object { Write-Host "  $_" }
    if ($idents.Count -gt 15) {
        Write-Host "  ... and $($idents.Count - 15) more"
    }

    $confirm = Read-Host "`nDisable sign-in (AccountEnabled = false) for these users? (Y/N)"
    if ($confirm -notmatch '^[Yy]$') {
        Write-Host "Cancelled." -ForegroundColor Yellow
        return
    }

    if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
        Write-Host "Installing Microsoft.Graph modules..." -ForegroundColor Yellow
        Install-Module Microsoft.Graph.Authentication, Microsoft.Graph.Users -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
    }
    Import-Module Microsoft.Graph.Authentication -Force -ErrorAction Stop
    Import-Module Microsoft.Graph.Users -Force -ErrorAction Stop

    Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
    Connect-MgGraph -Scopes "User.ReadWrite.All" -NoWelcome -ErrorAction Stop

    $ok = 0
    $failed = @()

    foreach ($id in $idents) {
        try {
            $user = Get-MgUser -Filter "userPrincipalName eq '$id'" -ErrorAction SilentlyContinue
            if (-not $user) {
                $user = Get-MgUser -Filter "mail eq '$id'" -ErrorAction SilentlyContinue
            }
            if (-not $user) { throw "User not found" }

            Update-MgUser -UserId $user.Id -AccountEnabled:$false -ErrorAction Stop
            Write-Host "  Blocked sign-in: $($user.UserPrincipalName)" -ForegroundColor Green
            $ok++
        }
        catch {
            Write-Host "  Failed: $id — $($_.Exception.Message)" -ForegroundColor Red
            $failed += $id
        }
    }

    Write-Host "`nDone. Blocked: $ok | Failed: $($failed.Count)" -ForegroundColor Cyan
    if ($failed.Count -gt 0) {
        $failed | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    }
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    try { Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null } catch { }
}
