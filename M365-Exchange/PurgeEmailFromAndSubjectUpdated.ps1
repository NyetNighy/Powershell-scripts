
$upn = Read-Host "Enter the User Principal Name (UPN) for connecting to Security & Compliance"

$searchName = Read-Host "Enter the Compliance Search Name (e.g., PurgeAbbeyGazetteEmail)"

$fromCommand = Read-Host "Enter sender email address or full query (leave blank to search only by subject)"

$subject = Read-Host "Enter the email subject to search for (leave blank to search only by sender)"

try {

    Import-Module ExchangeOnlineManagement -Force -ErrorAction Stop

    Write-Host "Connecting to Security & Compliance Center..." -ForegroundColor Cyan

    Connect-IPPSSession `
        -UserPrincipalName $upn `
        -EnableSearchOnlySession `
        -ShowBanner:$false `
        -ErrorAction Stop

    # Build query – both from and subject are optional, but at least one is required
    $queryParts = @()

    if (![string]::IsNullOrWhiteSpace($fromCommand)) {
        if ($fromCommand -notmatch '^(from:|to:|cc:|bcc:|subject:)') {
            $fromCommand = "from:$fromCommand"
        }
        $queryParts += $fromCommand
    }

    if (![string]::IsNullOrWhiteSpace($subject)) {
        # Remove embedded quotes that KQL doesn't support
        $cleanSubject = $subject.Replace('"', '').Trim()
        $queryParts += "subject:`"$cleanSubject`""
    }

    if ($queryParts.Count -eq 0) {
        Write-Host "Error: You must provide at least a sender or a subject." -ForegroundColor Red
        Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
        Read-Host "Press Enter to exit"
        exit
    }

    $contentMatchQuery = $queryParts -join " AND "

    Write-Host ""
    Write-Host "Using ContentMatchQuery:" -ForegroundColor Yellow
    Write-Host $contentMatchQuery -ForegroundColor Green
    Write-Host ""

    $existingSearch = Get-ComplianceSearch -Identity $searchName -ErrorAction SilentlyContinue

    if ($existingSearch) {

        Write-Host "A search named '$searchName' already exists." -ForegroundColor Yellow

        $remove = Read-Host "Delete existing search and recreate? (Y/N)"

        if ($remove -match '^[Yy]$') {

            Remove-ComplianceSearch `
                -Identity $searchName `
                -Confirm:$false `
                -ErrorAction Stop

            Write-Host "Existing search removed." -ForegroundColor Green

            Start-Sleep -Seconds 10
        }
        else {

            Write-Host "Operation cancelled." -ForegroundColor Yellow
            exit
        }
    }

    Write-Host "Creating compliance search: $searchName" -ForegroundColor Cyan

    New-ComplianceSearch `
        -Name $searchName `
        -ExchangeLocation All `
        -ContentMatchQuery $contentMatchQuery `
        -ErrorAction Stop

    Write-Host "Starting compliance search..." -ForegroundColor Cyan

    Start-ComplianceSearch `
        -Identity $searchName `
        -ErrorAction Stop

    Write-Host "Waiting for compliance search to complete..." -ForegroundColor Cyan

    do {

        Start-Sleep -Seconds 10

        $searchStatus = Get-ComplianceSearch -Identity $searchName

        Write-Host "Search status: $($searchStatus.Status)"

    } while ($searchStatus.Status -ne "Completed")

    Write-Host ""
    Write-Host "Compliance search results:" -ForegroundColor Green

    $finalSearch = Get-ComplianceSearch -Identity $searchName

    $finalSearch |
        Select-Object Name, Status, Items, Size, SuccessResults |
        Format-List

    if ([int]$finalSearch.Items -eq 0) {

        Write-Host ""
        Write-Host "No items found for the search. Cannot proceed with purge." -ForegroundColor Yellow

        Disconnect-ExchangeOnline -Confirm:$false

        Read-Host "Press Enter to exit"

        exit
    }

    Write-Host ""
    Write-Host "$($finalSearch.Items) item(s) found." -ForegroundColor Green

    Write-Host ""
    Write-Host "Select purge type:" -ForegroundColor Cyan
    Write-Host "  1 = SoftDelete  (moves to Recoverable Items – can still be recovered)"
    Write-Host "  2 = HardDelete  (permanent deletion – very difficult/impossible to recover)"
    Write-Host ""

    do {
        $purgeChoice = Read-Host "Enter 1 or 2"
    } while ($purgeChoice -notin @("1", "2"))

    if ($purgeChoice -eq "1") {
        $purgeType = "SoftDelete"
        $purgeColour = "Yellow"
    }
    else {
        $purgeType = "HardDelete"
        $purgeColour = "Red"
    }

    $confirmPurge = Read-Host "Proceed with $purgeType purge? This action cannot be undone easily. (Y/N)"

    if ($confirmPurge -notmatch '^[Yy]$') {

        Write-Host "Purge cancelled by user." -ForegroundColor Yellow

        Disconnect-ExchangeOnline -Confirm:$false

        Read-Host "Press Enter to exit"

        exit
    }

    Write-Host ""
    Write-Host "Creating $purgeType purge action..." -ForegroundColor $purgeColour

    New-ComplianceSearchAction `
        -SearchName $searchName `
        -Purge `
        -PurgeType $purgeType `
        -Confirm:$false `
        -ErrorAction Stop | Out-Null

    Start-Sleep -Seconds 10

    Write-Host "Waiting for purge to complete..." -ForegroundColor Cyan

    do {

        Start-Sleep -Seconds 10

        try {

            $purgeStatus = Get-ComplianceSearchAction |
                Where-Object {
                    $_.SearchName -eq $searchName -and
                    $_.Action -eq "Purge"
                } |
                Sort-Object JobStartTime -Descending |
                Select-Object -First 1

            if ($purgeStatus) {
                Write-Host "Purge status: $($purgeStatus.Status)"
            }
            else {
                Write-Host "Waiting for purge action to be created..."
            }

        }
        catch {

            Write-Host "Waiting for purge status..."
        }

    } while (!$purgeStatus -or $purgeStatus.Status -notin @("Completed", "PartiallySucceeded", "Failed"))

    Write-Host ""

    switch ($purgeStatus.Status) {

        "Completed" {

            Write-Host "$purgeType purge completed successfully." -ForegroundColor Green
        }

        "PartiallySucceeded" {

            Write-Host "Purge completed with some failures." -ForegroundColor Yellow
            $purgeStatus | Format-List
        }

        "Failed" {

            Write-Host "Purge failed." -ForegroundColor Red
            $purgeStatus | Format-List
        }
    }
}
catch {

    Write-Host ""
    Write-Host "Error:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}
finally {

    try {

        Disconnect-ExchangeOnline `
            -Confirm:$false `
            -ErrorAction SilentlyContinue

    }
    catch {
    }

    Read-Host "Press Enter to exit"
}