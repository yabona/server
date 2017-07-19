# how to insta-DDOS your domain controllers!
# Please never do this IRL!

# especially this. This is bad. 
$Computers = (Get-adcomputer -filter *).name

foreach ($i in $Computers) {
    if (Test-NetConnection $i -ErrorAction SilentlyContinue) {
        Write-Verbose "Updating policy on $i`:" -Verbose
        Invoke-GPUpdate -Computer $i -force -target Computer -Verbose -AsJob
    }
}

# wait for jobs to complete
Get-Job | Wait-Job | Remove-Job
# this feels wrong but so right

Write-verbose "Finished refreshing GP settings!" -Verbose
