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
# DC
install-windowsfeature ad-domain-services

# ForestRoot domain
Install-ADDSForest -CreateDNSDelegation:$false -DomainName "fanco.com" `
    -DomainMode "Win2012" -ForestMode "Win2012" -InstallDNS:$True `
    -SafeModeAdministratorPassword ((Get-Credential).Password) -Force:$true

# Child-domain
Install-ADDSDomain -CreateDnsDelegation -installDNS -DomainMode Win2012R2 `
    -NewDomainName "Staff" -ParentDomainName "fanco.com" `
    -SafeModeAdministratorPassword ("Windows1" | ConvertTo-SecureString -AsPlainText -Force) 

# ====================================================================== #
# router configuration
Install-WindowsFeature Routing -IncludeManagementTools
Get-NetAdapter | Set-NetIpInterface -Forwarding Enabled 

# NAT config
Install-RemoteAccess -VpnType Vpn
NETSH routing ip nat install
NETSH routing ip nat add interface EXT-NAT
NETSH routing ip nat set interface EXT-NAT mode=full
NETSH routing ip nat add interface PROD mode=private
#Show command: 
NETSH routing ip nat dump


# ====================================================================== #
Install-WindowsFeature fs-iscsitarget-server -IncludeManagementTools

New-IscsiVirtualDisk -SizeBytes 30GB -path C:\ISCSI-DISKS\DC1.vhdx
New-IscsiVirtualDisk -SizeBytes 60GB -path C:\ISCSI-DISKS\HV1.vhdx

New-IscsiServerTarget -targetname DC1 -InitiatorIds IPaddress:192.168.100.10
New-IscsiServerTarget -targetname HV1 -InitiatorIds IPaddress:192.168.100.21
    
Add-IscsiVirtualDiskTargetMapping -TargetName DC1 -Path C:\ISCSI-DISKS\DC1.vhdx
Add-IscsiVirtualDiskTargetMapping -TargetName HV1 -Path C:\ISCSI-DISKS\HV1.vhdx

(Get-IscsiServerTarget).TargetIqn

# -- -- -- -- 
# On HV-node/initiator end...

net start msiscsi
sc config msiscsi start=auto

Connect-IscsiTarget -NodeAddress iqn.1991-05.com.microsoft:san1-hv1-target

diskpart 
 > sel disk 1
 > attrib disk clear readonly 
 > create partition primary
 > format quick fs=NTFS label="ISCSI-SAN1"
 > select volume [3]
 > assign letter=E
iscsicpl.exe

# ======================================================================== #
# On memberserver
Install-WindowsFeature Windows-server-backup -IncludeManagementTools

diskpart 
 > sel vol []
 > shrink querymax 
 > shrink desired=50000

wbadmin start backup -backuptarget:\\dc1\e$ -AllCritical 
Stop-Computer -force


# ======================================== #
# configure virtualization
Install-WindowsFeature Hyper-V -IncludeManagementTools

