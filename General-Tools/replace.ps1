$content = Get-Content -Path "C:\Powershell\ExportSignLogs1m.ps1" -Raw
$content = $content -replace '[“”]', '"' -replace '[‘’]', "'"
$content | Set-Content -Path "C:\Powershell\ExportSignLogs1m_FIXED.ps1"