# Prompt the user for the user principal name (UPN)
$UPN = Read-Host -Prompt 'Enter the User Principal Name (UPN) for connecting to Exchange Online and Security & Compliance'

# Prompt the user for the compliance search name
$complianceSearchName = Read-Host -Prompt 'Enter the Compliance Search Name (e.g., PurgeToAndSubjectEmail)'

# Prompt the user for the recipient email address
$toAddress = Read-Host -Prompt 'Enter the recipient email address (e.g., example@domain.com)'

# Prompt the user for the email subject
$subject = Read-Host -Prompt 'Enter the email subject to search for'

# Set ContentMatchQuery with To and subject
$contentMatchQuery = "to:$toAddress subject:`"$subject`""

# Bypass execution policy temporarily for the current process
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

# Install and import the required ExchangeOnlineManagement module if not already installed
if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
    Write-Host "Installing ExchangeOnlineManagement module..."
    Install-Module -Name ExchangeOnlineManagement -Force -AllowClobber
}
Import-Module ExchangeOnlineManagement

# Connect to Exchange Online and Security & Compliance Center
try {
    Write-Host "Connecting to Exchange Online..."
    Connect-ExchangeOnline -UserPrincipalName $UPN -ShowProgress:$true -ErrorAction Stop
    Write-Host "Connecting to Security & Compliance Center..."
    Connect-IPPSSession -UserPrincipalName $UPN -ErrorAction Stop
} catch {
    Write-Host "Error connecting: $($_.Exception.Message)" -ForegroundColor Red
    Read-Host "Press Enter to exit."
    exit
}

# Create a new compliance search
try {
    Write-Host "Creating compliance search: $complianceSearchName"
    New-ComplianceSearch -Name $complianceSearchName -ExchangeLocation All -ContentMatchQuery $contentMatchQuery -ErrorAction Stop
} catch {
    Write-Host "Error creating compliance search: $($_.Exception.Message)" -ForegroundColor Red
    Read-Host "Press Enter to exit."
    Disconnect-ExchangeOnline -Confirm:$false
    exit
}

# Start the compliance search
try {
    Write-Host "Starting compliance search..."
    Start-ComplianceSearch -Identity $complianceSearchName -ErrorAction Stop
} catch {
    Write-Host "Error starting compliance search: $($_.Exception.Message)" -ForegroundColor Red
    Read-Host "Press Enter to exit."
    Disconnect-ExchangeOnline -Confirm:$false
    exit
}

# Wait for the completion of the compliance search
Write-Host "Waiting for compliance search to complete..."
do {
    Start-Sleep -Seconds 10
    $searchStatus = (Get-ComplianceSearch -Identity $complianceSearchName -ErrorAction Stop).Status
    Write-Host "Search status: $searchStatus"
} while ($searchStatus -ne "Completed")

# Display information about the completed compliance search
Write-Host "Compliance search results:"
$searchResults = Get-ComplianceSearch -Identity $complianceSearchName | Select-Object Name,Items,Size,SuccessResults
$searchResults | Format-List

# Check if any items were found
if ($searchResults.Items -eq 0) {
    Write-Host "No items found for the search. Cannot proceed with purge." -ForegroundColor Yellow
    Remove-ComplianceSearch -Identity $complianceSearchName -Confirm:$false -ErrorAction SilentlyContinue
    Disconnect-ExchangeOnline -Confirm:$false
    Read-Host "Press Enter to exit."
    exit
}

# Create a new compliance search action to purge
try {
    Write-Host "Initiating purge action..."
    $action = New-ComplianceSearchAction -SearchName $complianceSearchName -Purge -PurgeType HardDelete -Confirm:$false -ErrorAction Stop
    $actionIdentity = $action.Identity
    Write-Host "Purge action created with Identity: $actionIdentity"
} catch {
    Write-Host "Error creating purge action: $($_.Exception.Message)" -ForegroundColor Red
    Remove-ComplianceSearch -Identity $complianceSearchName -Confirm:$false -ErrorAction SilentlyContinue
    Disconnect-ExchangeOnline -Confirm:$false
    Read-Host "Press Enter to exit."
    exit
}

# Wait for the completion of the purge action
Write-Host "Waiting for purge action to complete..."
do {
    Start-Sleep -Seconds 10
    try {
        $actionStatus = (Get-ComplianceSearchAction -Identity $actionIdentity -ErrorAction Stop).Status
        Write-Host "Purge action status: $actionStatus"
    } catch {
        Write-Host "Error checking purge action status: $($_.Exception.Message)" -ForegroundColor Red
        Remove-ComplianceSearch -Identity $complianceSearchName -Confirm:$false -ErrorAction SilentlyContinue
        Disconnect-ExchangeOnline -Confirm:$false
        Read-Host "Press Enter to exit."
        exit
    }
} while ($actionStatus -ne "Completed")

# Display a message when the purge is completed
Write-Host "Purge completed successfully." -ForegroundColor Green

# Clean up the compliance search
Write-Host "Cleaning up compliance search..."
Remove-ComplianceSearch -Identity $complianceSearchName -Confirm:$false -ErrorAction SilentlyContinue

# Disconnect sessions
Write-Host "Disconnecting sessions..."
Disconnect-ExchangeOnline -Confirm:$false
Write-Host "Disconnected."

# Pause to keep the console window open
Read-Host "Press Enter to exit."