# shutdown all nodes

$servers = (Get-adcomputer -filter {name -notlike "*dc*"} ).DnsHostName

ForEach ($i in $servers) {
    Invoke-Command -ComputerName $i -ScriptBlock {Stop-Computer -force} -AsJob
}  get-job | Wait-Job

Stop-Computer