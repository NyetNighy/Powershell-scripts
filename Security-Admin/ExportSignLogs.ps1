# Connect (do this once)
Connect-MgGraph -Scopes "AuditLog.Read.All"

# Pull ALL sign-in logs and fully flatten everything
$AllSignIns = Get-MgAuditLogSignIn -All

$Expanded = $AllSignIns | ForEach-Object {
    $signIn = $_

    # Start with all top-level properties
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
    }

    # Location
    if ($signIn.Location) {
        Add-Member -InputObject $obj -NotePropertyName "City"      -NotePropertyValue $signIn.Location.City -PassThru
        Add-Member -InputObject $obj -NotePropertyName "State"     -NotePropertyValue $signIn.Location.State -PassThru
        Add-Member -InputObject $obj -NotePropertyName "Country"   -NotePropertyValue $signIn.Location.CountryOrRegion -PassThru
        Add-Member -InputObject $obj -NotePropertyName "Latitude"  -NotePropertyValue $signIn.Location.GeoCoordinates.Latitude -PassThru
        Add-Member -InputObject $obj -NotePropertyName "Longitude" -NotePropertyValue $signIn.Location.GeoCoordinates.Longitude -PassThru
    }

    # Device Detail
    if ($signIn.DeviceDetail) {
        Add-Member -InputObject $obj -NotePropertyName "DeviceId"        -NotePropertyValue $signIn.DeviceDetail.DeviceId -PassThru
        Add-Member -InputObject $obj -NotePropertyName "DeviceOS"        -NotePropertyValue $signIn.DeviceDetail.OperatingSystem -PassThru
        Add-Member -InputObject $obj -NotePropertyName "DeviceBrowser"   -NotePropertyValue $signIn.DeviceDetail.Browser -PassThru
        Add-Member -InputObject $obj -NotePropertyName "DeviceCompliant" -NotePropertyValue $signIn.DeviceDetail.IsCompliant -PassThru
        Add-Member -InputObject $obj -NotePropertyName "DeviceManaged"   -NotePropertyValue $signIn.DeviceDetail.IsManaged -PassThru
    }

    # MFA Detail
    if ($signIn.MfaDetail) {
        Add-Member -InputObject $obj -NotePropertyName "MFA_Method" -NotePropertyValue $signIn.MfaDetail.AuthMethod -PassThru
        Add-Member -InputObject $obj -NotePropertyName "MFA_Result" -NotePropertyValue $signIn.MfaDetail.AuthResult -PassThru
    }

    # Authentication steps (password, MFA, etc.)
    if ($signIn.AuthenticationDetails) {
        $steps = $signIn.AuthenticationDetails | ForEach-Object {
            "$($_.AuthenticationMethod): $($_.Succeeded)"
        }
        Add-Member -InputObject $obj -NotePropertyName "AuthenticationSteps" -NotePropertyValue ($steps -join " | ") -PassThru
    }

    # Conditional Access policies applied
    if ($signIn.AppliedConditionalAccessPolicies) {
        $caNames   = $signIn.AppliedConditionalAccessPolicies.DisplayName -join "; "
        $caResults = $signIn.AppliedConditionalAccessPolicies.Result -join "; "
        Add-Member -InputObject $obj -NotePropertyName "CA_Policies"   -NotePropertyValue $caNames -PassThru
        Add-Member -InputObject $obj -NotePropertyName "CA_Results"    -NotePropertyValue $caResults -PassThru
    }

    # Token age / freshness
    Add-Member -InputObject $obj -NotePropertyName "TokenAge" -NotePropertyValue $signIn.TokenIssuerType -PassThru

    # Output the fully expanded row
    $obj
}

# Export to CSV – this one will be perfect
$OutputFile = "C:\SignInLogs_COMPLETE_$(Get-Date -Format yyyyMMdd_HHmm).csv"
$Expanded | Sort-Object CreatedDateTime -Descending | Export-Csv -Path $OutputFile -NoTypeInformation -Encoding UTF8

Write-Host "Done! Full detailed report saved to:" -ForegroundColor Green
Write-Host $OutputFile -ForegroundColor Cyan
Write-Host "Total sign-ins exported:" $Expanded.Count -ForegroundColor Yellow

Disconnect-MgGraph