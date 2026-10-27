#Requires -Modules Microsoft.Graph.Reports
<#
.SYNOPSIS
    Export sign-in logs via Graph, then analyse for successful sign-ins from outside the UK.
.PARAMETER OutputFolder
    Folder for the exported CSV and analysis results. Defaults to current directory.
.PARAMETER Days
    Optional. Currently exports all available logs (Graph retention limit applies).
.EXAMPLE
    .\Export-And-Analyse-SignIns.ps1
.EXAMPLE
    .\Export-And-Analyse-SignIns.ps1 -OutputFolder D:\Reports
#>
[CmdletBinding()]
param(
    [string]$OutputFolder = (Get-Location).Path
)

if (-not (Test-Path -LiteralPath $OutputFolder)) {
    New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
}

$timestamp = Get-Date -Format 'yyyyMMdd_HHmm'
$exportPath = Join-Path $OutputFolder "SignInLogs_COMPLETE_$timestamp.csv"

# ---------- Export (same logic as ExportSignLogs.ps1) ----------
try {
    Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
    Connect-MgGraph -Scopes 'AuditLog.Read.All' -NoWelcome -ErrorAction Stop

    Write-Host "Fetching sign-in logs (this may take a while)..." -ForegroundColor Cyan
    $AllSignIns = Get-MgAuditLogSignIn -All -ErrorAction Stop

    if (-not $AllSignIns -or $AllSignIns.Count -eq 0) {
        Write-Host "No sign-in logs returned." -ForegroundColor Yellow
        return
    }

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
            $obj.AuthenticationSteps = ($steps -join ' | ')
        }

        if ($signIn.AppliedConditionalAccessPolicies) {
            $obj.CA_Policies = ($signIn.AppliedConditionalAccessPolicies.DisplayName -join '; ')
            $obj.CA_Results = ($signIn.AppliedConditionalAccessPolicies.Result -join '; ')
        }

        $obj
    }

    $Expanded | Sort-Object CreatedDateTime -Descending |
        Export-Csv -Path $exportPath -NoTypeInformation -Encoding UTF8 -ErrorAction Stop

    Write-Host "Export complete: $exportPath" -ForegroundColor Green
    Write-Host "Total sign-ins exported: $($Expanded.Count)`n" -ForegroundColor Yellow
}
catch {
    Write-Host "Export error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    try { Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null } catch { }
}

# ---------- Analyse ----------
Write-Host "Analysing for successful sign-ins from outside the UK..." -ForegroundColor Cyan

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$analyseScript = Join-Path $scriptDir 'Analyse-SignInsAbroad.ps1'

if (-not (Test-Path $analyseScript)) {
    Write-Error "Analyse-SignInsAbroad.ps1 not found in $scriptDir"
    return
}

& $analyseScript -InputFile $exportPath -OutputFolder $OutputFolder
