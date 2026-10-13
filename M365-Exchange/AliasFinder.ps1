# Search all Exchange recipients (including soft-deleted) for an email alias.

$aliasToFind = Read-Host "Enter the full email alias to search for (e.g. safeguarding@domain.com)"
if ([string]::IsNullOrWhiteSpace($aliasToFind)) {
    Write-Host "No alias entered. Exiting." -ForegroundColor Yellow
    exit 1
}

$aliasToFindLower = $aliasToFind.ToLower()

try {
    if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
        Write-Host "Installing ExchangeOnlineManagement module..." -ForegroundColor Yellow
        Install-Module -Name ExchangeOnlineManagement -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
    }
    Import-Module ExchangeOnlineManagement -Force -ErrorAction Stop

    Write-Host "Connecting to Exchange Online..." -ForegroundColor Cyan
    Connect-ExchangeOnline -ShowBanner:$false -ErrorAction Stop

    Write-Host "`nSearching all recipients (including soft-deleted) for: $aliasToFind" -ForegroundColor Yellow

    $results = Get-Recipient -ResultSize Unlimited -IncludeSoftDeletedRecipients -ErrorAction Stop |
        Where-Object {
            $_.EmailAddresses -like "*$aliasToFind*" -or
            $_.EmailAddresses -like "*$aliasToFindLower*"
        } |
        Select-Object Name,
            RecipientTypeDetails,
            PrimarySmtpAddress,
            @{Name = "EmailAddresses"; Expression = { $_.EmailAddresses -join "; " }},
            @{Name = "Status"; Expression = {
                if ($_.WhenSoftDeleted) { "Soft-Deleted ($($_.WhenSoftDeleted))" } else { "Active" }
            }}

    if ($results) {
        Write-Host "`nMATCH FOUND!" -ForegroundColor Green
        Write-Host "The alias is currently assigned to the following object(s):`n" -ForegroundColor Green
        $results | Format-List

        Write-Host "`nQuick tip:" -ForegroundColor Cyan
        Write-Host "- Uppercase SMTP: = primary email address"
        Write-Host "- Lowercase smtp: = alias / proxy address"
        Write-Host "- RecipientTypeDetails tells you what kind of object it is (UserMailbox, SharedMailbox, MailUser, Group, etc.)`n"

        $timestamp = Get-Date -Format "yyyyMMdd-HHmm"
        $exportPath = Join-Path $env:USERPROFILE "Desktop\AliasSearch_$timestamp.csv"
        try {
            $results | Export-Csv -Path $exportPath -NoTypeInformation -Encoding UTF8 -ErrorAction Stop
            Write-Host "Results saved to: $exportPath" -ForegroundColor Green
        }
        catch {
            Write-Host "Could not export CSV: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "`nNO MATCH FOUND" -ForegroundColor Red
        Write-Host "The alias '$aliasToFind' does not appear on any active or soft-deleted recipient." -ForegroundColor Yellow
        Write-Host "Possible explanations:"
        Write-Host "  • It's assigned to a mail contact, public folder mailbox, or legacy object (try Get-MailContact or Get-PublicFolder)"
        Write-Host "  • It's permanently deleted (retention expired) — contact Microsoft support via admin center"
        Write-Host "  • Typo in the address you entered"
        Write-Host "  • Rare backend sync glitch (wait a bit and retry, or open a support ticket)"
    }
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}
finally {
    Write-Host "`nDisconnecting session..." -ForegroundColor Cyan
    try {
        Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
    }
    catch { }
    Write-Host "Script complete." -ForegroundColor Green
}
