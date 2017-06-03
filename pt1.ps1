# ====================================================================== #
# Config 
Get-Netadapter Ethernet* | Rename-Netadapter -NewName [PROD]
New-NetIpAddress -interfacealias [PROD] -ipaddress [ip] -prefixlength [24] -defaultGateway [router]
Set-DnsClientServerAddress -interfacealias [PROD] -ServerAddress 192.168.200.10 
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False

Rename-Computer -NewName $compName -Restart 
Add-Computer -DomainName ad.elgoog.com -OUPath "ou=Servers,dc=ad,dc=elgoog,dc=com" `
    -Credential (Get-Credential) -Restart

# ====================================================================== #
# DC
install-windowsfeature ad-domian-services
Install-ADDSForest -CreateDNSDelegation:$false -DomainName "<domian.com>" `
    -DomainMode "Win2012" -ForestMode "Win2012" -InstallDNS:$True `
    -SafeModeAdministratorPassword ((Get-Credential).Password) -Force:$true

# ====================================================================== #
# routing
Install-WindowsFeature Routing -IncludeManagementTools
Get-NetAdapter | Set-NetIpInterface -Forwarding Enabled 

# ====================================================================== #	
# NLB
New-NlbCluster -interfacename [PROD] -clusterPrimaryIP [IP] `
    -clusterName [Intranet] -operationMode Multicast
Get-NlnClusterPortRule | Remove-NlbClusterPortRule
Add-NlbClusterPortRule -protocol tcp -startport 80 -endport 80 -interfacename PROD 
Add-NlbClusterNode -interfaceName PROD -newNodeName WEB2 -newNodeInterface PROD 
	
Get-NlbCluster
Get-NlbClusterNode 

# ====================================================================== #
# ISCSI Config: 
Install-WindowsFeature fs-iscsitarget-server -IncludeManagementTools

New-IscsiVirtualDisk -SizeBytes 10GB -path C:\iSCSIVirtualDisks\TEST2.vhdx
New-IscsiServerTarget -TargetName TEST2 -InitiatorIds IPaddress:10.11.12.13,etc 
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
	
Set-ClusterQuorum -fileshareWitness \\dc\quorum
	
Get-Disk [1] | Add-ClusterDisk 
Get-ClusterAvailableDisk | Add-ClusterSharedDisk 

Add-ClusterSharedVolume -Name "Cluster Disk 1"

mkdir \ClusterStorage\Volume1\Hyper-V
mkdir \ClusterStorage\Volume1\Hyper-V\vm_1
mkdir \ClusterStorage\Volume1\Hyper-V\vm_2 