New-VMSwitch -Name ext_PROD -AllowManagementOS:$true -NetAdapterName PROD 
New-Vhd -dynamic -path X:\Hyper-V\MS1.vhdx -SizeBytes 20GB
New-VM -name MS1 -generation 1 -memoryStartupBytes 512MB -switchname ext_PROD `
    -path x:\Hyper-v\ -vhdpath X:\hyper-v\ms1.vhdx
Set-VMMemory -vmname MS1 -DynamicMemoryEnabled:$True -MaximumBytes 1GB

# ========================================= #
# recovery (read up on this)

 # shift + f10
 diskpart 
  > sel disk 1
  > clean
 
 wpeutil initializenetwork
 netsh int ipv4 set address Name=Ethernet0 static 192.168.100.12 255.255.255.0 
 net use \\dc1\e$ /user:fanco\administrator
 wbadmin get versions -backuptarget:\\dc1\e$
 wbadmin start sysrecovery -backuptarget:\\dc1\e$ -version:[id] -machine MS1 -restoreAllVolumes -recreateDisks



# ========================================================== #
# VM Replication

<#
 # Replication... 
 # Make for damn sure that the SAN at both ends is not write-protected...
 # Every time, man. Every time. 
 #>

# enable replication at both ends, as follows
# Make sure it uses FQDNs, it will not work otherwise. 
 # SERVER1
Set-VMReplicationServer -ReplicationEnabled:$true -AllowedAuthenticationType Kerberos -ReplicationAllowedFromAnyServer:$false 
New-VMReplicationAuthorizationEntry hv2.fanco.com -ReplicaStorageLocation E:\ -TrustGroup fanco_com
 # SERVER2
Set-VMReplicationServer -ReplicationEnabled:$true -AllowedAuthenticationType Kerberos -ReplicationAllowedFromAnyServer:$false 
New-VMReplicationAuthorizationEntry hv1.fanco.com -ReplicaStorageLocation E:\ -TrustGroup fanco_com

 # Enable Replication on VM: 
Enable-VMReplication * hv2.fanco.com 80 kerberos
set-vmreplication -VMName MS1-Core -ReplicationFrequencySec 30 

 # Start initial D... No, initial replication!
Get-VM | Start-VMInitialReplication 

# move to replica server...
Get-VM -ComputerName HV1 | Stop-VM -ComputerName HV1
Start-VMFailover ms1 -Prepare
Start-VMFailover -VMName MS1 -ComputerName hv2
set-vmreplication -reverse -vmname ms1 -ComputerName HV2 
Start-VM -name ms1 -ComputerName hv2

# move back to primary server...
Get-VM -ComputerName HV2 | Stop-VM -ComputerName HV2
Start-VMFailover ms1 -Prepare
Start-VMFailover -vmname ms1 -computername hv1
Set-VMReplication -reverse -vmname ms1 -computername hv1
start-vm -name ms1 -computername hv1

# show commands
Get-VMReplication | fl name,primaryserver,replicaserver,authtype,ReplicaPort,ReplicationFrequencySec
Get-VM -ComputerName HV1 | fl VMname,state,ReplicationState,ReplicationHealth
Get-VM -ComputerName HV2 | fl VMname,state,ReplicationState,ReplicationHealth

# ================================================================#
# failover networking
Enable-VMIntegrationService -vmname MS1-Core -Name 'Guest Service Interface' -ComputerName HV1
Enable-VMIntegrationService -vmname MS1-Core -Name 'Guest Service Interface' -ComputerName HV2

Set-VMNetworkAdapterFailoverConfiguration -VMName MS1-Core -ComputerName HV1 `
    -IPv4Address 192.168.100.50 -IPv4SubnetMask 255.255.255.0  `
    -IPv4PreferredDNSServer 192.168.100.10 -IPv4DefaultGateway 192.168.100.254

Set-VMNetworkAdapterFailoverConfiguration -VMName MS1-Core -ComputerName HV2 `
    -IPv4Address 192.168.200.50 -IPv4SubnetMask 255.255.255.0 `
    -IPv4PreferredDNSServer 192.168.100.10 -IPv4DefaultGateway 192.168.200.254

# Show commands
Get-VMNetworkAdapterFailoverConfiguration -ComputerName HV1 -VMName MS1-Core
Get-VMNetworkAdapterFailoverConfiguration -ComputerName HV2 -VMName MS1-Core

# ================================================================#
# DNS and DHCP config

# on DNS server situated on NAT network, routing to internal network: 
route add 192.168.0.0 mask 255.255.0.0 200.0.0.250

# MS2
get-windowsfeature dhcp,dns | Install-WindowsFeature -IncludeManagementTools

net stop DHCPserver
net stop DNSs
net start DHCPserver
net start DNS

# Enable cachelocking
dnscmd /config /CacheLockingPercent 100
# Disable cachelocking 
dnscmd /config /CacheLockingPercent 0

dnscmd /clearCache

dnscmd /zoneUpdateFromDS
dnscmd /statistics

Set-DnsServerForwarder -IPAddress 208.67.222.222

###########################
# DHCP
# create dhcp scope on DC...
Add-DhcpServerv4Scope -StartRange 192.168.100.50 -EndRange 192.168.100.100 -SubnetMask 255.255.255.0 -Name DHCP
Set-DhcpServerv4OptionValue -OptionId 003 -ScopeId 192.168.100.0 -Value 192.168.100.254 
Set-DhcpServerv4OptionValue -OptionId 006 -ScopeId 192.168.100.0 -Value 192.168.100.10
Set-DhcpServerv4OptionValue -optionid 0015 -ScopeId 192.168.100.0 -Value "fanco.com"

# Set policy on DHCP server
    <# 
     # R.Clk IPv4 and define user options 
     # set title
     # In ASCII define value assigned to client
    #>

# client side settings
ipconfig /setclassid PROD "FastInternet"

ipconfig /showclassid PROD

#=============+++++======================+#
# IPAM
Invoke-IpamGpoProvisioning -Domain fanco.com -GpoPrefixName IPAM1 -IpamServerFqdn ipam.fanco.com

Invoke-IpamServerProvisioning -GpoPrefix IPAM1 -ProvisioningMethod Automatic 

Add-IpamDiscoveryDomain -Name noah.local -PassThru 

Add-IpamServerInventory -Name BAILEY-DHCP -ServerType DHCP -ManageabilityStatus Managed
Add-IpamServerInventory -name BAILEY-DC1 -ServerType DHCP,DNS -ManageabilityStatus Managed 



# Configer in server manager
# select servers
 # Unmanaged > managed
# Unblock --wtf???
# Firewalls disabled on both servers (PS)
# Make GPO to allow it
# Unblock somehow. may take some time. 

# turn all the firewalls off
# make for god damn sure that the DC is "domainAuth"
Get-NetConnectionProfile

# Add the IPAM server to the Administrators group

# update: all the servers have netconnection profiles of "Public"
Set-NetConnectionProfile -NetworkCategory DomainAuthenticated -InterfaceAlias PROD
 # This doesn't work for some ungodly reason!
net stop nlasvc
net start nlasvc

sc query dhcp
net stop dhcp
net start dhcp

# =========================================== #
dssite.msc # configure sites 
domain.msc # configure upn suffix

Get-ADuser -Filter {Name -like "Thicc Boi"} -Properties UserPrincipalName

whoami /upn

# ======================================== #
# Extra Goodies #

Get-ADComputer -filter *|%{Invoke-GPUpdate -Computer $_.dnshostname -Force -AsJob} 

$serverList = (Get-ADComputer -filter {name -notlike "*DC*"} ).dnsHostName
foreach ($i in $serverList) { Stop-Computer -ComputerName $i -AsJob -force } 
Get-Job | Wait-Job ; Stop-Computer