<#
    Install sql server
    set sql server to logon with domain cred
    Install NET3FX
    Install ADK for Windows 10
#>

$svc_account = 'BORK\SQLSVC'
$svc_password = 'Windows1'
$svc = gwmi win32_service -filter "name='MSSQLSERVER'"
$svc.change($null,$null,$null,$null,$null,$null,$svc_account,$svc_password)
Restart-Service MSSQLSERVER

#schema extensions
D:\smsSetup\BIN\i386\ExtADSch.exe 

New-ADObject -Type Container -Name "System Management" -Path:"CN=System,$((Get-AdDomain).DistinguishedName)" -ProtectedFromAccidentalDeletion:$True -PassThru -Confirm

<#
    Set permissions: 
        System Management container object
        FULL CONTROL
        SCCM$
        This object and descendant objects
#>


$Features = @('wds','rdc','BITS','Web-Server','UpdateServices','Web-Wmi')

foreach ($i in $Features) {
    Install-windowsfeature $i -includeManagementTools
}

<#
    Run through WSUS postinstall and sync (blahhh)
#>

<#
    It's okay to have: 
        Memory allocation & usage
        Verify site permissions 
#>