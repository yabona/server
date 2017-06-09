# ====================================================================== #
# router configuration

Rename-Computer -newname CiscoTM
Get-Netadapter Ethernet* | Rename-Netadapter -NewName PROD
New-NetIpAddress -interfacealias PROD -ipaddress 192.168.100.254 -prefixlength 24 
Set-DnsClientServerAddress -interfacealias PROD -ServerAddress 192.168.100.10 
# add second network interface
Get-Netadapter Ethernet* | Rename-Netadapter -NewName REMOTE
New-NetIpAddress -interfacealias PROD -ipaddress 192.168.200.254 -prefixlength 24
#configure routing
Install-WindowsFeature Routing -IncludeManagementTools
Get-NetAdapter | Set-NetIpInterface -Forwarding Enabled 
Restart-Computer 