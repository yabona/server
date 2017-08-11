# daves faves

wpeutil initializenetwork

schtasks /create /st:$date /SC:Once /RU:SYSTEM /TR:cmd.exe /tn:pwn

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

wmic product get Name
wmic startup get command

wmic share get Name,Path
NET share

wmic process get name,threadcount,status
wmic process where name="$toKill" terminate

wmic useraccount get Name,SID
wmic ntdomain get DomainControllerName,DomainName

wmic volume get name,label,fileSystem,capacity
wmic volume where name="D:\" dismount
mountvol E:\ /p 

# network stff
net view \\ip-addr /all 
net use \\ip-addr /user:comp\administrator *

# domain fuggery
klist purge ; logoff 

nltest --% /dsgetdc:<domain> [ /gc /kdc /pdc /force]


# config IPv6 prefix policy
# Set it up:
netsh interface ipv6 set prefixpolicy ::ffff:0:0/96 45 4

#Revert to windows default:
netsh interface ipv6 set prefixpolicy ::ffff:0:0/96 35 4