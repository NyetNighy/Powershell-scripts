# Create a public desktop shortcut for PaperCut Print Deploy Client.

$TargetPath  = "C:\Program Files\PaperCut Print Deploy Client\v2026-07-16-0211\pc-webview.exe"
$ShortcutPath = "$env:Public\Desktop\PaperCut Print Deploy.lnk"
$WorkingDir  = "C:\Program Files\PaperCut Print Deploy Client\v2026-07-16-0211"

try {
    if (-not (Test-Path -LiteralPath $TargetPath)) {
        Write-Output "Target executable not found: $TargetPath"
        exit 1
    }

    $WshShell = New-Object -ComObject WScript.Shell -ErrorAction Stop
    $Shortcut = $WshShell.CreateShortcut($ShortcutPath)
    $Shortcut.TargetPath       = $TargetPath
    $Shortcut.WorkingDirectory = $WorkingDir
    $Shortcut.IconLocation     = "$TargetPath,0"
    $Shortcut.Description      = "PaperCut Print Deploy Client"
    $Shortcut.Save()

    Write-Output "Shortcut created successfully: $ShortcutPath"
}
catch {
    Write-Output "Failed to create shortcut: $($_.Exception.Message)"
    exit 1
}
