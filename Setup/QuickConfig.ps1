& reg import $PSScriptRoot\lockscreenConfig.reg
& reg import $PSScriptRoot\executionPolicy.reg
& reg import $PSScriptRoot\hiddenFiles.reg
& reg import $PSScriptRoot\stopServerManager.reg

Enable-PSRemoting -force

echo "DON'T USE THIS ON A DC. STOP NOW!!!"
pause

#and because I will fuck up at some point in the future
if ($env:COMPUTERNAME -like "*DC*")
    {break}
else {
    Write-Verbose "disable built-in admin, create new one"
    net user administrator /active:no
    net user LOCALADMIN Windows1 /add
    net localgroup Administrators localadmin /add
}pause

