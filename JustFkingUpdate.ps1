# how to insta-DDOS your domain controllers!
# Please never do this IRL!

foreach ($i in (Get-ADForest).Domains) {
    (Get-ADComputer -server $i -filter {Name -like "*DC*" -and Enabled -eq $True } ).Name | % {
        Write-Verbose $_ -Verbose
        repadmin /kcc $_
        repadmin /syncall $_ /APed
    }
}

foreach ($i in (Get-ADForest).Domains) {
    foreach ($j in (Get-ADComputer -server $i -filter {Enabled -eq $true} ).dnsHostName ) {
        if (Test-NetConnection $j -ErrorAction SilentlyContinue) {
            Write-Verbose "Updating policy on $j`:" -Verbose
            Invoke-GPUpdate -Computer $j -Force -RandomDelayInMinutes 0 -Verbose -AsJob
        }
    }
}

Get-Job | Wait-Job 
Get-job | Remove-Job
repadmin /replsummary 
Write-verbose "Finished refreshing GP settings!" -Verbose
Write-Verbose "Finished replicating all DCs! " -Verbose

