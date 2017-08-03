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
# REPLICATION

repadmin /replicate staff-dc1 bailey-dc1 cn=schema,cn=configuration,dc=bailey,dc=local

repadmin /kcc

repadmin /syncall /APedq 

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
Get-ADTrust -filter * | fl Direction,Distinguishedname,ForestTransitive,Name,ObjectClass,Source,Target

# show site links
Get-ADReplicationSiteLink -filter * | ft Name,ReplicationFrequencyInMinutes,Cost -AutoSize

# Don't delete DFSN (default-first-site-name)
# bad things happen. Really. 

# ======================================================================= # 
# client side evidence
whoami /upn
(gwmi win32_computersystem).domain
wmic computersystem get domain,name
gwmi win32_ntdomain

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



# ======================================================================  #

Install-WindowsFeature ADFS-Federation -IncludeManagementTools -Restart

<# post config and setup...#>

# install WIDF and stuff: 

Install-WindowsFeature 

# ======================================================================= #

Install-WindowsFeature ADRMS -IncludeManagementTools -Restart


Install-AdfsFarm `
-CertificateThumbprint:"5151E727422AA744B7EE15EED49EE8467511C2B6" `
-FederationServiceDisplayName:"Fanco Org" `
-FederationServiceName:"federation.fanco.local" `
-ServiceAccountCredential:$serviceAccountCredential

setspn -s http/federation.fanco.local fanco\da 
setspn -s http/fanco-fs.fanco.local fanco\da 


Install-WindowsFeature windows-identity-foundation,`
    Net-framework-features,`
    net-framework-core,`
    NET-Framework-45-ASPNET `
    -Source D:\sources\sxs

"C:\Program Files (x86)\Windows Identity Foundation SDK\v4.0\Samples\Quick Start\Using Managed STS\ClaimsAwareWebAppWithManagedSTS"

https://acme-web.acme.local/ClaimsAwareWebAppWithManagedSTS/

# ========================================================================== # 

# export ca cert
certutil -ca.cert C:\fanco_ca.cer 

# import root ca cert 
 certutil –f –dspublish “Z:\file.cer” RootCA


# =========================================================================== # 
# make a public folder

icacls /grant:r S-1-5-11:(CI)(OI)(M)



 # ============================================================================= #

 <#

 where im at: 

 ADFS 
 creating the website for ClaimsAwareWebAppWithManagedSTS 

    distributing the truted root CA to MS's
    what the fuck seriously
    > DID IT. See above. 
 have done: 
    export from certmgr to shared folder, import on other domain
    export from cmdline, import with certmgr





 #>