
Connect-MgGraph -Scopes "Group.ReadWrite.All", "User.Read.All" -NoWelcome

$sourceGroupId = Read-Host "Enter the source group ID"
$targetGroupId = Read-Host "Enter the target group ID"

function Test-GroupExists {
    param ($GroupId, $GroupType)
    try {
        $group = Get-MgGroup -GroupId $GroupId -ErrorAction Stop
        Write-Host "$GroupType group found: $($group.DisplayName) (ID: $GroupId)"
        return $true
    } catch {
        Write-Host "Error: $GroupType group with ID $GroupId not found. $_"
        return $false
    }
}

if (-not (Test-GroupExists -GroupId $sourceGroupId -GroupType "Source")) {
    Write-Host "Checking if source group is deleted..."
    $deletedGroup = Get-MgDirectoryDeletedItem -Filter "microsoft.graph.group/id eq '$sourceGroupId'"
    if ($deletedGroup) {
        Write-Host "Source group is deleted. Restoring..."
        Restore-MgDirectoryDeletedItem -DirectoryObjectId $sourceGroupId
        Write-Host "Source group restored. Retrying..."
        if (-not (Test-GroupExists -GroupId $sourceGroupId -GroupType "Source")) {
            Write-Host "Prompt for source group display name:"
            $groupName = Read-Host "Enter the source group display name"
            $sourceGroup = Get-MgGroup -Filter "displayName eq '$groupName'"
            if ($sourceGroup) {
                $sourceGroupId = $sourceGroup.Id
                Write-Host "Found group: $($sourceGroup.DisplayName), ID: $sourceGroupId"
            } else {
                Write-Host "Group '$groupName' not found. Exiting."
                Disconnect-MgGraph
                exit
            }
        }
    } else {
        Write-Host "Group not found in deleted items. Please verify the source group ID or name."
        Disconnect-MgGraph
        exit
    }
}

if (-not (Test-GroupExists -GroupId $targetGroupId -GroupType "Target")) {
    Write-Host "Prompt for target group display name:"
    $groupName = Read-Host "Enter the target group display name"
    $targetGroup = Get-MgGroup -Filter "displayName eq '$groupName'"
    if ($targetGroup) {
        $targetGroupId = $targetGroup.Id
        Write-Host "Found group: $($targetGroup.DisplayName), ID: $targetGroupId"
    } else {
        Write-Host "Target group '$groupName' not found. Exiting."
        Disconnect-MgGraph
        exit
    }
}

$sourceMembers = Get-MgGroupMember -GroupId $sourceGroupId -All

if ($sourceMembers.Count -eq 0) {
    Write-Host "No members found in the source group."
    Disconnect-MgGraph
    exit
}

foreach ($member in $sourceMembers) {
    try {
        New-MgGroupMember -GroupId $targetGroupId -DirectoryObjectId $member.Id
        Write-Host "Added member $($member.Id) to target group."
    } catch {
        Write-Host "Failed to add member $($member.Id): $_"
    }
}

Disconnect-MgGraph

Write-Host "Member copy operation completed."