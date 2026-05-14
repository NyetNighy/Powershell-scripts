#Requires -Module ActiveDirectory

# Import the Active Directory module
Import-Module ActiveDirectory -ErrorAction Stop


# Prompt for source and target group names
$SourceGroup = Read-Host "Enter the source group name (e.g., Finance-Users)"
$TargetGroup = Read-Host "Enter the target group name (e.g., All-Employees)"

# Validate input
if (-not $SourceGroup) {
    Write-Error "Source group name cannot be empty."
    exit 1
}
if (-not $TargetGroup) {
    Write-Error "Target group name cannot be empty."
    exit 1
}


# Function to build common parameters for AD cmdlets
function Get-ADCommonParams {
    $params = @{}
    if ($Server) { $params['Server'] = $Server }
    if ($UseCredentials -and $Credential) { $params['Credential'] = $Credential }
    return $params
}

try {
    Write-Host "Connecting to Active Directory..." -ForegroundColor Green
    
    # Verify source and target groups exist
    $commonParams = Get-ADCommonParams
    $sourceGroupObj = Get-ADGroup -Identity $SourceGroup @commonParams -ErrorAction Stop
    $targetGroupObj = Get-ADGroup -Identity $TargetGroup @commonParams -ErrorAction Stop
    
    Write-Host "Source group '$SourceGroup' found (DN: $($sourceGroupObj.DistinguishedName))" -ForegroundColor Yellow
    Write-Host "Target group '$TargetGroup' found (DN: $($targetGroupObj.DistinguishedName))" -ForegroundColor Yellow
    
    # Get user members from source group (recursive, filter for users only)
    Write-Host "Retrieving user members from source group (recursive)..." -ForegroundColor Green
    $sourceUsers = Get-ADGroupMember -Identity $SourceGroup -Recursive @commonParams -ErrorAction Stop |
                   Where-Object { $_.objectClass -eq 'user' } |
                   Select-Object -ExpandProperty DistinguishedName
    
    Write-Host "Found $($sourceUsers.Count) user(s) in source group." -ForegroundColor Cyan
    
    if ($sourceUsers.Count -eq 0) {
        Write-Host "No users to copy. Exiting." -ForegroundColor Yellow
        exit
    }
    
    # Get current members of target group for comparison
    $targetCurrentMembers = Get-ADGroupMember -Identity $TargetGroup @commonParams -ErrorAction Stop |
                            Where-Object { $_.objectClass -eq 'user' } |
                            Select-Object -ExpandProperty DistinguishedName
    
    $usersToAdd = $sourceUsers | Where-Object { $targetCurrentMembers -notcontains $_ }
    $usersAlreadyInTarget = $sourceUsers | Where-Object { $targetCurrentMembers -contains $_ }
    
    Write-Host "Users already in target group: $($usersAlreadyInTarget.Count)" -ForegroundColor Gray
    Write-Host "New users to add: $($usersToAdd.Count)" -ForegroundColor Green
    
    if ($usersToAdd.Count -eq 0) {
        Write-Host "All users already exist in target group. No changes made." -ForegroundColor Yellow
        exit
    }
    
    # Add users to target group
    Write-Host "Adding users to target group..." -ForegroundColor Green
    $addedCount = 0
    foreach ($userDN in $usersToAdd) {
        try {
            Add-ADGroupMember -Identity $TargetGroup -Members $userDN @commonParams -ErrorAction Stop
            Write-Host "Added: $userDN" -ForegroundColor Green
            $addedCount++
        }
        catch {
            Write-Warning "Failed to add $userDN : $($_.Exception.Message)"
        }
    }
    
    Write-Host "Successfully added $addedCount user(s) to '$TargetGroup'." -ForegroundColor Green
    Write-Host "Script completed." -ForegroundColor Green
}
catch {
    Write-Error "Script failed: $($_.Exception.Message)"
    Write-Host "Full error: $($_.Exception | Format-List -Force)" -ForegroundColor Red
    exit 1
}