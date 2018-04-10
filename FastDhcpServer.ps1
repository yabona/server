# Give me DHCP dammit!
# Run as DA, fuck best practices!

param(
  [Paramater(Mandatory=$True)]$TargetDomainController,
)

$RemoteCommandInvocation = {

  Install-WindowsFeature dhcp -IncludeManagementTools

  $DC_IPconfig = Get-NetIPConfiguration

  [System.Collections.ArrayList]$addr = $DC_IPconfig.ipv4address.ipaddress.split('.')
  [string]$subnet = "$([string]$addr[0]).$([string]$addr[1]).$([string]$addr[2])"
      # that's shit and I feel ashamed

  if($DC_IPconfig.ipaddress.prefixlength -ne 24) {
      $subnetMask = Read-Host "subnet mask"
  }else{ $subnet = $DC_IPconfig.ipaddress.prefixlength }

  Add-DhcpServerv4Scope -StartRange "$subnet.200" -EndRange "$subnet.250"  `
      -name DHCP_Server -SubnetMask $SubnetMask

  Set-DhcpServerv4OptionValue -ScopeId "$subnet.0" `
      -DnsDomain $DC_IPconfig.netprofile.name `
      -DnsServer $DC_IPconfig.ipv4address.ipaddress `
      -Router $DC_IPconfig.IPv4defaultGateway.Nexthop

  Add-DhcpServerInDC -DnsName $(hostname)

}

#-------------------------------------------------------------------------------
Invoke-Command -computername:$TargetDomainController -Scriptblock:$RemoteCommandInvocation
