# ====================================================================== #
# Config 
Get-Netadapter Ethernet* | Rename-Netadapter -NewName [PROD]
New-NetIpAddress -interfacealias [PROD] -ipaddress [ip] -prefixlength [24] -defaultGateway [router]
Set-DnsClientServerAddress -interfacealias [PROD] -ServerAddress 192.168.200.10 
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False

Rename-Computer -NewName $compName -Restart 
Add-Computer -DomainName ad.elgoog.com -OUPath "ou=Servers,dc=ad,dc=elgoog,dc=com" -Credential (Get-Credential) -Restart

# ====================================================================== #
# DC
install-windowsfeature ad-domian-services
Install-ADDSForest -CreateDNSDelegation:$false -DomainName "<domian.com>" -DomainMode "Win2012" -ForestMode "Win2012" -InstallDNS:$True -SafeModeAdministratorPassword ((Get-Credential).Password) -Force:$true

# ====================================================================== #
# routing
Install-WindowsFeature Routing -IncludeManagementTools
Get-NetAdapter | Set-NetIpInterface -Forwarding Enabled 

# ====================================================================== #	
# NLB
New-NlbCluster -interfacename [PROD] -clusterPrimaryIP [IP] -clusterName [Intranet] -operationMode Multicast
Get-NlnClusterPortRule | Remove-NlbClusterPortRule
Add-NlbClusterPortRule -protocol tcp -startport 80 -endport 80 -interfacename PROD 
Add-NlbClusterNode -interfaceName PROD -newNodeName WEB2 -newNodeInterface PROD 
	
Get-NlbCluster
Get-NlbClusterNode 

# ====================================================================== #
# ISCSI Config: 
Install-WindowsFeature fs-iscsitarget-server -IncludeManagementTools

New-IscsiVirtualDisk -SizeBytes 10GB -path C:\iSCSIVirtualDisks\TEST2.vhdx
New-IscsiServerTarget -TargetName TEST2 -InitiatorIds IPaddress:10.11.12.13,IPaddress:172.30.20.10,etc 
    #Include cluster IP, all nodes' interfaces..
Add-IscsiVirtualDiskTargetMapping -TargetName TEST2 -Path C:\iSCSIVirtualDisks\TEST2.vhdx

# ====================================================================== #
# auth
$password = ConvertTo-SecureString -String "chapchapchap" -AsPlainText -force
$chap = New-Object -TypeName PScredential ("iscsi",$password)
Set-IscsiServerTarget -TargetName TEST2 -EnableChap:$true -chap $chap

Get-IscsiServerTarget | fl *
Get-IscsiSession | fl *

# ====================================================================== #
# Clustering
install-windowsfeature Hyper-V,Failover-Clustering -includemanagementTools
new-cluster -name [clustername] -node [node1],[node2] -staticAddress [192.168.200.30
	
Set-ClusterQuorum -fileshareWitness 
	
Get-Disk [1] | Add-ClusterDisk 
Get-ClusterAvailableDisk | Add-ClusterSharedDisk 

Add-ClusterSharedVolume -Name "Cluster Disk 1"

mkdir \ClusterStorage\Volume1\Hyper-V
mkdir \ClusterStorage\Volume1\Hyper-V\vmNoah_1
mkdir \ClusterStorage\Volume1\Hyper-V\vmNoah_2 

New-VMSwitch -Name ext_PROD -AllowManagementOS:$true -NetAdapterName PROD 
New-VHD -Dynamic -Path C:\ClusterStorage\Volume1\Hyper-V\vmNoah_1\vmNoah_1.vhdx -SizeBytes 20GB
New-VM -name vmNoah_1 -Generation 1 -MemoryStartupBytes 512MB -SwitchName ext_PROD `
	-Path C:\ClusterStorage\Volume1\Hyper-V\ -VHDPath C:\ClusterStorage\Volume1\Hyper-V\vmNoah_1\vmNoah_1.vhdx 
Set-VMMemory -VMName vmNoah_1 -DynamicMemoryEnabled:$true -MaximumBytes 1GB 

get-vm | fl *

Add-ClusterVirtualMachineRole -VMname vm-name 
Add-ClusterScaleOutFileServerRole -name WebApp
	
test-cluster 
Get-ClusterNetwork
cluadmin.msc

# ====================================================================== #
# iscsicpl
connect-advanced-CHAP
Initialize-format-etc. 
start-service msiscsi
sc --% config msiscsi start=auto

iscsicli addtarget iqn..... 
diskpart
  sel disk 1
  attrib disk clear readonly
  create partition primary
  format quick fs=ntfs label="csv"

# ====================================================================== #
#branchcache
Install-WindowsFeature fs-Branchcache,branchcache -IncludeManagementTools
# Edit DomainControllers GPO: 
    # computerConfig\AdminTemplates\Network\LanManServer > Hash Publication (ALL)
GPUPDATE /FORCE 
# create GPO to apply to clients
    # ComputerConfig\Admin Templates\Network\Branchcache 
        #> turn on branchecache [ENABLE]
        #> Disitributed Mode [ENABLE]
    # computerConfig\Security\Wf\Inbound rule > ContentRetrieval, PeerDiscovery
mkdir C:\BranchCache
net share BC_Share=C:\BranchCache /GRANT:Everyone,FULL /CACHE:BranchCache

# ====================================================================== #
# dynamic Access
Install-WindowsFeature fs-resource-manager -IncludeManagementTools 
# Edit DomainControllers policy to support claims
    # CompConfig\Policies\AdminTemplates\System\KDC
        #> KDC Support for Claims... [Supported]

    # Set Confidentilaity resource ENABLE
    $confid = Get-ADResourceProperty -filter {DisplayName -eq "Confidentiality"} 
    Set-ADResourceProperty -Identity:$confid -Enabled:$true

    # Create resoucePropertyList
    New-ADResourcePropertyList -Name Exec_RPL -ProtectedFromAccidentalDeletion:$false 
    $PropList = Get-ADResourcePropertyList -filter {Name -eq "Exec_RPL"}
    Add-ADResourcePropertyListMember -Identity $propList -Members $confid 

    #Create template ACL
    new-item -Type file -name acl.txt
    icacls --% acl.txt /reset
    icacls --% acl.txt /grant:r ad\Exec:(M) /grant:r system:(F) /inheritance:r /t

    # Create Central Access Rule with template as CURRENT perms
    $acl = (get-acl acl.txt).Sddl 
    New-ADCentralAccessRule -CurrentAcl:$acl `
        -Name:"EXEC_CARule" `
        -ResourceCondition:"(@RESOURCE.Confidentiality_MS == 3000)"

    #Create Policy and Add Member(s)
    New-ADCentralAccessPolicy -name Exec_CAPolicy 
    Add-ADCentralAccessPolicyMember -Identity Exec_CAPolicy -Members Exec_CARule

    #Show-Commands
    Get-ADResourcePropertyList -filter *
    Get-ADCentralAccessRule -filter *
    Get-ADCentralAccessPolicy -filter *

# GPMC:DefaultDomain
    # Comp/Policies/Windows/Sec/FileSystem/CentralAccessPolicy
    # R.Click > Manage > Add
# FSRM 
    # Create new rule
    # Content classifier: regex for content search
    # Eval: Re-Evaluate, Aggregate
# Set Everyone:Modify on NTFS perms

# ====================================================================== #
# features-on-demand
Get-WindowsFeature | ? { !($_.InstallState -eq "Installed") } | Uninstall-WindowsFeature -Remove

# ====================================================================== #