# Prompt the user for the user principal name (UPN)
$UPN = Read-Host -Prompt 'Enter the User Principal Name (UPN) for connecting to Security & Compliance'

# Prompt the user for the compliance search name
$complianceSearchName = Read-Host -Prompt 'Enter the Compliance Search Name (e.g., PurgeClientEmail)'

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
    Write-Host "Installing/Updating ExchangeOnlineManagement module to version $requiredVersion or higher..." -ForegroundColor Yellow
    Install-Module -Name ExchangeOnlineManagement -Force -AllowClobber -MinimumVersion $requiredVersion
}
Import-Module ExchangeOnlineManagement

# Connect to Security & Compliance Center with DisableWAM (critical fix for WAM/auth issues)
$connected = $false
$maxConnectRetries = 3
$connectRetry = 0

while (-not $connected -and $connectRetry -lt $maxConnectRetries) {
    try {
        Write-Host "Connecting to Security & Compliance Center (Attempt $($connectRetry + 1)/$maxConnectRetries)..." -ForegroundColor Cyan
        Connect-IPPSSession -UserPrincipalName $UPN `
                           -EnableSearchOnlySession `
                           -DisableWAM `
                           -Verbose `
                           -ErrorAction Stop
        $connected = $true
        Write-Host "Successfully connected using -DisableWAM" -ForegroundColor Green
    }
    catch {
        $connectRetry++
        Write-Host "Connection failed: $($_.Exception.Message)" -ForegroundColor Red
        if ($connectRetry -lt $maxConnectRetries) {
            Write-Host "Retrying in 10 seconds..." -ForegroundColor Yellow
            Start-Sleep -Seconds 10
        }
        else {
            Write-Host "Failed to connect after $maxConnectRetries attempts." -ForegroundColor Red
            Read-Host "Press Enter to exit"
            exit
        }
    }
}

if (-not $connected) { exit }

# Create a new compliance search
try {
    Write-Host "Creating compliance search: $complianceSearchName" -ForegroundColor Cyan
    New-ComplianceSearch -Name $complianceSearchName -ExchangeLocation "All" -ContentMatchQuery $contentMatchQuery -Verbose -ErrorAction Stop
}
catch {
    Write-Host "Error creating compliance search: $($_.Exception.Message)" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    Disconnect-ExchangeOnline -Confirm:$false
    exit
}

# Start the compliance search
try {
    Write-Host "Starting compliance search..." -ForegroundColor Cyan
    Start-ComplianceSearch -Identity $complianceSearchName -Verbose -ErrorAction Stop
}
catch {
    Write-Host "Error starting compliance search: $($_.Exception.Message)" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    Disconnect-ExchangeOnline -Confirm:$false
    exit
}

# Wait for the completion of the compliance search
Write-Host "Waiting for compliance search to complete..." -ForegroundColor Cyan
$timeoutMinutes = 30
$startTime = Get-Date
do {
    Start-Sleep -Seconds 10
    try {
        $searchStatus = (Get-ComplianceSearch -Identity $complianceSearchName -ErrorAction Stop).Status
        Write-Host "Search status: $searchStatus"
    }
    catch {
        Write-Host "Error checking search status: $($_.Exception.Message)" -ForegroundColor Red
        Read-Host "Press Enter to exit"
        Disconnect-ExchangeOnline -Confirm:$false
        exit
    }
    if ((Get-Date) - $startTime -gt (New-TimeSpan -Minutes $timeoutMinutes)) {
        Write-Host "Search timed out after $timeoutMinutes minutes." -ForegroundColor Red
        Read-Host "Press Enter to exit"
        Disconnect-ExchangeOnline -Confirm:$false
        exit
    }
} while ($searchStatus -ne "Completed")

# Display information about the completed compliance search
Write-Host "Compliance search results:" -ForegroundColor Cyan
$searchResults = Get-ComplianceSearch -Identity $complianceSearchName | Select-Object Name, Items, Size, SuccessResults
$searchResults | Format-List

# Check if any items were found
if ($searchResults.Items -eq 0) {
    Write-Host "No items found for the search. Cannot proceed with purge." -ForegroundColor Yellow
    Remove-ComplianceSearch -Identity $complianceSearchName -Confirm:$false -ErrorAction SilentlyContinue
    Disconnect-ExchangeOnline -Confirm:$false
    Read-Host "Press Enter to exit"
    exit
}

# Create a new compliance search action to purge with retry logic
$maxRetries = 3
$retryCount = 0
$success = $false
while (-not $success -and $retryCount -lt $maxRetries) {
    try {
        Write-Host "Initiating purge action (Attempt $($retryCount + 1)/$maxRetries)..." -ForegroundColor Cyan
        $action = New-ComplianceSearchAction -SearchName $complianceSearchName -Purge -PurgeType HardDelete -Confirm:$false -Verbose -ErrorAction Stop
        $actionIdentity = $action.Identity
        Write-Host "Purge action created with Identity: $actionIdentity" -ForegroundColor Green
        $success = $true
    }
    catch {
        $retryCount++
        Write-Host "Error creating purge action: $($_.Exception.Message)" -ForegroundColor Red
        if ($retryCount -lt $maxRetries) {
            Write-Host "Retrying in 15 seconds..." -ForegroundColor Yellow
            Start-Sleep -Seconds 15
        }
        else {
            Write-Host "Max retries reached. Purge failed." -ForegroundColor Red
            Remove-ComplianceSearch -Identity $complianceSearchName -Confirm:$false -ErrorAction SilentlyContinue
            Disconnect-ExchangeOnline -Confirm:$false
            Read-Host "Press Enter to exit"
            exit
        }
    }
}

# Wait for the completion of the purge action (with better retry handling)
Write-Host "Waiting for purge action to complete..." -ForegroundColor Cyan
$actionCompleted = $false
$actionRetries = 0
$maxActionRetries = 12

do {
    Start-Sleep -Seconds 15
    try {
        $action = Get-ComplianceSearchAction -Identity $actionIdentity -ErrorAction Stop
        $actionStatus = $action.Status
        Write-Host "Purge action status: $actionStatus"
        if ($actionStatus -eq "Completed") {
            $actionCompleted = $true
        }
    }
    catch {
        $actionRetries++
        Write-Host "Retry $($actionRetries)/$maxActionRetries - $($_.Exception.Message)" -ForegroundColor Yellow
        if ($actionRetries -ge $maxActionRetries) {
            Write-Host "Failed to get purge action status after max retries." -ForegroundColor Red
            break
        }
    }
} while (-not $actionCompleted -and $actionRetries -lt $maxActionRetries)

if ($actionCompleted) {
    Write-Host "Purge completed successfully." -ForegroundColor Green
}
else {
    Write-Host "Purge action did not complete successfully within timeout." -ForegroundColor Red
}

# Clean up the compliance search
Write-Host "Cleaning up compliance search..." -ForegroundColor Cyan
Remove-ComplianceSearch -Identity $complianceSearchName -Confirm:$false -ErrorAction SilentlyContinue

# Disconnect sessions
Write-Host "Disconnecting sessions..." -ForegroundColor Cyan
Disconnect-ExchangeOnline -Confirm:$false
Write-Host "Disconnected." -ForegroundColor Green

# Pause to keep the console window open
Read-Host "Press Enter to exit"