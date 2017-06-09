# ====================================================================== #
# Config 
Get-Netadapter Ethernet* | Rename-Netadapter -NewName PROD
New-NetIpAddress -interfacealias PROD -ipaddress 192.168.100.10 -prefixlength 24 -defaultGateway 192.168.100.254
Set-DnsClientServerAddress -interfacealias PROD -ServerAddress 192.168.100.10 

Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False

Rename-Computer -NewName $compName -Restart 

wmic --% useraccount where name="Administrator" rename LocalAdmin

Add-Computer -DomainName ad.elgoog.com -OUPath "ou=infra,dc=fanco,dc=com"  -Restart

# ====================================================================== #
# DC
install-windowsfeature ad-domian-services
Install-ADDSForest -CreateDNSDelegation:$false -DomainName "fanco.com" `
    -DomainMode "Win2012" -ForestMode "Win2012" -InstallDNS:$True `
    -SafeModeAdministratorPassword ((Get-Credential).Password) -Force:$true

# ====================================================================== #
# router configuration

Install-WindowsFeature Routing -IncludeManagementTools
Get-NetAdapter | Set-NetIpInterface -Forwarding Enabled 

# ====================================================================== #
Install-WindowsFeature fs-iscsitarget-server -IncludeManagementTools

