param (
    [paramater(mandatory=$true)][String]$domainName
    [String]
)

Install-WindowsFeature ad-domain-services -IncludeManagementTools

Install-ADDSForest -CreateDNSDelegation:$false -DomainName $domainName `
    -DomainMode "Win2012" -ForestMode "Win2012" -InstallDNS:$True  `
    -SafeModeAdministratorPassword ((Get-Credential).Password) -Force:$true
