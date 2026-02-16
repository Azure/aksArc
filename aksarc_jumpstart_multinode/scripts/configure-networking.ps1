param(
    [int]$nodeIndex = 1,
    [int]$nodeCount = 1
)

# Configure networking: InternalNAT switch, IP, NAT.
# DNS and DHCP are configured only on node 1.
# Other nodes point their DNS to node 1's InternalNAT IP.

Start-Transcript -Path "$env:LogDirectory\configure-networking.ps1.log" -Append

# Wait for Hyper-V to be ready
while ($true) {
    try {
        Get-VMSwitch -ErrorAction Stop | Out-Null
        break
    } catch {
        Write-Host "Waiting for Hyper-V to be ready..."
        Start-Sleep -Seconds 10
    }
}

$gatewayIP = "172.16.0.1"
$ipPrefix = "172.16.0.0/16"

# Each node gets a unique IP on the InternalNAT switch: 172.16.0.1 for node 1, 172.16.0.2 for node 2, etc.
$nodeIP = "172.16.0.$nodeIndex"

Write-Host "Creating InternalNAT switch..."
New-VMSwitch -Name "InternalNAT" -SwitchType Internal
New-NetIPAddress -IPAddress $nodeIP -PrefixLength 16 -InterfaceAlias "vEthernet (InternalNAT)"
New-NetNat -Name "AKSARCNAT" -InternalIPInterfaceAddressPrefix $ipPrefix
Set-DnsClientServerAddress -InterfaceAlias "vEthernet (InternalNAT)" -ServerAddresses ($gatewayIP)
Set-NetIPInterface -InterfaceAlias "vEthernet (InternalNAT)" -InterfaceMetric 5

if ($nodeIndex -eq 1) {
    Write-Host "Node 1: Configuring DNS and DHCP..."
    Add-DnsServerPrimaryZone -Name "aksarc.local" -ZoneFile "aksarc.local.dns" -DynamicUpdate NonsecureAndSecure
    Add-DnsServerPrimaryZone -NetworkID 172.16.0.0/24 -ZoneFile "0.16.172.in-addr.arpa.dns" -DynamicUpdate NonsecureAndSecure
    Add-DnsServerForwarder -IPAddress ("1.1.1.1", "1.0.0.1") -PassThru
    dnscmd /resetlistenaddresses $gatewayIP
    Test-DnsServer -IPAddress $gatewayIP -ZoneName "aksarc.local"

    netsh dhcp add securitygroups
    Restart-Service dhcpserver
    Set-ItemProperty -Path registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\ServerManager\Roles\12 -Name ConfigurationState -Value 2
    Set-DhcpServerv4DnsSetting -DynamicUpdates "Always" -DeleteDnsRRonLeaseExpiry $True -UpdateDnsRRForOlderClients $True -DisableDnsPtrRRUpdate $false
    Add-DhcpServerv4Scope -name "172.16.0.0" -StartRange 172.16.100.0 -EndRange 172.16.100.255 -SubnetMask 255.255.255.0 -State Active -LeaseDuration 1.00:00:00
    Set-DhcpServerv4OptionValue -OptionID 3 -Value $gatewayIP -ScopeID 172.16.0.0
    Set-DhcpServerv4OptionValue -DnsDomain aksarc.local -DnsServer $gatewayIP

    # Register all cluster node hostnames in DNS
    for ($i = 1; $i -le $nodeCount; $i++) {
        $nodeName = "jumpstartVM-$i"
        $nodeAddr = "172.16.0.$i"
        Add-DnsServerResourceRecordA -Name $nodeName -ZoneName "aksarc.local" -IPv4Address $nodeAddr -ErrorAction SilentlyContinue
        Write-Host "Registered DNS: $nodeName -> $nodeAddr"
    }
} else {
    Write-Host "Node $nodeIndex: Pointing DNS to node 1 ($gatewayIP)..."
    Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses ($gatewayIP)
}

Write-Host "Networking configured for node $nodeIndex."
Stop-Transcript
