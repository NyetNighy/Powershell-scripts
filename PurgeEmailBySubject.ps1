# PurgeEmailBySubject.ps1 - Updated February 2026
# Requires ExchangeOnlineManagement module v3.9.0 or higher

# Prompt for inputs
$UPN = Read-Host -Prompt 'Enter the User Principal Name (UPN) with eDiscovery Manager + Search And Purge roles'
$complianceSearchName = Read-Host -Prompt 'Enter the Compliance Search Name (e.g., PurgeSubjectEmail)'
$subject = Read-Host -Prompt 'Enter the email subject to search for (exact match)'

# Build KQL query (use quotes for exact subject match; adjust if partial/wildcard needed)
$contentMatchQuery = "subject:`"$subject`""

# Set execution policy for this session only
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

# Ensure ExchangeOnlineManagement module is installed and up to date
$module = Get-Module -ListAvailable -Name ExchangeOnlineManagement
if (-not $module) {
    Write-Host "Installing ExchangeOnlineManagement module..." -ForegroundColor Yellow
    Install-Module -Name ExchangeOnlineManagement -Force -AllowClobber -Scope CurrentUser
} elseif ($module.Version -lt [Version]"3.9.0") {
    Write-Host "Updating ExchangeOnlineManagement module to latest (requires >= 3.9.0)..." -ForegroundColor Yellow
    Update-Module -Name ExchangeOnlineManagement -Force -AllowPrerelease:$false
}
Import-Module ExchangeOnlineManagement -Force

# Connect ONLY to Security & Compliance with search-only session (critical fix)
try {
    Write-Host "Connecting to Microsoft Purview Security & Compliance (search-only mode)..." -ForegroundColor Cyan
    Connect-IPPSSession -UserPrincipalName $UPN -EnableSearchOnlySession -ErrorAction Stop
    Write-Host "Connected successfully." -ForegroundColor Green
} catch {
    Write-Host "Connection failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Ensure:" -ForegroundColor Yellow
    Write-Host "- Module is >= 3.9.0" -ForegroundColor Yellow
    Write-Host "- Account has eDiscovery Manager role (for search) AND Search And Purge role (for purge)" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit
}

# Create compliance search
try {
    Write-Host "Creating compliance search: $complianceSearchName" -ForegroundColor Cyan
    New-ComplianceSearch -Name $complianceSearchName -ExchangeLocation All -ContentMatchQuery $contentMatchQuery -ErrorAction Stop | Out-Null
} catch {
    Write-Host "Error creating search: $($_.Exception.Message)" -ForegroundColor Red
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
    Read-Host "Press Enter to exit"
    exit
}

# Start the search
try {
    Write-Host "Starting compliance search..." -ForegroundColor Cyan
    Start-ComplianceSearch -Identity $complianceSearchName -ErrorAction Stop | Out-Null
} catch {
    Write-Host "Error starting search: $($_.Exception.Message)" -ForegroundColor Red
    Remove-ComplianceSearch -Identity $complianceSearchName -Confirm:$false -ErrorAction SilentlyContinue
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
    Read-Host "Press Enter to exit"
    exit
}

# Wait for search to complete
Write-Host "Waiting for compliance search to complete..." -ForegroundColor Cyan
do {
    Start-Sleep -Seconds 10
    $search = Get-ComplianceSearch -Identity $complianceSearchName -ErrorAction Stop
    Write-Host "Search status: $($search.Status) | Items: $($search.Items) | Size: $($search.Size)" -ForegroundColor Yellow
} while ($search.Status -ne "Completed")

# Display results
Write-Host "`nCompliance search results:" -ForegroundColor Green
$search | Select-Object Name, Items, Size, SuccessResults | Format-List

if ($search.Items -eq 0) {
    Write-Host "No matching items found. No purge needed." -ForegroundColor Yellow
    Remove-ComplianceSearch -Identity $complianceSearchName -Confirm:$false -ErrorAction SilentlyContinue
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
    Read-Host "Press Enter to exit"
    exit
}

# Prompt confirmation before purge (safety)
$confirmPurge = Read-Host "Items found! Type YES to proceed with HARD DELETE purge (permanent, irreversible)"
if ($confirmPurge -ne "YES") {
    Write-Host "Purge aborted by user." -ForegroundColor Yellow
    Remove-ComplianceSearch -Identity $complianceSearchName -Confirm:$false -ErrorAction SilentlyContinue
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
    Read-Host "Press Enter to exit"
    exit
}

# Create purge action (HardDelete = permanent removal)
try {
    Write-Host "Initiating HARD DELETE purge..." -ForegroundColor Red
    $action = New-ComplianceSearchAction -SearchName $complianceSearchName -Purge -PurgeType HardDelete -Confirm:$false -ErrorAction Stop
    $actionIdentity = $action.Identity
    Write-Host "Purge action created: $actionIdentity" -ForegroundColor Cyan
} catch {
    Write-Host "Error creating purge action: $($_.Exception.Message)" -ForegroundColor Red
    Remove-ComplianceSearch -Identity $complianceSearchName -Confirm:$false -ErrorAction SilentlyContinue
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
    Read-Host "Press Enter to exit"
    exit
}

# Wait for purge action to complete
Write-Host "Waiting for purge action to complete..." -ForegroundColor Cyan
do {
    Start-Sleep -Seconds 10
    try {
        $actionStatus = (Get-ComplianceSearchAction -Identity $actionIdentity -ErrorAction Stop).Status
        Write-Host "Purge status: $actionStatus" -ForegroundColor Yellow
    } catch {
        Write-Host "Error checking purge status: $($_.Exception.Message)" -ForegroundColor Red
        break
    }
} while ($actionStatus -ne "Completed")

Write-Host "Purge completed successfully (Hard Delete)." -ForegroundColor Green

# Cleanup
Write-Host "Cleaning up compliance search..." -ForegroundColor Cyan
Remove-ComplianceSearch -Identity $complianceSearchName -Confirm:$false -Force -ErrorAction SilentlyContinue

# Disconnect
Write-Host "Disconnecting session..." -ForegroundColor Cyan
Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
Write-Host "Session disconnected." -ForegroundColor Green

Read-Host "Press Enter to exit"