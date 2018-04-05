<#
 # FUCK BEST PRACTICES
 # yeah, I know, there are serious security flaws with this script. Fuck it. 
 # Yeah... I fucking know. But I'm too lazy of a dickhole to fix it. 
 #>

param (
    [switch]$localBackup = $true, 
    [switch]$remoteBackup = $false
)

# only ask for NAS pw when using remote backup...
if ($remoteBackup) {$password = Read-Host -AsSecureString "Password for NAS?"}

# Local incremental backup: 
if ($localBackup) {
    Write-Verbose "Starting local backup..." -Verbose

    wbadmin start backup -include:S: -backuptarget:D: -vssCopy -quiet

    Write-Verbose "Backup complete...."  -Verbose
}

if ($remoteBackup) {
    Write-Verbose "Preparing network backup..." -Verbose

    wbadmin start backup -include:S: -backuptarget:"\\10.11.12.251\backups\VMWARE-BACKUP" -user:StorageClient `
        -password:$([Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.interopServices.Marshal]::SecureStringToBSTR($password)))`
        -vssCopy -quiet

    Write-verbose "Network backup complete..." -Verbose
}