# =============================================
# PRTG Custom Sensor for Dell PowerVault ME5024 Disks
# Uses ME5 REST API (CLI over HTTP)
# Author: Grok
# =============================================

param(
    [string]$hostname = "YOUR_ME5024_IP_OR_HOSTNAME",   # e.g. 192.168.10.50
    [string]$username = "YOUR_API_USERNAME",
    [string]$password = "YOUR_API_PASSWORD"
)

# Ignore SSL certificate errors (common with storage arrays - remove if you have valid cert)
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }

$baseUrl = "https://$hostname/api"

# Login and get session key
$loginBody = @{
    user     = $username
    password = $password
} | ConvertTo-Json

try {
    $loginResponse = Invoke-RestMethod -Uri "$baseUrl/login" -Method Post -Body $loginBody -ContentType "application/json"
    $sessionKey = $loginResponse.key
} catch {
    Write-Output "<prtg><error>1</error><text>Login failed: $($_.Exception.Message)</text></prtg>"
    exit
}

# Show disks in JSON format
$headers = @{
    "sessionKey" = $sessionKey
}

try {
    $disksResponse = Invoke-RestMethod -Uri "$baseUrl/show/disks" -Method Get -Headers $headers -ContentType "application/json"
} catch {
    Write-Output "<prtg><error>1</error><text>Failed to get disks: $($_.Exception.Message)</text></prtg>"
    exit
}

$disks = $disksResponse."disks"   # The array of disks

if (-not $disks -or $disks.Count -eq 0) {
    Write-Output "<prtg><error>1</error><text>No disks returned from array</text></prtg>"
    exit
}

# PRTG XML Output
$xml = New-Object System.Text.StringBuilder
[void]$xml.AppendLine("<prtg>")

$healthyCount = 0
$problemCount = 0

foreach ($disk in $disks) {
    $dName      = $disk."dsk-name"      # e.g. 0.0, 0.1 ...
    $dHealth    = $disk."health"        # OK, Degraded, Fault, etc.
    $dTemp      = [int]$disk."temperature-numeric"   # numeric value in Celsius
    $dSSD       = $disk."ssd-life-remaining"   # percentage for SSDs
    $dStatus    = $disk."status"        # additional status

    $healthValue = if ($dHealth -eq "OK") { 0 } else { 1 }

    if ($dHealth -eq "OK") { $healthyCount++ } else { $problemCount++ }

    # Channel for each disk health
    [void]$xml.AppendLine("  <result>")
    [void]$xml.AppendLine("    <channel>Disk $dName Health</channel>")
    [void]$xml.AppendLine("    <value>$healthValue</value>")
    [void]$xml.AppendLine("    <unit>One</unit>")
    [void]$xml.AppendLine("    <CustomUnit>Status</CustomUnit>")
    [void]$xml.AppendLine("    <LimitMode>1</LimitMode>")
    [void]$xml.AppendLine("    <LimitMinWarning>0</LimitMinWarning>")
    [void]$xml.AppendLine("    <LimitMaxWarning>0</LimitMaxWarning>")
    [void]$xml.AppendLine("    <LimitMinError>1</LimitMinError>")
    [void]$xml.AppendLine("    <showChart>1</showChart>")
    [void]$xml.AppendLine("    <showTable>1</showTable>")
    [void]$xml.AppendLine("  </result>")

    # Temperature channel (only if value is valid)
    if ($dTemp -gt 0) {
        [void]$xml.AppendLine("  <result>")
        [void]$xml.AppendLine("    <channel>Disk $dName Temperature</channel>")
        [void]$xml.AppendLine("    <value>$dTemp</value>")
        [void]$xml.AppendLine("    <unit>Temperature</unit>")
        [void]$xml.AppendLine("    <CustomUnit>°C</CustomUnit>")
        [void]$xml.AppendLine("    <LimitMode>1</LimitMode>")
        [void]$xml.AppendLine("    <LimitMaxWarning>45</LimitMaxWarning>")
        [void]$xml.AppendLine("    <LimitMaxError>55</LimitMaxError>")
        [void]$xml.AppendLine("  </result>")
    }

    # SSD life (if present)
    if ($dSSD -and $dSSD -ne "") {
        [void]$xml.AppendLine("  <result>")
        [void]$xml.AppendLine("    <channel>Disk $dName SSD Life</channel>")
        [void]$xml.AppendLine("    <value>$dSSD</value>")
        [void]$xml.AppendLine("    <unit>Percent</unit>")
        [void]$xml.AppendLine("    <LimitMode>1</LimitMode>")
        [void]$xml.AppendLine("    <LimitMinWarning>10</LimitMinWarning>")
        [void]$xml.AppendLine("    <LimitMinError>5</LimitMinError>")
        [void]$xml.AppendLine("  </result>")
    }
}

# Summary channels
[void]$xml.AppendLine("  <result>")
[void]$xml.AppendLine("    <channel>Healthy Disks</channel>")
[void]$xml.AppendLine("    <value>$healthyCount</value>")
[void]$xml.AppendLine("    <unit>Count</unit>")
[void]$xml.AppendLine("  </result>")

[void]$xml.AppendLine("  <result>")
[void]$xml.AppendLine("    <channel>Problem Disks</channel>")
[void]$xml.AppendLine("    <value>$problemCount</value>")
[void]$xml.AppendLine("    <unit>Count</unit>")
[void]$xml.AppendLine("    <LimitMode>1</LimitMode>")
[void]$xml.AppendLine("    <LimitMaxWarning>0</LimitMaxWarning>")
[void]$xml.AppendLine("    <LimitMaxError>0</LimitMaxError>")
[void]$xml.AppendLine("  </result>")

[void]$xml.AppendLine("  <text>$($disks.Count) disks monitored | $healthyCount healthy, $problemCount with issues</text>")
[void]$xml.AppendLine("</prtg>")

Write-Output $xml.ToString()