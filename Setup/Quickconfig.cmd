reg import .\lockscreenConfig.reg
reg import .\executionPolicy.reg
reg import .\hiddenFiles.reg
reg import .\stopServerManager.reg

powershell enable-psremoting -force

echo DON'T USE THIS ON A DC. STOP NOW!!!
pause

net user administrator /active:no
net user LOCALADMIN Windows1 /add
net localgroup Administrators localadmin /add

pause