#Install connect tools (MSOnline)

Install-Module MSOnline

#add too session

Import-Module MSOnline

#connect to AD

Connect-MsolService

$userUPN = Read-Host -Prompt "Enter the Username of the user that requires a password reset"
$newPassword = Read-Host -Prompt "Enter a new password for the user"
Write-Host "Changing user $userUPN password to $newPassword"

#$userUPN="test@YOUR_DOMAIN"
#$newPassword="password2"

#Set Password Complexity to False
Set-MsolUser -UserPrincipalName $userUPN -StrongPasswordRequired $false

#Change User Password
Set-MsolUserPassword -UserPrincipalName $userUPN -NewPassword $newPassword -ForceChangePassword $false

#Set Password Complexity to True
Set-MsolUser -UserPrincipalName $userUPN -StrongPasswordRequired $true