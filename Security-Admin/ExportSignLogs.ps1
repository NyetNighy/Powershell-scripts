#Requires -Modules Microsoft.Graph.Reports
<#
.SYNOPSIS
    Export Microsoft Graph sign-in audit logs to CSV (fully flattened).
.PARAMETER OutputPath
    Destination CSV path. Default: SignInLogs_COMPLETE_<timestamp>.csv in the current directory.
.PARAMETER Connect
    Connect to Graph with AuditLog.Read.All before export (default: true).
.PARAMETER Disconnect
    Disconnect Graph session after export (default: true).
.EXAMPLE
    .\ExportSignLogs.ps1
.EXAMPLE
    .\ExportSignLogs.ps1 -OutputPath D:\Reports\signins.csv
#>
[CmdletBinding()]
param(
    [Parameter()]
    [string]$OutputPath = "",

    [Parameter()]
    [bool]$Connect = $true,

    [Parameter()]
    [bool]$Disconnect = $true
)

if (-not $OutputPath) {
    $OutputPath = Join-Path -Path (Get-Location).Path -ChildPath ("SignInLogs_COMPLETE_{0:yyyyMMdd_HHmm}.csv" -f (Get-Date))
}

$outputDir = Split-Path -Parent $OutputPath
if ($outputDir -and -not (Test-Path -LiteralPath $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

if ($Connect) {
    Connect-MgGraph -Scopes "AuditLog.Read.All" -NoWelcome
}

Write-Host "Fetching sign-in logs (this may take a while)..." -ForegroundColor Cyan
$AllSignIns = Get-MgAuditLogSignIn -All

$Expanded = $AllSignIns | ForEach-Object {
    $signIn = $_

    $obj = [pscustomobject]@{
        Id                      = $signIn.Id
        CreatedDateTime         = $signIn.CreatedDateTime
        UserDisplayName         = $signIn.UserDisplayName
        UserPrincipalName       = $signIn.UserPrincipalName
        UserId                  = $signIn.UserId
        AppDisplayName          = $signIn.AppDisplayName
        AppId                   = $signIn.AppId
        IPAddress               = $signIn.IPAddress
        ClientAppUsed           = $signIn.ClientAppUsed
        CorrelationId           = $signIn.CorrelationId
        ConditionalAccessStatus = $signIn.ConditionalAccessStatus
        IsInteractive           = $signIn.IsInteractive
        ResourceDisplayName     = $signIn.ResourceDisplayName
        ResourceId              = $signIn.ResourceId
        RiskLevelAggregated     = $signIn.RiskLevelAggregated
        RiskLevelDuringSignIn   = $signIn.RiskLevelDuringSignIn
        RiskState               = $signIn.RiskState
        StatusErrorCode         = $signIn.Status.ErrorCode
        StatusFailureReason     = $signIn.Status.FailureReason
        StatusAdditionalDetails = $signIn.Status.AdditionalDetails
        City                    = $null
        State                   = $null
        Country                 = $null
        Latitude                = $null
        Longitude               = $null
        DeviceId                = $null
        DeviceOS                = $null
        DeviceBrowser           = $null
        DeviceCompliant         = $null
        DeviceManaged           = $null
        MFA_Method              = $null
        MFA_Result              = $null
        AuthenticationSteps     = $null
        CA_Policies             = $null
        CA_Results              = $null
        TokenIssuerType         = $signIn.TokenIssuerType
    }

    if ($signIn.Location) {
        $obj.City = $signIn.Location.City
        $obj.State = $signIn.Location.State
        $obj.Country = $signIn.Location.CountryOrRegion
        if ($signIn.Location.GeoCoordinates) {
            $obj.Latitude = $signIn.Location.GeoCoordinates.Latitude
            $obj.Longitude = $signIn.Location.GeoCoordinates.Longitude
        }
    }

    if ($signIn.DeviceDetail) {
        $obj.DeviceId = $signIn.DeviceDetail.DeviceId
        $obj.DeviceOS = $signIn.DeviceDetail.OperatingSystem
        $obj.DeviceBrowser = $signIn.DeviceDetail.Browser
        $obj.DeviceCompliant = $signIn.DeviceDetail.IsCompliant
        $obj.DeviceManaged = $signIn.DeviceDetail.IsManaged
    }

    if ($signIn.MfaDetail) {
        $obj.MFA_Method = $signIn.MfaDetail.AuthMethod
        $obj.MFA_Result = $signIn.MfaDetail.AuthResult
    }

    if ($signIn.AuthenticationDetails) {
        $steps = $signIn.AuthenticationDetails | ForEach-Object {
            "$($_.AuthenticationMethod): $($_.Succeeded)"
        }
        $obj.AuthenticationSteps = ($steps -join " | ")
    }

    if ($signIn.AppliedConditionalAccessPolicies) {
        $obj.CA_Policies = ($signIn.AppliedConditionalAccessPolicies.DisplayName -join "; ")
        $obj.CA_Results = ($signIn.AppliedConditionalAccessPolicies.Result -join "; ")
    }

    $obj
}

$Expanded | Sort-Object CreatedDateTime -Descending |
    Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8

Write-Host "Done! Full detailed report saved to:" -ForegroundColor Green
Write-Host $OutputPath -ForegroundColor Cyan
Write-Host "Total sign-ins exported: $($Expanded.Count)" -ForegroundColor Yellow

if ($Disconnect) {
    Disconnect-MgGraph | Out-Null
}
