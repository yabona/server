Get-VMSwitch | ft -AutoSize Name,AllowManagementOS,switchType,ID

Get-vm | % { Get-VMNetworkAdapter -VMName $_.VMName | ft -AutoSize Vmname,SwitchName,IPaddresses }

Get-IscsiConnection | fl * 