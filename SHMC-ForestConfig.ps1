#####################################
# SHMC-DC1
$name = 'SHMC-DC1'
$IP = '172.30.10.10'

get-netadapter | Rename-NetAdapter -newname DATACENTER
Rename-Computer -newname $name 

new-netipaddress -InterfaceAlias DATACENTER -IPAddress $IP -PrefixLength 24 -DefaultGateway 172.30.10.1
Set-DnsClientServerAddress -InterfaceAlias DATACENTER -ServerAddresses 172.30.10.10

Install-WindowsFeature AD-Domain-Services -IncludeManagementTools 

Install-ADDSforest -CreateDnsDelegation:$false -DomainName "shmc.ca" -DomainMode Win2012R2 `
    -ForestMode Win2012R2 -SafeModeAdministratorPassword ((Get-Credential).Password) `
    -Force -InstallDns -NoRebootOnCompletion


################################################
# SHMC-DC2
$name = 'SHMC-DC2'
$IP = '172.30.10.11'

get-netadapter | Rename-NetAdapter -newname DATACENTER
Rename-Computer -NewName $name 

new-netipaddress -InterfaceAlias DATACENTER -IPAddress $IP -PrefixLength 24 -DefaultGateway 172.30.10.1
Set-DnsClientServerAddress -InterfaceAlias DATACENTER -ServerAddresses 172.30.10.10

Install-WindowsFeature AD-Domain-Services -IncludeManagementTools 

Add-Computer -DomainName SHMC.ca -Restart