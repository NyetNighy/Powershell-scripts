# ============================================================
# Create new group + copy members (Interactive)
# ============================================================

# --- Connect to Microsoft Graph ---
Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
Connect-MgGraph -Scopes "Group.ReadWrite.All", "Directory.Read.All", "User.Read.All"

Write-Host ""
Write-Host "=== Create New Group & Copy Members ===" -ForegroundColor Cyan
Write-Host ""

# --- Prompt for details ---
$oldGroupId = Read-Host "Enter the OLD Group Object ID (e.g. 4d53cf4a-49fa-45b6-98ff-54547c62dfd9)"
if ([string]::IsNullOrWhiteSpace($oldGroupId)) {
    Write-Host "Old Group ID is required. Exiting." -ForegroundColor Red
    return
}

$newGroupName = Read-Host "Enter the NEW Group Display Name (e.g. All Students - New)"
if ([string]::IsNullOrWhiteSpace($newGroupName)) {
    Write-Host "New Group Name is required. Exiting." -ForegroundColor Red
    return
}

$newGroupMailNick = Read-Host "Enter the NEW Group Mail Nickname (no spaces, e.g. AllStudentsNew)"
if ([string]::IsNullOrWhiteSpace($newGroupMailNick)) {
    Write-Host "Mail Nickname is required. Exiting." -ForegroundColor Red
    return
}

Write-Host ""
Write-Host "Summary of what will be created:" -ForegroundColor Yellow
Write-Host "  Old Group ID     : $oldGroupId"
Write-Host "  New Group Name   : $newGroupName"
Write-Host "  Mail Nickname    : $newGroupMailNick"
Write-Host ""

$confirm = Read-Host "Type YES to continue"
if ($confirm -ne "YES") {
    Write-Host "Aborted by user." -ForegroundColor Yellow
    return
}

# --- Create the new group ---
Write-Host "`nCreating new group '$newGroupName'..." -ForegroundColor Cyan

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

try {
    $members = Get-MgGroupMember -GroupId $oldGroupId -All -ErrorAction Stop
}
catch {
    Write-Host "Failed to get members from old group: $($_.Exception.Message)" -ForegroundColor Red
    return
}

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
