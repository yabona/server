# ====================================================================== #
# Config 
Get-Netadapter Ethernet* | Rename-Netadapter -NewName PROD
New-NetIpAddress -interfacealias PROD -ipaddress 192.168.100.10 -prefixlength 24 -defaultGateway 192.168.100.254
Set-DnsClientServerAddress -interfacealias PROD -ServerAddress 192.168.100.10 

Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False

# core machine only
Set-displayresolution -height 600 -width 800 -force

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

wbadmin start backup -backuptarget:\\dc1\e$ -AllCritical 
Stop-Computer -force

# create dhcp scope on DC...
Add-DhcpServerv4Scope -StartRange 192.168.100.50 -EndRange 192.168.100.100 -SubnetMask 255.255.255.0 -Name DHCP
Set-DhcpServerv4OptionValue -OptionId 003 -ScopeId 192.168.100.0 -Value 192.168.100.254 
Set-DhcpServerv4OptionValue -OptionId 006 -ScopeId 192.168.100.0 -Value 192.168.100.10
Set-DhcpServerv4OptionValue -optionid 0015 -ScopeId 192.168.100.0 -Value "fanco.com"

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

<# Insert WinPE disk
 # boot machine in HV
 # Connect to DC1 and load image
 #>

 # shift + f10
 diskpart 
  > sel disk 1
  > clean
  > create part primary
  > format fs=NTFS label="BOOT" quick
 netsh int ipv4 set address Name=Ethernet0 static 192.168.100.12 255.255.255.0 
 pushd \\dc1\e$
 wbadmin get versions -backuptarget:\\dc1\e$
 wbadmin start sysrecovery -version:[guid] -machine MS1 -recoverytarget:C:\ -restoreAllVolumes -recreateDisks

<#
 # Replication... 
 # Make for damn sure that the SAN at both ends is not write-protected...
 # Every time, man. Every time. 
 #>

 # enable replication at both ends, as follows
Enable-VMReplication * hv2.fanco.com 80 kerberos
set-vmreplicationserver -ReplicationEnabled:$true -AllowedAuthenticationType Kerberos -ReplicationAllowedFromAnyServer:$false 
New-VMReplicationAuthorizationEntry hv2.fanco.com -ReplicaStorageLocation E:\ -TrustGroup fanco_com
set-vmreplication -VMName MS1-Core -ReplicationFrequencySec 30 

Get-VM | Start-VMInitialReplication 

# Failover 
Get-VM | Stop-VM

# move to replica server...
Start-VMFailover ms1-core -Prepare
Start-VMFailover -VMName MS1-core -ComputerName hv2
set-vmreplication -reverse -vmname ms1-core -ComputerName HV2
Start-VM -name ms1-core -ComputerName hv2

# move back to primary server...
Start-VMFailover ms1-core -Prepare
Start-VMFailover -vmname ms1-core -computername hv1
Set-VMReplication -reverse -vmname ms1-core -computername hv1
start-vm -name ms1-core -computername hv1

# show commands
Get-VMReplication | fl name,primaryserver,replicaserver,authtype,ReplicaPort,ReplicationFrequencySec
Get-VM | fl VMname,ReplicationState,ReplicationHealth

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

# ======================================== #
# Extra Goodies #

Get-ADComputer -filter *|%{Invoke-GPUpdate -Computer $_.dnshostname -Force -AsJob} 

$serverList = (Get-ADComputer -filter {name -notlike "*DC*"} ).dnsHostName
foreach ($i in $serverList) { Stop-Computer -ComputerName $i -AsJob -force } 
Get-Job | Wait-Job ; Stop-Computer

