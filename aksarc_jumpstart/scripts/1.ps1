# Create an internal switch with NAT and configure DNS and DHCP, 
# with IP Space 172.16.0.0/16
# Gateway IP: 172.16.0.1
# DNS Zone: aksarc.local
# DHCP Scope: 172.16.100.0 - 172.16.100.255
# Everything else, is static

Start-Transcript -Path "$env:LogDirectory\1.ps1.log" -Append

# Wait for Hyper-V to be ready. If we attempt too quickly, we would end up getting
# Hyper-V encountered an error trying to access an object on computer '<some comupter name>' because the object was not found.
while ($true) {
    try {
        Get-VMSwitch -ErrorAction Stop | Out-Null
        break
    } catch {
        Write-Host "Waiting for Hyper-V to be ready..."
        Start-Sleep -Seconds 10
    }
}

New-VMSwitch -Name "InternalNAT" -SwitchType Internal;  
New-NetIPAddress -IPAddress 172.16.0.1 -PrefixLength 16 -InterfaceAlias "vEthernet (InternalNAT)"; 
New-NetNat -Name "AKSARCNAT" -InternalIPInterfaceAddressPrefix 172.16.0.0/16; 
Get-NetNat
Set-DnsClientServerAddress -InterfaceAlias "vEthernet (InternalNAT)" -ServerAddresses ("172.16.0.1"); 
Set-NetIPInterface -InterfaceAlias "vEthernet (InternalNAT)" -InterfaceMetric 5
Add-DnsServerPrimaryZone -Name "aksarc.local" -ZoneFile "aksarc.local.dns" -DynamicUpdate NonsecureAndSecure; 
Add-DnsServerPrimaryZone -NetworkID 172.16.0.0/24 -ZoneFile "0.16.172.in-addr.arpa.dns" -DynamicUpdate NonsecureAndSecure; 
Add-DnsServerForwarder -IPAddress ("1.1.1.1", "1.0.0.1") -PassThru

dnscmd /resetlistenaddresses 172.16.0.1; 
Test-DnsServer -IPAddress 172.16.0.1 -ZoneName "aksarc.local"
netsh dhcp add securitygroups; Restart-Service dhcpserver

Set-ItemProperty -Path registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\ServerManager\Roles\12 -Name ConfigurationState -Value 2
Set-DhcpServerv4DnsSetting -DynamicUpdates "Always" -DeleteDnsRRonLeaseExpiry $True -UpdateDnsRRForOlderClients $True -DisableDnsPtrRRUpdate $false; 
Add-DhcpServerv4Scope -name "172.16.0.0" -StartRange 172.16.100.1 -EndRange 172.16.100.254 -SubnetMask 255.255.255.0 -State Active -LeaseDuration 1.00:00:00; 
Set-DhcpServerv4OptionValue -OptionID 3 -Value 172.16.0.1 -ScopeID 172.16.100.0; 
Set-DhcpServerv4OptionValue -DnsDomain aksarc.local -DnsServer 172.16.0.1

Stop-Transcript