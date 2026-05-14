# Set registry values under WOW6432Node
$wow6432NodePath = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v4.0.30319"
New-Item -Path $wow6432NodePath -Force

Set-ItemProperty -Path $wow6432NodePath -Name "AspNetEnforceViewStateMac" -Value 1

$skusPath = Join-Path $wow6432NodePath "SKUs"
New-Item -Path $skusPath -Force

$versions = @("v4.0", "v4.0.1", "v4.0.2", "v4.0.3", "v4.5", "v4.5.1", "v4.5.2", "v4.5.3", "v4.6", "v4.6.1", "v4.6.2", "v4.7", "v4.7.1", "v4.7.2", "v4.8")
foreach ($version in $versions) {
    $versionPath = Join-Path $skusPath ".NETFramework,Version=$version"
    New-Item -Path $versionPath -Force

    $profilePath = Join-Path $versionPath "Profile=Client"
    New-Item -Path $profilePath -Force
}

# Set registry values without WOW6432Node
$noWow6432NodePath = "HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319"
New-Item -Path $noWow6432NodePath -Force

Set-ItemProperty -Path $noWow6432NodePath -Name "AspNetEnforceViewStateMac" -Value 1

$noWow6432NodeSkusPath = Join-Path $noWow6432NodePath "SKUs"
New-Item -Path $noWow6432NodeSkusPath -Force

foreach ($version in $versions) {
    $versionPath = Join-Path $noWow6432NodeSkusPath ".NETFramework,Version=$version"
    New-Item -Path $versionPath -Force

    $profilePath = Join-Path $versionPath "Profile=Client"
    New-Item -Path $profilePath -Force
}
