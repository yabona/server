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

New-IscsiVirtualDisk -SizeBytes 30GB -path C:\ISCSI-DISKS\DC1.vhdx
New-IscsiVirtualDisk -SizeBytes 60GB -path C:\ISCSI-DISKS\HV1.vhdx

New-IscsiServerTarget -targetname DC1 -InitiatorIds IPaddress:192.168.100.10
New-IscsiServerTarget -targetname HV1 -InitiatorIds IPaddress:192.168.100.21

    
Add-IscsiVirtualDiskTargetMapping -TargetName DC1 -Path C:\ISCSI-DISKS\DC1.vhdx
Add-IscsiVirtualDiskTargetMapping -TargetName HV1 -Path C:\ISCSI-DISKS\HV1.vhdx

# ======================================================================== #
Install-WindowsFeature Windows-server-backup -IncludeManagementTools

Add-DhcpServerv4Scope -StartRange 192.168.100.50 -EndRange 192.168.100.100 -Name DHCP
Set-DhcpServerv4OptionDefinition 

