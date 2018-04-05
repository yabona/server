# Oauth 

# SFB Replication
invoke-csmanagementstorereplication 

# EMS config
Get-ClientAccessServer | Set-ClientAccessServer -autodiscoverserviceinternalURI "https://autodiscover.s0717158.com/autodiscover/autodiscover.xml"
Get-ClientAccessServer | Select Name,AutoDiscoverServiceInternalUri | fl *

Get-WebServicesVirtualDirectory | Set-WebServicesVirtualDirectory –Identity “EXCH\EWS (Default WebSite)” –InternalUrl "https://autodiscover.s0717158.com/ews/exchange.asmx"

Set-OABVirtualDirectory –Identity “EXCH\OAB (Default Web Site)” –InternalUrl "https://autodiscover.s0717158.com/oab"

Set-UMVirtualDirectory –Identity “EXCH\unifiedmessaging (DefaultWeb Site)” –InternalURL "https://autodiscover.s0717158.com/unifiedmessaging/service.asmx"

# Connect to lync
'C:\Program Files\Microsoft\Exchange Server\V15\Scripts\'

.\Configure-EnterprisePartnerApplication.ps1  –AuthMetaDataUrl "https://skype-pool1.s0717158.com/metadata/json/1" –ApplicationType Lync

# SFB server 
Set-CsOAuthConfiguration –ExchangeAutodiscoverUrl "https://autodiscover.s0717158.com/autodiscover/autodiscover.svc"

New-CsOAuthServer –Identity “Exchange” –Metadataurl “https://autodiscover.s0717158.com/autodiscover/metadata/json/1”

New-CsPartnerApplication –Identity Exchange –ApplicationTrustLevel Full -MetadataUrl “https://autodiscover.s0717158.com/autodiscover/metadata/json/1”

Get-CsOAuthConfiguration
Get-CsOAuthServer
Get-CsPartnerApplication

Test-CsExStorageConnectivity –SipUri sip:n@s0717158.com -verbose

# Integration part II

# configure OWA cpresence 
Get-OWAVirtualDirectory | Set-OwaVirtualDirectory -instantmessagingenabled $True -instantMessagingType OCS 
Set-OWAMailboxPolicy -identity "Default" -InstantMessagingEnabled $True -InstantMessagingType OCS

# Add to web.config 
<#
    <add key=”IMCertificateThumbprint” value=”51A79C30EBF7F99137D453488D62A12EA9859520”/>
    <add key=”IMServerName” value=”Skype-Pool1.s0717158.com”/>

51A79C30EBF7F99137D453488D62A12EA9859520
 >>  get-exchangecertificate | select Subject,DNSnameList,thumbprint | fl
   > the autodiscover certificate 
#>

# On skype server: 
$CSsite = (Get-CSsite).siteID
New-CSTrustedApplicationPool -Identity autodiscover.s0717158.com -registrar Skype-pool1.s0717158.com -site:$CSsite -requiresReplication $False 
New-CSTrustedApplication -ApplicationID "OutlookWebApp" -TrustedApplicationPoolFQDN autodiscover.s0717158.com -Port 5199 

# DO ITTTT
Enable-CSTopology