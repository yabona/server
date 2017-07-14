$LAcred = "Windows1" | ConvertTo-SecureString -AsPlainText -Force

Uninstall-ADDSDomainController -LocalAdministratorPassword:$LAcred -NoRebootOnCompletion 

Restart-Computer -force

Remove-Computer -UnjoinDomainCredential $DAcred -LocalCredential $LAcred -Restart

netdom resetpwd /server:$pdc /userd:$user /passwordd:* 