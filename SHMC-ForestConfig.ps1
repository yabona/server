<#
well fuck, let's do this
I got a lot of work ahead of me so let's be terse... 
Tested and working on the "MODEL III"

Dont fuck it up agian, just take er ez
#>

<#
shmc\da
hunter2 (jk, its the one we always use)

#>


# setup DC...
function DcPreInstall ($IP,$name) {
    get-netadapter | Rename-NetAdapter -newname DATACENTER
    Rename-Computer -newname $name 

    new-netipaddress -InterfaceAlias DATACENTER -IPAddress $IP -PrefixLength 24 -DefaultGateway 172.30.10.1
    Set-DnsClientServerAddress -InterfaceAlias DATACENTER -ServerAddresses 172.30.10.10

    Install-WindowsFeature AD-Domain-Services -IncludeManagementTools 
}

#####################################
# SHMC-DC1
$name = 'SHMC-DC1'
$IP = '172.30.10.10'

DcPreInstall("SHMC-DC1","172.30.10.10")

# New forest on PDC
Install-ADDSforest -CreateDnsDelegation:$false -DomainName "shmc.ca" -DomainMode Win2012R2 `
    -ForestMode Win2012R2 -SafeModeAdministratorPassword ((Get-Credential).Password) `
    -Force -InstallDns -NoRebootOnCompletion


################################################
# SHMC-DC2
$name = 'SHMC-DC2'
$IP = '172.30.10.11'

DcPreInstall("SHMC-DC2","172.30.10.11")

Add-Computer -DomainName SHMC.ca -Restart

# secondary DC on forest root domain
Install-ADDSDomainController -DomainName shmc.ca -InstallDNS `
    -SafeModeAdministratorPassword ((Get-Credential).Password)


#############################################
# RES-DC1
$name = 'res-dc1'
$IP = '172.30.10.20'

DcPreInstall("RES-DC1","172.30.10.20")

Add-Computer -DomainName SHMC.ca -Restart

# Install child domain... 
Install-ADDSDomain -CreateDnsDelegation -installDNS -DomainMode Win2012R2 `
    -NewDomainName "res" -ParentDomainName "shmc.ca" `
    -SafeModeAdministratorPassword ("Windows1" | ConvertTo-SecureString -AsPlainText -Force) 

#############################################
# SPHM-DC1
$name = 'SPHM-DC1'
$IP = '172.30.10.30'

DcPreInstall("SPHM-DC1","172.30.10.30")

Add-Computer -DomainName SHMC.ca -Restart

Install-ADDSDomain -CreateDnsDelegation -installDNS -DomainMode Win2012R2 `
    -NewDomainName "sphm" -ParentDomainName "shmc.ca" `
    -SafeModeAdministratorPassword ("Windows1" | ConvertTo-SecureString -AsPlainText -Force) 