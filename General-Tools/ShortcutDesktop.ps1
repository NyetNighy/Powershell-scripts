
$TargetPath = "C:\Program Files\PaperCut Print Deploy Client\v2026-07-16-0211\pc-webview.exe"
$ShortcutPath = "$env:Public\Desktop\PaperCut Print Deploy.lnk"
$WorkingDir  = "C:\Program Files\PaperCut Print Deploy Client\v2026-07-16-0211"


if (-not (Test-Path $TargetPath)) {
    Write-Output "Target executable not found: $TargetPath"
    exit 1
}

$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut($ShortcutPath)
$Shortcut.TargetPath       = $TargetPath
$Shortcut.WorkingDirectory = $WorkingDir
$Shortcut.IconLocation     = "$TargetPath,0"   # Uses the exe’s own icon
$Shortcut.Description      = "PaperCut Print Deploy Client"
$Shortcut.Save()

Write-Output "Shortcut created successfully: $ShortcutPath"