New-VMSwitch -Name ext_PROD -AllowManagementOS:$true -NetAdapterName PROD 
New-VHD -Dynamic -Path C:\ClusterStorage\Volume1\Hyper-V\vm_1\vm_1.vhdx -SizeBytes 20GB
New-VM -name vm_1 -Generation 1 -MemoryStartupBytes 512MB -SwitchName ext_PROD `
	-Path C:\ClusterStorage\Volume1\Hyper-V\ -VHDPath C:\ClusterStorage\Volume1\Hyper-V\vm_1\vmN_1.vhdx 
Set-VMMemory -VMName vm_1 -DynamicMemoryEnabled:$true -MaximumBytes 1GB 

get-vm | fl *


Get-ClusterNode | % {get-vm -computername $_.Name} | fl ComputerName,VMName

# ad config:
Import-Module ActiveDirectory
$clusterSID = (Get-adcomputer fcc).sid.value
dsacls 'ou=foc,ou=infra,dc=ad,dc=elgoog,dc=com' /G $clusterSID`:DC
dsacls 'ou=foc,ou=infra,dc=ad,dc=elgoog,dc=com' /G $clusterSID`:CC

# scaleout
Install-WindowsFeature FS-File-Server -IncludeManagementTools
Add-ClusterScaleOutFileServerRole -name WebApp
mkdir C:\ClusterStorage\Volume1\WebApp
# webserver config
Install-WindowsFeature Web-Server -IncludeManagementTools
Set-ItemProperty 'IIS:\Sites\Default Web Site' -name PhysicalPath -Value \\webapp\Site
Set-ItemProperty 'IIS:\Sites\Default Web Site' -name userName -value "Administrator"
Set-ItemProperty 'IIS:\Sites\Default Web Site' -name Password -value "Windows1"

Add-ClusterVirtualMachineRole -VMname vm-name 
Move-ClusterVirtualMachineRole -Name vmN_1 -Node fc1

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
icacls --% acl.txt /grant:r ad\Exec:(M) /grant:r system:(F) /inheritance:r 

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

set-acl C:\$share -CentralAccessPolicy IT_CApolicy -AclObject (Get-Acl $share)
icacls --% C:\Share /grant:r *s-1-1-0:(CI)(OI)(M) /inheritance:r
icacls --% C:\Share /grant:r *s-1-5-18:(CI)(OI)(F) 

# ====================================================================== #
# features-on-demand
Get-WindowsFeature | ? { ($_.Installed -eq $false) } | Uninstall-WindowsFeature -Remove

# ====================================================================== #

<#

/Td6WFoAAAFpIt42AgAhAQAAAAA3J5fW4AxiBD9dABBrh0X7KZxyvHRcmGscEcFp
6PB+d/0ZDPJPF8EB+XfiotSrbaz93z8+gO7M6yH3CYsYdsHm6/IYZ47ju5z0o8Fk
xTL852SM3tPu6eh8HT7lXPPfwronchnIa2N4Yls4JxRKKsFXgEpHoOaJmAP6W3j6
7xzhW30WHWIHylC58bkDWfSqYKkjzVa9RMt6izUZ73lFbXbNGwM7s1bW6IXjriYs
MP8i2oDJBfyqQJvFgiq/xVONhs3Bbnpi2CHgSIbXvxzCefmFgnsEQuiOY+5G5MGe
Dr+hFkgqclEAVgAmdmwMgwBprJ/9kPZZhdBcN1jqym9WyCFhM6Fc0Sr5ftUWIdzi
OHuS2apaazY1KY9diTvadj6JlRKltk79/21HA4n7njYs5xa1FBNSZlABt9n8yDBT
BEeKJF8ycqQWJ2x/HJSrUfRywqS//L5yx1u0kqYw6K/JtRwLyeVlftu9BguMJajE
mQwsaxWIfxXsOsAemUEl1BQCpMN7+Onvyg2LnRC/bbFGOJFB0AqN+nHamsfKmfz2
jEJXdNu3+w0lTxjHQZ9y/swnD/yqQ2aE7nOUhWgMwML+n81ZZhJrFxjfODeUfQXn
pscgB63FTeSyaX6EnkUQExYV+6PPuoXGPm8KOHsSySse3UddiGjLUoNLloCC3nNs
121AC/z6371xmlasJkThk8hwlK1NUx/YR8RRmrRzzAFPxDk/rPfaa7ZsNFN+Yp8c
aptPm5sz6KwYCGhfSDx6osB3B4E3C3hFVN93bp8XzNrhiMwniIlhe3ro0jLB0BIY
f85RbqQgZatHkkKvmzjdnaOrv4K/uYOpBya5f/AuSFZrgc54eu20g2ZXXwVQlVWb
0rPZK3/ddyvvS6xvj2qiG0hXUPlyptrwpeBfVdkSrmuKnuVuLHLdRqkm5yNrWBFy
/YlMba0/8WzxTx9bMZm1sFOWRL9ccb8qX2E2ZCTVeKigjjnTWTQZv5Gb+biXhPre
BgcC5Q1LJaIxDsJyYowCWHi07co4nda09O3WiW1XAupClJZXQfSYx79//A8Xr8JI
f87k0HhEvb8H2Perv2vIy9ULp9tI5uQe1TmdfsqIDlxpkNlXxWp+EScjT70cpZDa
lu/HNkuDi7H7ylCq1buTBA+kxKlslSmyXcJR8DSmqDRBdH7jJVsmBoEwyMLsb8A1
UUybp0ODO49qIIk5wfURt53YhBSKNEIcDGqJ6CvLTO7IqTXl5UbdwTHjPapHFHmo
ehvca/mKJjyc0YjDXUwEW9J4KkZk5f1No3IojCb66hvxtgMk5ufkaXneSl6uPYNM
Z11/45HXctlCzgCHNNLovux3H5/8SV1TrR3EWcuDMWkLHA1Mg5Qifx0/txSopspI
xFQuLS5qR/KtJEDRVGbAAyiQRQGuTi4ShMnY1hdosjVeQY3V3fNIZ3eqDJVYLs1P
YlxxH0NfcTpwCgWNuEsAADmV3YEAAdcI4xgAAJWv4So+MA2LAgAAAAABWVo=

.txt.xz.txt
 #>

