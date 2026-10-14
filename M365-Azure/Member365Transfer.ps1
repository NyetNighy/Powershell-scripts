#Requires -Version 5.1
<#
.SYNOPSIS
    Copy members from a source Microsoft 365 / Security group to a target group.
    Prompts for group IDs (or display names on failure), shows count, requires confirmation.
#>

$ErrorActionPreference = "Stop"

try {
    if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
        Write-Host "Installing Microsoft.Graph modules..." -ForegroundColor Yellow
        Install-Module Microsoft.Graph.Authentication, Microsoft.Graph.Groups -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
    }
    Import-Module Microsoft.Graph.Authentication -Force -ErrorAction Stop
    Import-Module Microsoft.Graph.Groups -Force -ErrorAction Stop

    Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
    Connect-MgGraph -Scopes "Group.ReadWrite.All", "User.Read.All", "Directory.Read.All" -NoWelcome -ErrorAction Stop

    $sourceGroupId = Read-Host "Enter the source group Object ID (GUID)"
    $targetGroupId = Read-Host "Enter the target group Object ID (GUID)"
    if ([string]::IsNullOrWhiteSpace($sourceGroupId) -or [string]::IsNullOrWhiteSpace($targetGroupId)) {
        throw "Source and target group IDs are required."
    }
    $sourceGroupId = $sourceGroupId.Trim()
    $targetGroupId = $targetGroupId.Trim()

    function Resolve-Group {
        param ($GroupId, $Label)
        try {
            $g = Get-MgGroup -GroupId $GroupId -ErrorAction Stop
            Write-Host "$Label group: $($g.DisplayName) ($($g.Id))" -ForegroundColor Cyan
            return $g
        }
        catch {
            Write-Host "$Label group ID not found. Trying display name..." -ForegroundColor Yellow
            $name = Read-Host "Enter $Label group display name"
            $found = Get-MgGroup -Filter "displayName eq '$name'" -ErrorAction SilentlyContinue
            if (-not $found) { throw "$Label group not found." }
            if ($found -is [array] -and $found.Count -gt 1) {
                Write-Host "Multiple matches; using first: $($found[0].DisplayName)" -ForegroundColor Yellow
                $found = $found[0]
            }
            Write-Host "$Label group: $($found.DisplayName) ($($found.Id))" -ForegroundColor Cyan
            return $found
        }
    }

    $source = Resolve-Group -GroupId $sourceGroupId -Label "Source"
    $target = Resolve-Group -GroupId $targetGroupId -Label "Target"

    $sourceMembers = Get-MgGroupMember -GroupId $source.Id -All -ErrorAction Stop
    $count = @($sourceMembers).Count

    if ($count -eq 0) {
        Write-Host "No members found in the source group." -ForegroundColor Yellow
        return
    }

    Write-Host "`nWill copy $count member(s) from '$($source.DisplayName)' → '$($target.DisplayName)'." -ForegroundColor Yellow
    $confirm = Read-Host "Proceed? (Y/N)"
    if ($confirm -notmatch '^[Yy]$') {
        Write-Host "Cancelled." -ForegroundColor Yellow
        return
    }

    $added = 0
    $already = 0
    $failed = @()

    foreach ($member in $sourceMembers) {
        try {
            New-MgGroupMember -GroupId $target.Id -DirectoryObjectId $member.Id -ErrorAction Stop
            Write-Host "  Added: $($member.Id)" -ForegroundColor Green
            $added++
        }
        catch {
            if ($_.Exception.Message -match 'already exist|One or more added object references already exist') {
                Write-Host "  Already member: $($member.Id)" -ForegroundColor Yellow
                $already++
            }
            else {
                Write-Host "  Failed: $($member.Id) — $($_.Exception.Message)" -ForegroundColor Red
                $failed += $member.Id
            }
        }
    }

    Write-Host "`nDone. Added: $added | Already: $already | Failed: $($failed.Count)" -ForegroundColor Cyan
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    try { Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null } catch { }
}
