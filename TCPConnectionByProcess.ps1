function Get-TCPConnectionByProcess {
    Get-NetTCPConnection -state:Established | % {[pscustomobject]@{
        LocalAddress=$_.LocalAddress;
        LocalTCPPort=$_.LocalPort;
        ConnectedAddress=$_.RemoteAddress;
        ConnectedTCPPort=$_.RemotePort;
        Name=((ps -id $_.OwningProcess).name)}
    } | ft -AutoSize
}