#Requires -Version 5.1
<#
.SYNOPSIS
    Force all (or filtered) Microsoft 365 users to change password at next sign-in.
    Shows count and requires explicit confirmation before making any change.
#>

$ErrorActionPreference = "Stop"

try {
    Write-Host "This will set ForceChangePasswordNextSignIn for users in the tenant." -ForegroundColor Yellow
    Write-Host "Scope options:" -ForegroundColor Cyan
    Write-Host "  1 = All enabled users (licensed + unlicensed)"
    Write-Host "  2 = Licensed users only"
    Write-Host "  3 = Single user (by UPN)"
    $scope = Read-Host "Enter 1, 2, or 3"
    if ($scope -notin @("1", "2", "3")) {
        Write-Host "Invalid choice. Cancelled." -ForegroundColor Yellow
        return
    }

    $singleUpn = $null
    if ($scope -eq "3") {
        $singleUpn = Read-Host "Enter the user UPN"
        if ([string]::IsNullOrWhiteSpace($singleUpn)) {
            throw "UPN is required."
        }
        $singleUpn = $singleUpn.Trim()
    }

    if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
        Write-Host "Installing Microsoft.Graph modules..." -ForegroundColor Yellow
        Install-Module Microsoft.Graph.Authentication, Microsoft.Graph.Users -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
    }
    Import-Module Microsoft.Graph.Authentication -Force -ErrorAction Stop
    Import-Module Microsoft.Graph.Users -Force -ErrorAction Stop

    Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
    Connect-MgGraph -Scopes "User.ReadWrite.All", "Directory.AccessAsUser.All" -NoWelcome -ErrorAction Stop

    if ($scope -eq "3") {
        $user = Get-MgUser -Filter "userPrincipalName eq '$singleUpn'" -ErrorAction SilentlyContinue
        if (-not $user) { throw "User not found: $singleUpn" }
        $targets = @($user)
    }
    else {
        Write-Host "Retrieving users (this may take a while)..." -ForegroundColor Cyan
        $all = Get-MgUser -All -Property Id, UserPrincipalName, AccountEnabled, AssignedLicenses -ErrorAction Stop |
            Where-Object { $_.AccountEnabled -eq $true }

        if ($scope -eq "2") {
            $targets = $all | Where-Object { $_.AssignedLicenses -and $_.AssignedLicenses.Count -gt 0 }
        }
        else {
            $targets = $all
        }
    }

    $count = @($targets).Count
    if ($count -eq 0) {
        Write-Host "No matching users found." -ForegroundColor Yellow
        return
    }

    Write-Host "`n$count user(s) will be forced to change password at next sign-in." -ForegroundColor Yellow
    if ($count -le 15) {
        $targets | ForEach-Object { Write-Host "  $($_.UserPrincipalName)" }
    }
    else {
        $targets | Select-Object -First 10 | ForEach-Object { Write-Host "  $($_.UserPrincipalName)" }
        Write-Host "  ... and $($count - 10) more"
    }

    $confirm = Read-Host "`nProceed? This affects live sign-in behaviour. (Y/N)"
    if ($confirm -notmatch '^[Yy]$') {
        Write-Host "Cancelled." -ForegroundColor Yellow
        return
    }

    $ok = 0
    $failed = @()

    foreach ($u in $targets) {
        try {
            Update-MgUser -UserId $u.Id -PasswordProfile @{ forceChangePasswordNextSignIn = $true } -ErrorAction Stop
            Write-Host "  Set: $($u.UserPrincipalName)" -ForegroundColor Green
            $ok++
        }
        catch {
            Write-Host "  Failed: $($u.UserPrincipalName) — $($_.Exception.Message)" -ForegroundColor Red
            $failed += $u.UserPrincipalName
        }
    }

    Write-Host "`nDone. Updated: $ok | Failed: $($failed.Count)" -ForegroundColor Cyan
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
