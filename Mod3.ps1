# ====================================================================== #
# Config 
Shift+F10
 > wmic useraccount where name="Administrator" rename LocalAdmin 
 > net user LocalAdmin /active:yes
 > net user LocalAdmin * 
 > wmic comptuersystem where name="%COMPUTERNAME%" rename "$newname"
# done.

Get-Netadapter Ethernet* | Rename-Netadapter -NewName PROD
New-NetIpAddress -interfacealias PROD -ipaddress 192.168.100.10 -prefixlength 24 -defaultGateway 192.168.100.254
Set-DnsClientServerAddress -interfacealias PROD -ServerAddress 192.168.100.10 

Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False

# core machine only
Set-displayresolution -height 600 -width 800 -force

Rename-Computer -NewName $compName -Restart 

Add-Computer -DomainName ad.elgoog.com -OUPath "ou=infra,dc=fanco,dc=com"  -Restart

# ====================================================================== #
# router configuration
Install-WindowsFeature Routing -IncludeManagementTools
Get-NetAdapter | Set-NetIpInterface -Forwarding Enabled 

Set-NetFirewallProfile -all -Enabled False

New-NetNat -name EXT-NAT -ExternalIPInterfaceAddressPrefix 200.0.0.250/24
Add-NetNatExternalAddress -NatName EXT-NAT -IPAddress 200.0.0.250 


# ====================================================================== #
# DC
install-windowsfeature ad-domain-services

# ForestRoot domain
Install-ADDSForest -CreateDNSDelegation:$false -DomainName "fanco.com" `
    -DomainMode "Win2012" -ForestMode "Win2012" -InstallDNS:$True `
    -SafeModeAdministratorPassword ((Get-Credential).Password) -Force:$true

# secondary DC
Install-ADDSDomainController -DomainName fanco.local -WhatIf -InstallDns:$true

# Child-domain
Install-ADDSDomain -CreateDnsDelegation -installDNS -DomainMode Win2012R2 `
    -NewDomainName "Staff" -ParentDomainName "fanco.com" `
    -SafeModeAdministratorPassword ("Windows1" | ConvertTo-SecureString -AsPlainText -Force) 


# ===================================================================== #
# DNS config

# on router: 
Add-DnsServerConditionalForwarderZone -Name acme.local -MasterServers 10.100.100.10 
Add-DnsServerConditionalForwarderZone -Name east.fanco.local -MasterServers 192.168.101.11
Add-DnsServerConditionalForwarderZone -Name west.fanco.local -MasterServers 192.168.102.10
Add-DnsServerConditionalForwarderZone -name fanco.local -MasterServers 192.168.101.10,192.168.100.10

# on each DC: 
 # set DNS forwarder to router interface: 
Set-DnsServerForwarder ((Get-NetIPConfiguration).IPv4defaultgateway.nexthop)


# ====================================================================== #
# AD Forest trusts

# literally everything
domain.msc

# show trusts
Get-ADTrust -filter * | ft Name,Direction,Target,forestTransitive -AutoSize

# show site links
Get-ADReplicationSiteLink -filter * | ft Name,ReplicationFrequencyInMinutes,Cost -AutoSize


# ======================================================================= # 
# client side evidence
whoami /upn
(gwmi win32_computersystem).domain
wmic computersystem get domain,name

# ======================================================================= #
# ADCS configuration
Install-WindowsFeature ad-certificate -IncludeManagementTools -Restart