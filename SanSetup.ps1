##############
# SAN config #
# NB - 2018  #
##############

Rename-Computer -NewName "TURBOENCABULATOR" -Force

# join workgroup: 
(Gwmi win32_Computersystem).JoinDomainOrWorkgroup("dc.ca")
Set-LocalUser -Name Administrator -Password:(ConvertTo-SecureString "CharlieHalt66" -asplaintext -force) # LOL; security

# assign network interface names
$MgmtNic = Get-Netadapter | ? {$_.InterfaceDescription -like "*5709C*"}
$IscsiNic = Get-NetAdapter | ? {$_.InterfaceDescription -like "*5716*" -and $_.status -eq "Up"}

Set-NetAdapterAdvancedProperty -Name:$IscsiNic.name -DisplayName "Jumbo Frame" -RegistryValue 9014
Set-NetAdapterAdvancedProperty -Name:$IscsiNic.name -DisplayName "Jumbo Frame" -RegistryValue 9014

$MgmtNic | Rename-NetAdapter "MGMT"
$IscsiNic | Rename-NetAdapter "ISCSI"

# Configure interface addressing and network firewall
New-NetIPAddress -IPAddress 10.1.3.100 -PrefixLength 8 -InterfaceIndex:$MgmtNic.ifIndex
New-NetIPAddress -IPAddress 20.1.3.100 -PrefixLength 8 -InterfaceIndex:$IscsiNic.ifIndex
Set-NetFirewallProfile -All -Enabled:$false

# sync time from NTP peer
win32tm /register
win32tm /config /syncfromflags:manual /manualpeerlist 10.0.100.5 
win32tm /config /update 

######################
# ISCSI Target server

$TargetConfig = new-object -type PSCustomObject -Property:@{
    VirtualDiskPath = "C:\ISCSI";
    VirtualDiskSize = 30GB; 
    TargetName = "SAN"
    TargetPermittedInitiatorID = "IPaddress:10.1.53.100";
    ChapCredential = New-Object pscredential ("Chappie", $(ConvertTo-SecureString "Windows1Windows1" -asPlainText -force)) 
} # as a wise man once said, "THIS IS SHIT FOR BRAINS, DRUG INDUCED CRAP". that man made the #3 operating system in the world. 

# Install feature and init service (run at boot)
Install-windowsfeature FS-iscsiTarget-Server -includeManagementTools
Start-Service MSISCSI 
Set-Service MSISCSI -StartupType Automatic


# create and map virtual disk
New-IscsiVirtualDisk -size:$TargetConfig.VirtualDiskSize -Path:$TargetConfig.VirtualDiskPath
New-ISCSIServerTarget -TargetName:$TargetConfig.TargetName -initiatorIDs:$TargetConfig.TargetPermittedInitiatorID
Add-iscsiVirtualDiskTargetMapping -targetName:$TargetConfig.TargetName -Path:$TargetConfig.VirtualDiskPath
Set-IscsiServerTarget -TargetName:$TargetConfig.TargetName -EnableChap:$true -chap:$TargetConfig.ChapCredential

# check your work: 
Get-IscsiServerTarget
(Get-IscsiServerTarget).Sessions 
(Get-IscsiServerTarget).TargetIQN


# register in ISNS server
Set-WmiInstance -Namespace root\wmi -class WT_iSNSServer -Arguments:@{ServerName="_SNS_SERVER_NAME_.LOCALDOMAIN"} 

# User iSNS server for discovery
Set-WmiInstance -Namespace root\wmi -class WT_iSNSServer -Arguments:@{iSNSServerAddress="_SNS_SERVER_NAME_.LOCALDOMAIN"}

# I don't think this even works tbqhfam
