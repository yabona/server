# shutdown all nodes

$servers = @("ROUTER","NLB1","NLB2","FoC1","FoC2")

ForEach ($i in $servers) {
    Invoke-Command -ComputerName $i -ScriptBlock {Stop-Computer -force} -AsJob
}

get-job | Wait-Job

Stop-Computer