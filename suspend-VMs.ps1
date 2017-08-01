
Set-Location S:\VirtualMachines\ 

foreach ($i in (gci).name) {vmrun suspend $i\$i.vmx}