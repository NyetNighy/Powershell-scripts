#Requires -Modules Microsoft.Graph.Authentication, Microsoft.Graph.Groups

<#
.SYNOPSIS
    Finds Microsoft 365 groups (Unified) with zero members and zero owners,
    then adds the currently signed-in Global Admin as Owner (and Member).
    Skips Distribution Lists and Security groups.

.NOTES
    - Requires Global Admin (or equivalent) rights.
    - Uses interactive browser sign-in.
    - Scope: Group.ReadWrite.All + User.Read
#>

# ---------- Configuration ----------
$AddAsMemberAsWell = $true   # Set to $false if you only want Owner, not Member
# ----------------------------------

Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan

Connect-MgGraph -Scopes "Group.ReadWrite.All","User.Read" -NoWelcome

# Get the signed-in user (the Global Admin running the script)
$context = Get-MgContext
$signedInUser = Get-MgUser -UserId $context.Account

Write-Host "Signed in as: $($signedInUser.DisplayName) <$($signedInUser.UserPrincipalName)>" -ForegroundColor Green
Write-Host "Object ID: $($signedInUser.Id)`n"

# Retrieve only Microsoft 365 groups (Unified)
Write-Host "Retrieving Microsoft 365 groups (Unified)..." -ForegroundColor Cyan

$allGroups = Get-MgGroup -All -Filter "groupTypes/any(c:c eq 'Unified')" `
    -Property "Id,DisplayName,GroupTypes,MailEnabled,SecurityEnabled"

Write-Host "Found $($allGroups.Count) Microsoft 365 groups. Checking for empty ones...`n"

$emptyGroups = @()
$processed = 0

foreach ($group in $allGroups) {
    $processed++
    if ($processed % 50 -eq 0) {
        Write-Host "  Checked $processed / $($allGroups.Count) groups..." -ForegroundColor DarkGray
    }

    # Get owners and members
    $owners  = Get-MgGroupOwner  -GroupId $group.Id -All -ErrorAction SilentlyContinue
    $members = Get-MgGroupMember -GroupId $group.Id -All -ErrorAction SilentlyContinue

    $ownerCount  = if ($owners)  { $owners.Count }  else { 0 }
    $memberCount = if ($members) { $members.Count } else { 0 }

    if ($ownerCount -eq 0 -and $memberCount -eq 0) {
        $emptyGroups += [PSCustomObject]@{
            Id          = $group.Id
            DisplayName = $group.DisplayName
            GroupTypes  = ($group.GroupTypes -join ",")
            MailEnabled = $group.MailEnabled
            SecurityEnabled = $group.SecurityEnabled
        }
    }
}

Write-Host "`nFound $($emptyGroups.Count) Microsoft 365 group(s) with zero members and zero owners.`n" -ForegroundColor Yellow

if ($emptyGroups.Count -eq 0) {
    Write-Host "Nothing to do. Disconnecting..." -ForegroundColor Green
    Disconnect-MgGraph | Out-Null
    return
}

# Show the empty groups
$emptyGroups | Format-Table -AutoSize

$confirm = Read-Host "`nDo you want to add $($signedInUser.UserPrincipalName) as Owner (and Member) to these groups? (Y/N)"
if ($confirm -notmatch '^[Yy]') {
    Write-Host "Cancelled by user." -ForegroundColor Red
    Disconnect-MgGraph | Out-Null
    return
}

# Add the signed-in user as Owner (and optionally Member)
foreach ($g in $emptyGroups) {
    Write-Host "Processing: $($g.DisplayName) ($($g.Id))" -ForegroundColor Cyan

    try {
        # Add as Owner
        $ownerParams = @{
            "@odata.id" = "https://graph.microsoft.com/v1.0/users/$($signedInUser.Id)"
        }
        New-MgGroupOwnerByRef -GroupId $g.Id -BodyParameter $ownerParams -ErrorAction Stop
        Write-Host "  → Added as Owner" -ForegroundColor Green

        # Optionally add as Member as well
        if ($AddAsMemberAsWell) {
            $memberParams = @{
                "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$($signedInUser.Id)"
            }
            New-MgGroupMemberByRef -GroupId $g.Id -BodyParameter $memberParams -ErrorAction Stop
            Write-Host "  → Added as Member" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "  → ERROR: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`nDone. Disconnecting from Microsoft Graph..." -ForegroundColor Cyan
Disconnect-MgGraph | Out-Null
Write-Host "Script finished." -ForegroundColor Green
