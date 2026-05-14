
Install-Module -Name ExchangeOnlineManagement -Scope CurrentUser -Force -AllowClobber


$aliasToFind = Read-Host "Enter the full email alias to search for (e.g. safeguarding@domain.com)"


$aliasToFindLower = $aliasToFind.ToLower()

Write-Host "Connecting to Exchange Online..." -ForegroundColor Cyan
Connect-ExchangeOnline -ShowBanner:$false

Write-Host "`nSearching all recipients (including soft-deleted) for: $aliasToFind" -ForegroundColor Yellow


$results = Get-Recipient -ResultSize Unlimited -IncludeSoftDeletedRecipients `
    | Where-Object { 
        $_.EmailAddresses -like "*$aliasToFind*" -or 
        $_.EmailAddresses -like "*$aliasToFindLower*" 
      } `
    | Select-Object Name, 
        RecipientTypeDetails, 
        PrimarySmtpAddress, 
        @{Name="EmailAddresses"; Expression={ $_.EmailAddresses -join "; " }}, 
        @{Name="Status"; Expression={ if($_.WhenSoftDeleted) { "Soft-Deleted ($($_.WhenSoftDeleted))" } else { "Active" } }}

if ($results) {
    Write-Host "`nMATCH FOUND!" -ForegroundColor Green
    Write-Host "The alias is currently assigned to the following object(s):`n" -ForegroundColor Green
    $results | Format-List

    Write-Host "`nQuick tip:" -ForegroundColor Cyan
    Write-Host "- Uppercase SMTP: = primary email address"
    Write-Host "- Lowercase smtp: = alias / proxy address"
    Write-Host "- RecipientTypeDetails tells you what kind of object it is (UserMailbox, SharedMailbox, MailUser, Group, etc.)`n"

    # Export to CSV on desktop
    $timestamp = Get-Date -Format "yyyyMMdd-HHmm"
    $exportPath = "$env:USERPROFILE\Desktop\AliasSearch_$timestamp.csv"
    $results | Export-Csv -Path $exportPath -NoTypeInformation -Encoding UTF8
    Write-Host "Results saved to: $exportPath" -ForegroundColor Green
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

Write-Host "`nDisconnecting session..." -ForegroundColor Cyan
Disconnect-ExchangeOnline -Confirm:$false

Write-Host "Script complete." -ForegroundColor Green