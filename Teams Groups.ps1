# Connect to Microsoft Teams
Connect-MicrosoftTeams -AccountId bctec@kinghenry.org.uk

# Retrieve all Teams groups
$AllTeams = Get-Team

# Create an empty array to store the Teams data
$TeamList = @()

# Iterate over each Team
foreach ($Team in $AllTeams) {
    $TeamGUID = $Team.GroupID
    $TeamName = $Team.DisplayName

    # Retrieve Team owners
    $TeamOwners = (Get-TeamUser -GroupId $Team.GroupId | Where-Object { $_.Role -eq 'Owner' }).Name -join ', '

    # Retrieve Team members
    $TeamMembers = (Get-TeamUser -GroupId $Team.GroupId | Where-Object { $_.Role -eq 'Member' }).Name -join ', '

    # Create a custom object and add it to the array
    $TeamObject = [PSCustomObject]@{
        TeamName     = $TeamName
        TeamObjectID = $TeamGUID
        TeamOwners   = $TeamOwners
        TeamMembers  = $TeamMembers
    }
    $TeamList += $TeamObject
}

# Export the Team data to a CSV file
$TeamList | Export-Csv -Path "C:\temp\TeamsData.csv" -NoTypeInformation