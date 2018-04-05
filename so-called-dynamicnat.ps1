get-netnat | Remove-NetNat

Set-NetIPInterface -InterfaceAlias EXTERNAL -Dhcp Enabled
ipconfig /renew 

$ExternalAddress = get-netipaddress -interfacealias external -AddressFamily IPv4

New-NetNat -name EXT-NAT -ExternalIPInterfaceAddressPrefix "$($externalAddress.ipaddress)/$($ExternalAddress.PrefixLength)"
New-netnatexternaladdress -natname EXT-NAT -ipaddress $ExternalAddress.ipaddress 