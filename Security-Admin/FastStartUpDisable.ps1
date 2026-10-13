# Disable Windows Fast Startup (HiberbootEnabled = 0). Requires elevation.

$Path  = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power"
$Name  = "HiberbootEnabled"
$Value = 0

try {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Host "This script must be run as Administrator." -ForegroundColor Red
        exit 1
    }

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -Path $Path -Force -ErrorAction Stop | Out-Null
    }

    New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType DWORD -Force -ErrorAction Stop | Out-Null
    Write-Host "Fast Startup disabled (HiberbootEnabled = 0)." -ForegroundColor Green
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
