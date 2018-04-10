$ServerIP = 10.1.3.10 
$VICRED = (Get-Credential -UserName "Administrator@s3.local")
Connect-VIServer -server:$ServerIP -credential:$VICRED 



# Deploy templates to VMhost
$Server = Get-VMHost  
$DataStore = Get-Datastore "DataStore-S3"
1..6 | % { 
    Import-VApp `
        -Source C:\OVA\Win2016-x64-core.ova `
        -Datastore:$dataStore `
        -VMHost:$server `
        -Name "W16-S3-$_" `
        -storageFormat Thin 
}

# Start all the VMs
Get-VM W16-S3-* | Start-VM  


$GuestCred = (Get-Credential)

# Copy script to VMs 
1..6 | % { 
    Copy-VMGuestFile `
        -source "C:\scripts\CpuBusy.vbs" `
        -Destination "C:\" `
        -VM "W16-S3-$_" `
        -LocalToGuest `
        -GuestCredential:$GuestCred
}

# Kick off CPUbusy on all VMs 
1..6 | % { 
    Invoke-VMScript `
        -scriptText "wscript //B C:\cpuBusy.vbs" `
        -VM "W16-S3-$_" `
        -GuestCredential:$GuestCred `
        -runasync 
}

# kill cpubusy processes on all VMs
1..6 | % { 
    Invoke-VMScript `
        -scriptText "tskill wscript" `
        -VM "W16-S3-$_" `
        -GuestCredential:$GuestCred `
        -runasync 
}

Invoke-VMScript -scriptText "wscript //B C:\cpubusy.vbs" -vm W16-S3-2 -GuestCredential:$GuestCred -runasync
Invoke-VMScript -scriptText "taskkill /IM:wscript" -vm W16-S3-2 -GuestCredential:$GuestCred -runasync

