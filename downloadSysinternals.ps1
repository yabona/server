$sysInternals = iwr https://live.sysinternals.com -usebasicparsing
$sysInternals.links | %{iwr "https://live.sysinternals.com/$($_.href.substring(1))" `
	-outFile .\$($_.href.substring(1)) -usebasicparsing}