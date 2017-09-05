# from install media, to connect to shares... 
wpeutil initializenetwork

# start admin cmd
schtasks /create /st:$date /SC:Once /RU:SYSTEM /TR:cmd.exe /tn:pwn

# change pw policy
wmic useraccount where name="Administrator" rename LocalAdmin
net accounts /MinPwLen:0
secedit /export /cfg C:\temp\policy.cfg
(Get-Content C:\Temp\policy.cfg).Replace('\PasswordComplexity = 1\','PasswordComplexity = 0') `
 | Set-Content C:\Temp\policy.cfg
secedit /configure /db C:\Windows\security\new.sdb /cfg C:\temp\policy.cfg /areas SECURITYPOLICY

net user LocalAdmin /Active:yes
net user LocalAdmin * #enter, enter

# cached creds
cmdkey /list 

# system info, app data
wmic product get Name
wmic startup get command

wmic share get Name,Path
NET share

wmic process get name,threadcount,status
wmic process where name="$toKill" terminate

wmic useraccount get Name,SID



wmic volume get name,label,fileSystem,capacity
wmic volume where name="D:\" dismount
mountvol E:\ /p 

# network stff
net view \\ip-addr /all 
net use \\ip-addr /user:comp\administrator *

# domain fuggery
klist purge ; logoff 

nltest --% /dsgetdc:<domain> [ /gc /kdc /pdc /force]

wmic useraccount get name,sid
wmic useraccount where name='username' set PasswordRequired=false
wmic useraccount where name='username' rename 'newusername' 

wmic ntdomain get DomainControllerName,DomainName

wmic computersystem joindomainorworkgroup Name=domainName Username=Admin Password=*

wmic qfe get HotfixID,Description,InstalledOn

wmic startup list

wmic bootconfig list full

mwic recoveros list full

wmic environment where name="NUMBER_OF_PROCESSORS" get caption,variableValue
wmic environment where name="PATH" get username,variablevalue

wmic service where name="WinRM" call StartService
wmic service where state="Running" get name,pathName

wmic process where name="taskmgr.exe" terminate
wmic process where name="taskmgr.exe" getOwner

# stop the bloody xbox crap on W10
(get-service | ? {$_.name -like "*xb*"}).stop() 

wmic product where name="CrapWare" uninstall

# config IPv6 prefix policy
# Set it up:
netsh interface ipv6 set prefixpolicy ::ffff:0:0/96 45 4

#Revert to windows default:
netsh interface ipv6 set prefixpolicy ::ffff:0:0/96 35 4
