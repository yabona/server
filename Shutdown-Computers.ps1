$DAcred = Get-Credential -UserName shmc\da -Message "Shutdown all servers"
$ws = $env:COMPUTERNAME
foreach ($i in (Get-ADForest).Domains) {
    foreach ($j in (Get-ADComputer -server $i -filter {Enabled -eq $true -and Name -ne $ws }).dnsHostName ) {
        if (Test-NetConnection $j -ErrorAction SilentlyContinue) {
            Write-Verbose "Shutting down $j`:" -Verbose
            Stop-Computer -ComputerName $j -Verbose -AsJob -Force -Credential $DAcred
        }
    }
}

get-job  | Wait-Job