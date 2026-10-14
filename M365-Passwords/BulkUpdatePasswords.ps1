#Requires -Version 5.1
<#
.SYNOPSIS
    Bulk-set Microsoft 365 passwords from a CSV (UserPrincipalName + Password columns).
    Interactive: prompts for CSV path, previews users, requires confirmation.
    Uses Microsoft Graph (MSOnline/AzureAD are deprecated).
#>

$ErrorActionPreference = "Stop"

try {
    $CsvPath = Read-Host "Enter the full path to the CSV file (columns: UserPrincipalName, Password)"
    if ([string]::IsNullOrWhiteSpace($CsvPath)) { throw "CSV path is required." }
    $CsvPath = $CsvPath.Trim().Trim('"')

    if (-not (Test-Path -LiteralPath $CsvPath)) {
        throw "CSV not found: $CsvPath"
    }

    $rows = Import-Csv -Path $CsvPath -ErrorAction Stop
    if (-not $rows -or $rows.Count -eq 0) {
        throw "CSV is empty: $CsvPath"
    }

    $upnCol = $rows[0].PSObject.Properties.Name |
        Where-Object { $_ -match '^(UserPrincipalName|UPN|Mail|Email)$' } |
        Select-Object -First 1
    $pwdCol = $rows[0].PSObject.Properties.Name |
        Where-Object { $_ -match '^(Password|NewPassword|Pwd)$' } |
        Select-Object -First 1

    if (-not $upnCol -or -not $pwdCol) {
        throw "CSV must have a UserPrincipalName (or UPN/Mail/Email) column and a Password column."
    }

    $entries = @()
    foreach ($r in $rows) {
        $upn = ($r.$upnCol ?? "").Trim()
        $pwd = ($r.$pwdCol ?? "").Trim()
        if (-not [string]::IsNullOrWhiteSpace($upn) -and -not [string]::IsNullOrWhiteSpace($pwd)) {
            $entries += [pscustomobject]@{ UPN = $upn; Password = $pwd }
        }
    }
    $entries = $entries | Sort-Object UPN -Unique

    if ($entries.Count -eq 0) {
        throw "No valid UserPrincipalName + Password rows found."
    }

    Write-Host "`nFound $($entries.Count) user(s) to update. Preview (first 10):" -ForegroundColor Cyan
    $entries | Select-Object -First 10 | ForEach-Object {
        Write-Host "  $($_.UPN)  (password length: $($_.Password.Length))"
    }
    if ($entries.Count -gt 10) {
        Write-Host "  ... and $($entries.Count - 10) more"
    }

    $forceChange = Read-Host "`nForce password change at next sign-in? (Y/N) - Recommended: N if setting known temp passwords"
    $forceNext = $forceChange -match '^[Yy]'

    $confirm = Read-Host "`nReset passwords for $($entries.Count) user(s)? This cannot be undone. (Y/N)"
    if ($confirm -notmatch '^[Yy]$') {
        Write-Host "Cancelled." -ForegroundColor Yellow
        return
    }

    # Modules
    if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
        Write-Host "Installing Microsoft.Graph modules..." -ForegroundColor Yellow
        Install-Module Microsoft.Graph.Authentication, Microsoft.Graph.Users -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
    }
    Import-Module Microsoft.Graph.Authentication -Force -ErrorAction Stop
    Import-Module Microsoft.Graph.Users -Force -ErrorAction Stop

    Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
    Connect-MgGraph -Scopes "User.ReadWrite.All", "Directory.AccessAsUser.All" -NoWelcome -ErrorAction Stop

    $ok = 0
    $failed = @()

    foreach ($e in $entries) {
        try {
            $user = Get-MgUser -Filter "userPrincipalName eq '$($e.UPN)'" -ErrorAction SilentlyContinue
            if (-not $user) {
                $user = Get-MgUser -Filter "mail eq '$($e.UPN)'" -ErrorAction SilentlyContinue
            }
            if (-not $user) { throw "User not found" }

            $profile = @{
                password                     = $e.Password
                forceChangePasswordNextSignIn = $forceNext
            }
            Update-MgUser -UserId $user.Id -PasswordProfile $profile -ErrorAction Stop
            Write-Host "  Updated: $($e.UPN)" -ForegroundColor Green
            $ok++
        }
        catch {
            Write-Host "  Failed: $($e.UPN) — $($_.Exception.Message)" -ForegroundColor Red
            $failed += $e.UPN
        }
    }

    Write-Host "`nDone. Updated: $ok | Failed: $($failed.Count)" -ForegroundColor Cyan
    if ($failed.Count -gt 0) {
        Write-Host "Failed users:" -ForegroundColor Red
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
