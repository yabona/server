# Shutdown all VMs: 
Get-ADComputer -filter * | Stop-Computer -force -asjob -computerName $_.dnsHostName

# Shutdown only member-servers, no DCs:
$serverList = (Get-ADComputer -filter {name -notlike "*DC*"} ).dnsHostName
foreach ($i in $serverList) { Stop-Computer -ComputerName $i -AsJob -force }
Get-Job | Wait-Job ; Stop-Computer
