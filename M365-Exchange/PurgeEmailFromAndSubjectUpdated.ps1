# Prompt the user for the user principal name (UPN)
$UPN = Read-Host -Prompt 'Enter the User Principal Name (UPN) for connecting to Security & Compliance'

# Prompt the user for the compliance search name
$complianceSearchName = Read-Host -Prompt 'Enter the Compliance Search Name (e.g., PurgeAbbeyGazetteEmail)'

# Prompt the user for the ContentMatchQuery
$fromCommand = Read-Host -Prompt 'Enter the ContentMatchQuery (e.g., from:example@domain.com)'

# Prompt the user for the email subject
$subject = Read-Host -Prompt 'Enter the email subject to search for'

# Combine ContentMatchQuery with subject if provided
if ($subject) {
    $contentMatchQuery = "$fromCommand subject:`"$subject`""
} else {
    $contentMatchQuery = $fromCommand
}

# Bypass execution policy temporarily for the current process
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

# Check and install/update ExchangeOnlineManagement module to v3.9.0 or higher
$requiredVersion = [Version]"3.9.0"
$module = Get-Module -ListAvailable -Name ExchangeOnlineManagement | Sort-Object Version -Descending | Select-Object -First 1
if (-not $module -or $module.Version -lt $requiredVersion) {
    Write-Host "Installing/Updating ExchangeOnlineManagement module to version $requiredVersion or higher..."
    Install-Module -Name ExchangeOnlineManagement -Force -AllowClobber -MinimumVersion $requiredVersion
}
Import-Module ExchangeOnlineManagement

# Connect to Security & Compliance Center with required flag
try {
    Write-Host "Connecting to Security & Compliance Center with -EnableSearchOnlySession..."
    Connect-IPPSSession -UserPrincipalName $UPN -EnableSearchOnlySession -Verbose -ErrorAction Stop
} catch {
    Write-Host "Error connecting: $($_.Exception.Message)" -ForegroundColor Red
    Read-Host "Press Enter to exit."
    exit
}

# Create a new compliance search
try {
    Write-Host "Creating compliance search: $complianceSearchName"
    New-ComplianceSearch -Name $complianceSearchName -ExchangeLocation "All" -ContentMatchQuery $contentMatchQuery -Verbose -ErrorAction Stop
} catch {
    Write-Host "Error creating compliance search: $($_.Exception.Message)" -ForegroundColor Red
    Read-Host "Press Enter to exit."
    Disconnect-ExchangeOnline -Confirm:$false
    exit
}

# Start the compliance search
try {
    Write-Host "Starting compliance search..."
    Start-ComplianceSearch -Identity $complianceSearchName -Verbose -ErrorAction Stop
} catch {
    Write-Host "Error starting compliance search: $($_.Exception.Message)" -ForegroundColor Red
    Read-Host "Press Enter to exit."
    Disconnect-ExchangeOnline -Confirm:$false
    exit
}

# Wait for the completion of the compliance search
Write-Host "Waiting for compliance search to complete..."
$timeoutMinutes = 30
$startTime = Get-Date
do {
    Start-Sleep -Seconds 10
    try {
        $searchStatus = (Get-ComplianceSearch -Identity $complianceSearchName -ErrorAction Stop).Status
        Write-Host "Search status: $searchStatus"
    } catch {
        Write-Host "Error checking search status: $($_.Exception.Message)" -ForegroundColor Red
        Read-Host "Press Enter to exit."
        Disconnect-ExchangeOnline -Confirm:$false
        exit
    }
    if ((Get-Date) - $startTime -gt (New-TimeSpan -Minutes $timeoutMinutes)) {
        Write-Host "Search timed out after $timeoutMinutes minutes." -ForegroundColor Red
        Read-Host "Press Enter to exit."
        Disconnect-ExchangeOnline -Confirm:$false
        exit
    }
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

# Create a new compliance search action to purge with retry logic
$maxRetries = 3
$retryCount = 0
$success = $false
while (-not $success -and $retryCount -lt $maxRetries) {
    try {
        Write-Host "Initiating purge action (Attempt $($retryCount + 1)/$maxRetries)..."
        $action = New-ComplianceSearchAction -SearchName $complianceSearchName -Purge -PurgeType HardDelete -Confirm:$false -Verbose -ErrorAction Stop
        $actionIdentity = $action.Identity
        Write-Host "Purge action created with Identity: $actionIdentity"
        $success = $true
    } catch {
        $retryCount++
        Write-Host "Error creating purge action: $($_.Exception.Message)" -ForegroundColor Red
        if ($retryCount -lt $maxRetries) {
            Write-Host "Retrying in 10 seconds..."
            Start-Sleep -Seconds 10
        } else {
            Write-Host "Max retries reached. Purge failed." -ForegroundColor Red
            Remove-ComplianceSearch -Identity $complianceSearchName -Confirm:$false -ErrorAction SilentlyContinue
            Disconnect-ExchangeOnline -Confirm:$false
            Read-Host "Press Enter to exit."
            exit
        }
    }
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