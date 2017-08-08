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

# DNS
Add-DnsServerConditionalForwarderZone -Name acme.local -MasterServers 10.100.100.10 
Add-DnsServerConditionalForwarderZone -Name east.fanco.local -MasterServers 192.168.101.11
Add-DnsServerConditionalForwarderZone -Name west.fanco.local -MasterServers 192.168.102.10
Add-DnsServerConditionalForwarderZone -name fanco.local -MasterServers 192.168.101.10,192.168.100.10


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

# set DNS forwarder to Router... 
Set-DnsServerForwarder ((Get-NetIPConfiguration).IPv4defaultgateway.nexthop)

# ===================================================================== #
# REPLICATION - pg340

repadmin /replicate staff-dc1 bailey-dc1 cn=schema,cn=configuration,dc=bailey,dc=local

repadmin /kcc

repadmin /syncall /APedq 

# ===================================================================== #
# Sites

$sites = @("Site1","Site2","Site3","Site4")
foreach ($i in $sites) {
    New-ADReplicationSite -Name $i 
}

# -------------------------------------------------------------------- #
#site-links
# hashtables wrapped in arrays. S1/S2 are the sites included in the link.
# uhhhhhhh i dont think this is the right way to do this, but fuck it man
$Site1_Site2 = @{Name = "Site1-Site2"; S1 = 'Site1'; S2 = 'Site2'; Cost = 50; Rep = 120} 
$Site2_Site3 = @{Name = "Site2-Site3"; S1 = 'Site2'; S2 = 'Site3'; Cost = 100; Rep = 180}
$sitelinks = $Site1_Site2,$Site2_Site3

#delet existing...
Get-ADReplicationSiteLink -filter * | Remove-ADReplicationSiteLink -WhatIf
pause; Get-ADReplicationSiteLink -filter * | Remove-ADReplicationSiteLink 

#create them according to hashtables
foreach ($i in 0..($sitelinks.Count -1) ) {
    New-ADReplicationSiteLink -Name $sitelinks[$i].Name `
        -Cost $sitelinks[$i].Cost `
        -ReplicationFrequencyInMinutes $sitelinks[$i].Rep `
        -SitesIncluded $sitelinks[$i].S1,$sitelinks[$i].S2
}

# -------------------------------------------------------------------- #
#site-link bridges
$Site1_Site3 = @{name = "Site1-Site3"; L1 = "Site1-Site2" ; L2 = "Site2-Site3"}
$Site3_Site5 = @{name = "Site3-Site5"; L1 = "Site3-Site4" ; L2 = "Site4-Site5"}
$SiteLinkBridges = $Site1_Site3,$Site3_Site5

foreach ($i in 0..($SiteLinkBridges.Count -1) ) {
    New-ADReplicationSiteLinkBridge -Name $siteLinkBridges[$i].Name `
        -SiteLinksIncluded $siteLinkBridges[$i].L1,$siteLinkBridges[$i].L2 `
        -InterSiteTransportProtocol IP 
}

# -------------------------------------------------------------------- #
# Replication Subnets

$Subnets = @{
    Site1 = 101,102,103;
    Site2 = 104,105,106; 
    Site3 = 107,108,109
}
foreach ($i in $Subnets.Keys) {
    foreach ($j in $subnets.$i) {
        New-AdReplicationSubnet -name "172.16.$j.0/24" -Site $i
    }
}

# -------------------------------------------------------------------- #
# Move DCs and show results 

Get-ADDomainController $dcName | Move-ADDirectoryServer -Site $siteName 

# SHOW
Get-ADReplicationSubnet -filter * | ft Name,Site
get-adreplicationsiteLink -filter * | fl Name,Cost,ReplicationFrequencyInMinutes,SitesIncluded
Get-ADReplicationSiteLinkBridge -filter * | ft Name,SiteLinksIncluded -AutoSize

Gwmi win32_ntdomain
Gwmi win32_

# ====================================================================== #
# AD Forest/External trusts

# literally everything
domain.msc

# external trust. Netdom can't do forest/transitive trusts! WTF?
netdom trust TrustingDomain.local /Domain:TrustedDomain.local /userD:trustedDomain\admin /add /twoway

netdom trust TrustingDomain.local /Domain:TrustedDomain.local /verify 

# and if you fuck up: 
netdom trust TrustingDomain.local /Domain:TrustedDomain.local /Remove

# show trusts
Get-ADTrust -filter * | fl Direction,Distinguishedname,ForestTransitive,Name,ObjectClass,Source,Target
 

# ======================================================================= # 
# client side evidence
whoami /upn
(gwmi win32_computersystem).domain
wmic computersystem get domain,name
gwmi win32_ntdomain

# ===================================================================== #
# DNS config

# on router: 

# on each DC: 
 # set DNS forwarder to router interface: 


# ======================================================================= #
# ADCS configuration

Get-WindowsFeature ADCS* | Install-WindowsFeature -IncludeManagementTools -Restart

Install-AdcsCertificationAuthority -CAType EnterpriseRootCA

# ADCS CA management
certsrv.msc

# Machine certs
certmgr.msc

# OCSP 
ocsp.msc

<#
    server manager post configuration
    
    cersrv > CA1 > properties
    extensions > AIA
    Add
        http://<CaName>/ocsp
    Check both boxes: include AIA and the other one

    certsrv: templates > manage
    OCSP > security > add Auth Users:(enroll,AutoEnroll)

    Templates > new template to issue
     OCSP > add

    Ocsp.msc
    revocation > add
    Nexty next next

#>

# test: 
certutil -pulse


# ===================================snt ===================================  #
# ADFS Config


Install-WindowsFeature ADFS-Federation -IncludeManagementTools -Restart

<# post config and setup...#>
# pg. 366 for Psh 

Add-ADFSClaimsProviderTrust

Add-ADFSRelyingPartyTrust

Update-ADFSCertificate 


setspn -s http/federation.fanco.local fanco\da 
setspn -s http/fanco-fs.fanco.local fanco\da 

"C:\Program Files (x86)\Windows Identity Foundation SDK\v4.0\Samples\Quick Start\Using Managed STS\ClaimsAwareWebAppWithManagedSTS"

https://acme-web.acme.local/ClaimsAwareWebAppWithManagedSTS/

# SHOW
Get-AdfsRelyingPartyTrust | ? {$_.Name -like "*Noah*"} | `
    fl Name,Identifier,MetaDataURL,IssuanceTransformRules,RequestSigningCertificate

Get-AdfsClaimsProviderTrust | ? {$_.Name -like "*Bailey*"} | `
    fl Name,Identifier,MetaDataURL,IssuanceTransformRules,TokenSigningCertificates


# ======================================================================= #

Install-WindowsFeature ADRMS -IncludeManagementTools -Restart


Install-AdfsFarm `
-CertificateThumbprint:"5151E727422AA744B7EE15EED49EE8467511C2B6" `
-FederationServiceDisplayName:"Fanco Org" `
-FederationServiceName:"federation.fanco.local" `
-ServiceAccountCredential:$serviceAccountCredential

# create service account: 
ADRMS-SVC

<#
  Problem: user has not been authenticated
  It means: CA is not configured correctly
    OSCP is not configured properly?
    check out pg.424 later when you're more sane
    443 for verifiying SPNs are correct? 
#>

# ========================================================================== # 

# export ca cert
certutil -ca.cert C:\fanco_ca.cer 

# import root ca cert 
 certutil –f –dspublish “Z:\file.cer” RootCA


# =========================================================================== # 
# make a public folder

icacls /grant:r *S-1-5-11:(CI)(OI)(M)



 # ============================================================================= #

 whoami /groups
