# Prompt the user for the user principal name (UPN)
$UPN = Read-Host -Prompt 'Enter the User Principal Name (UPN) for connecting to Exchange Online'

# Prompt the user for the compliance search name
$complianceSearchName = Read-Host -Prompt 'Enter the Compliance Search Name'

# Prompt the user for the From: command
$fromCommand = Read-Host -Prompt 'Enter the From: command for ContentMatchQuery'

# Bypass execution policy temporarily
Set-ExecutionPolicy Unrestricted -Scope Process -Force

# Install and import the required modules
Install-Module -Name ExchangeOnlineManagement -RequiredVersion 3.0.0 -Force
Import-Module ExchangeOnlineManagement

# Connect to Exchange Online using the provided UPN
Connect-IPPSSession -UserPrincipalName $UPN

# Create a new compliance search
New-ComplianceSearch -Name $complianceSearchName -ExchangeLocation all -ContentMatchQuery $fromCommand

# Start the compliance search
Start-ComplianceSearch -Identity $complianceSearchName

# Wait for the completion of the compliance search
do {
    Start-Sleep -Seconds 10
    $searchStatus = (Get-ComplianceSearch -Identity $complianceSearchName).Status
} while ($searchStatus -ne "Completed")

# Display information about the completed compliance search
Get-ComplianceSearch -Identity $complianceSearchName

# Define the path for the log file
$logFile = "C:\Logs\MailboxesDeletedFrom.log"

# Create the directory if it doesn't exist
if (-not (Test-Path "C:\Logs")) {
    New-Item -ItemType Directory -Path "C:\Logs"
}

# Get the search results and log the mailboxes involved
$results = Get-ComplianceSearchAction -Identity $complianceSearchName
$mailboxes = $results.Results | ForEach-Object { $_.PrimaryMailbox }

$mailboxes | Out-File -FilePath $logFile -Append
Write-Host "Mailboxes affected have been logged to $logFile"

# Create a new compliance search action to purge
$action = New-ComplianceSearchAction -SearchName $complianceSearchName -Purge -PurgeType HardDelete

# Wait for the completion of the purge action
do {
    Start-Sleep -Seconds 10
    $actionStatus = (Get-ComplianceSearchAction -Identity $action.Identity).Status
} while ($actionStatus -ne "Completed")

# Display a message when the purge is completed
Write-Host "Purge completed."

# Pause to keep the console window open
Read-Host "Press Enter to exit."
