Install-Module Microsoft.Graph -Force
Install-Module Microsoft.Graph.Beta -AllowClobber -Force
Connect-MgGraph -Scopes "Organization.ReadWrite.All,Directory.ReadWrite.All"
Get-MgOrganization | Select OnPremisesSyncEnabled
$organizationId = (Get-MgOrganization).Id
$params = @{ onPremisesSyncEnabled = $false }
Update-MgOrganization -OrganizationId $organizationId -BodyParameter $params
Get-MgOrganization | Select OnPremisesSyncEnabled