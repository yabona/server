$Server03 = '10.1.3.100'
$Server69 = '10.1.69.100'
$VCSA = '10.1.3.10'

$ServerCred = new-object pscredential ("root", $("Windows1" | convertto-securestring -asplaintext -force))
$VCSACred = new-object pscredential ("Administrator@s3.local", $("CharlieHalt66!" | convertto-securestring -asplaintext -force))
$GuestCred = new-object pscredential ("Administrator", $("Windows1" | convertto-securestring -AsPlainText -force))

$AppliancePath = '.\VCSA-3.ova'


#...........................................................................


function DeployVCSA ($AppliancePath) {
    
    # Deploy VCSA to server: 
    Connect-ViServer -server $Server69 -credential:$ServerCred 
    $Datastore = Get-Datastore Datastore1

    Import-VApp -source $AppliancePath -VMHost:$Server69 -Datastore:$dataStore -name "VCSA-S3" -DiskStorageFormat Thin 
    # Wait for this to complete...... 
}



#...........................................................................

Connect-VIServer -server:$VCSA -credential:$VCSACred 
$Server = Get-VMHost  
$DataStore = Get-Datastore "DataStore-S3"

function DeployGuests ([int32]$Guests) {
    # Deploy templates to VMhost
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
}


#...........................................................................


function InjectCpuBusy {
    # Copy script to VMs 
    1..6 | % { 
        Copy-VMGuestFile `
            -source "C:\scripts\CpuBusy.vbs" `
            -Destination "C:\" `
            -VM "W16-S3-$_" `
            -LocalToGuest `
            -GuestCredential:$GuestCred
    }
}

function StartCpuBusy () {
    # Kick off CPUbusy on all VMs 
    1..6 | % { 
        Invoke-VMScript `
            -scriptText "wscript //B C:\cpuBusy.vbs" `
            -VM "W16-S3-$_" `
            -GuestCredential:$GuestCred `
            -runasync 
    }
}


#...........................................................................

function StopCpuBusy () {
    # kill cpubusy processes on all VMs
    1..6 | % { 
        Invoke-VMScript `
            -scriptText "tskill wscript" `
            -VM "W16-S3-$_" `
            -GuestCredential:$GuestCred `
            -runasync 
    }
}
