# how to insta-DDOS your domain controllers!
# Please never do this IRL!

# especially this: 
$Computers = (Get-adcomputer -filter *).name
# it's so wrong and so right
$domainControllers = $Computers.Where({$_ -like "*DC*"})

# Replicate and sync all DCs in forest:  
foreach ($i in $domainControllers) {
    repadmin /kcc $i
    repadmin /syncall $i /APed
}

# Update all GPs. 
foreach ($i in $Computers) {
    # test connection first...
    if (Test-NetConnection $i -ErrorAction SilentlyContinue) {
        
        # update GP immediately on all responsive machines: 
        Write-Verbose "Updating policy on $i`:" -Verbose
        Invoke-GPUpdate -Computer $i -Force -RandomDelayInMinutes 0 -Verbose -AsJob
    }
}

# wait for jobs to complete
Get-Job | Wait-Job 
Get-job | Remove-Job

# m-m-m-MONEYSHOT
repadmin /replsummary 
Write-verbose "Finished refreshing GP settings!" -Verbose
Write-Verbose "Finished replicating all DCs! " -Verbose
