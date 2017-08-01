
Set-Location S:\VirtualMachines\ 

foreach($i in (gci).name){$i; vmrun suspend $i\$i.vmx}

###################################################

$subdir = "ChallengeLab3"

$subdir = Read-Host "subfolder:(challengeLab3)"

Set-Location S:\VirtualMachines\$subdir

foreach($i in (gci).name){$i; vmrun start $i\$i.vmx}