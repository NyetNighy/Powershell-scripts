$emailList = Import-Csv -Path "C:\temp\emails.csv"

foreach ($email in $emailList) {
    $user = Get-AzureADUser -Filter "UserPrincipalName eq '$($email.EmailAddress)'"
    if ($user) {
        $user | Set-AzureADUser -AccountEnabled:$false
        Write-Host "Blocked sign-in for $($email.EmailAddress)"
    }
    else {
        Write-Host "User with email address $($email.EmailAddress) not found."
    }
}
