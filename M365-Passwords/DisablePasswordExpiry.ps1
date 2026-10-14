#Requires -Version 5.1
<#
.SYNOPSIS
    Disable password expiration for one Microsoft 365 user (PasswordPolicies = DisablePasswordExpiration).
#>

$ErrorActionPreference = "Stop"

try {
    $upn = Read-Host "Enter the user UPN (e.g. admin@contoso.com)"
    if ([string]::IsNullOrWhiteSpace($upn)) { throw "UPN is required." }
    $upn = $upn.Trim()

    if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
        Write-Host "Installing Microsoft.Graph modules..." -ForegroundColor Yellow
        Install-Module Microsoft.Graph.Authentication, Microsoft.Graph.Users -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
    }
    Import-Module Microsoft.Graph.Authentication -Force -ErrorAction Stop
    Import-Module Microsoft.Graph.Users -Force -ErrorAction Stop

    Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
    Connect-MgGraph -Scopes "User.ReadWrite.All" -NoWelcome -ErrorAction Stop

    $user = Get-MgUser -Filter "userPrincipalName eq '$upn'" -Property Id, UserPrincipalName, DisplayName, PasswordPolicies -ErrorAction SilentlyContinue
    if (-not $user) {
        $user = Get-MgUser -Filter "mail eq '$upn'" -Property Id, UserPrincipalName, DisplayName, PasswordPolicies -ErrorAction SilentlyContinue
    }
    if (-not $user) { throw "User not found: $upn" }

    Write-Host "`nUser: $($user.DisplayName) ($($user.UserPrincipalName))" -ForegroundColor Cyan
    Write-Host "Current PasswordPolicies: $($user.PasswordPolicies)" -ForegroundColor Gray

    $confirm = Read-Host "Disable password expiration for this user? (Y/N)"
    if ($confirm -notmatch '^[Yy]$') {
        Write-Host "Cancelled." -ForegroundColor Yellow
        return
    }

    Update-MgUser -UserId $user.Id -PasswordPolicies "DisablePasswordExpiration" -ErrorAction Stop
    Write-Host "Password expiration disabled for $($user.UserPrincipalName)." -ForegroundColor Green
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    try { Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null } catch { }
}
