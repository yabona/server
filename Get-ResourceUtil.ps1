function SystemInfo {

    $proc = (Get-CimInstance Win32_Processor)
    $proc | fl Name,SocketDesignation,Manufacturer
    $proc | ft NumberofCores,NumberofLogicalProcessors,currentClockSpeed,MaxClockSpeed

    gwmi win32_physicalmemory | ft capacity,speed,DeviceLocator,PartNumber

    Get-PhysicalDisk | Get-StorageReliabilityCounter

    Get-iscsisession | ft InitiatorNodeAddress,TargetNodeAddress,isConnected
}

function OSinfo {
    $Os = (Get-CimInstance win32_OperatingSystem)
    $memUse = ( ($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / $os.TotalVisibleMemorySize)*100
    Write-Verbose $memUse -Verbose

    $os.MaxProcessMemorySize

    $os.LocalDateTime - $os.LastBootUpTime | ft days,hours,minutes
}

function VMConfigInfo {
    Get-VMSwitch | ft -AutoSize Name,AllowManagementOS,switchType,ID

    Get-vm | % { Get-VMNetworkAdapter -VMName $_.VMName | ft -AutoSize Vmname,SwitchName,IPaddresses }

}