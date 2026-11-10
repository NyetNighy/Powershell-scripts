# ============================================================
# Create new group + copy members from an existing group
# Non-interactive version (hardcoded values)
# ============================================================

# --- Configuration ---
$oldGroupId       = "4d53cf4a-49fa-45b6-98ff-54547c62dfd9"   # Change this to the source group Object ID
$newGroupName     = "All Students - New"
$newGroupMailNick = "AllStudentsNew"

# --- Connect (if not already connected) ---
# Connect-MgGraph -Scopes "Group.ReadWrite.All", "Directory.Read.All", "User.Read.All"

# --- Create the new group ---
Write-Host "Creating new group '$newGroupName'..." -ForegroundColor Cyan

try {
    $newGroup = New-MgGroup -DisplayName $newGroupName `
                            -MailEnabled:$false `
                            -SecurityEnabled:$true `
                            -MailNickname $newGroupMailNick `
                            -GroupTypes @() `
                            -ErrorAction Stop

    $newGroupId = $newGroup.Id
    Write-Host "Created successfully." -ForegroundColor Green
    Write-Host "New Group ID: $newGroupId" -ForegroundColor Green
}
catch {
    Write-Host "Failed to create group: $($_.Exception.Message)" -ForegroundColor Red
    return
}

# --- Copy members ---
Write-Host "`nCopying members from old group..." -ForegroundColor Cyan

$members = Get-MgGroupMember -GroupId $oldGroupId -All
$total   = $members.Count
$added   = 0
$skipped = 0

Write-Host "Found $total members to process.`n"

foreach ($member in $members) {
    $upn = $member.AdditionalProperties.userPrincipalName
    if (-not $upn) { $upn = $member.Id }

    try {
        New-MgGroupMember -GroupId $newGroupId -DirectoryObjectId $member.Id -ErrorAction Stop
        Write-Host "  + Added: $upn" -ForegroundColor Green
        $added++
    }
    catch {
        Write-Host "  ~ Skipped: $upn" -ForegroundColor Yellow
        $skipped++
    }
}

# --- Summary ---
Write-Host "`n========== SUMMARY ==========" -ForegroundColor Cyan
Write-Host "New Group Name : $newGroupName"
Write-Host "New Group ID   : $newGroupId"
Write-Host "Members added  : $added"
Write-Host "Skipped        : $skipped"
Write-Host "=============================" -ForegroundColor Cyan
