configuration AKSHCIHost
{
    param 
    ( 
        [Parameter(Mandatory)]
        [string]$DomainName,
        [Parameter(Mandatory)]
        [string]$environment,
        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$Admincreds,
        [Parameter(Mandatory)]
        [string]$enableDHCP,
        [Parameter(Mandatory)]
        [string]$customRdpPort,
        [Int]$RetryCount = 20,
        [Int]$RetryIntervalSec = 30,
        [string]$vSwitchNameHost = "InternalNAT",
        [String]$targetDrive = "V",
        [String]$targetVMPath = "$targetDrive" + ":\VMs",
        [String]$targetADPath = "$targetDrive" + ":\ADDS",
        [String]$baseVHDFolderPath = "$targetVMPath\base"
    ) 
    
    Import-DscResource -ModuleName 'PSDesiredStateConfiguration'
    Import-DscResource -ModuleName 'xPSDesiredStateConfiguration'
    Import-DscResource -ModuleName 'ComputerManagementDsc'
    Import-DscResource -ModuleName 'xHyper-v'
    Import-DscResource -ModuleName 'StorageDSC'
    Import-DscResource -ModuleName 'NetworkingDSC'
    Import-DscResource -ModuleName 'xDHCpServer'
    Import-DscResource -ModuleName 'xDNSServer'
    Import-DscResource -ModuleName 'cChoco'
    Import-DscResource -ModuleName 'DSCR_Shortcut'
    Import-DscResource -ModuleName 'xCredSSP'
    Import-DscResource -ModuleName 'xActiveDirectory'

    if ($enableDHCP -eq "Enabled") {
        $dhcpStatus = "Active"
    }
    else { $dhcpStatus = "Inactive" }

    [System.Management.Automation.PSCredential]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($Admincreds.UserName)", $Admincreds.Password)

    $ipConfig = (Get-NetAdapter -Physical | Get-NetIPConfiguration | Where-Object IPv4DefaultGateway)
    $netAdapters = Get-NetAdapter -Name ($ipConfig.InterfaceAlias) | Select-Object -First 1
    $InterfaceAlias = $($netAdapters.Name)

    Node localhost
    {
        LocalConfigurationManager {
            RebootNodeIfNeeded = $true
            ActionAfterReboot  = 'ContinueConfiguration'
            ConfigurationMode  = 'ApplyOnly'
        }

        # STAGE 1 -> PRE-HYPER-V REBOOT
        # STAGE 2 -> POST-HYPER-V REBOOT
        # STAGE 3 -> POST CREDSSP REBOOT

        #### STAGE 1a - CREATE STORAGE SPACES V: & VM FOLDER ####

        Script StoragePool {
            SetScript  = {
                New-StoragePool -FriendlyName AksHciPool -StorageSubSystemFriendlyName '*storage*' -PhysicalDisks (Get-PhysicalDisk -CanPool $true)
            }
            TestScript = {
                (Get-StoragePool -ErrorAction SilentlyContinue -FriendlyName AksHciPool).OperationalStatus -eq 'OK'
            }
            GetScript  = {
                @{Ensure = if ((Get-StoragePool -FriendlyName AksHciPool).OperationalStatus -eq 'OK') { 'Present' } Else { 'Absent' } }
            }
        }
        Script VirtualDisk {
            SetScript  = {
                $disks = Get-StoragePool -FriendlyName AksHciPool -IsPrimordial $False | Get-PhysicalDisk
                $diskNum = $disks.Count
                New-VirtualDisk -StoragePoolFriendlyName AksHciPool -FriendlyName AksHciDisk -ResiliencySettingName Simple -NumberOfColumns $diskNum -UseMaximumSize
            }
            TestScript = {
                (Get-VirtualDisk -ErrorAction SilentlyContinue -FriendlyName AksHciDisk).OperationalStatus -eq 'OK'
            }
            GetScript  = {
                @{Ensure = if ((Get-VirtualDisk -FriendlyName AksHciDisk).OperationalStatus -eq 'OK') { 'Present' } Else { 'Absent' } }
            }
            DependsOn  = "[Script]StoragePool"
        }
        Script FormatDisk {
            SetScript  = {
                $vDisk = Get-VirtualDisk -FriendlyName AksHciDisk
                if ($vDisk | Get-Disk | Where-Object PartitionStyle -eq 'raw') {
                    $vDisk | Get-Disk | Initialize-Disk -Passthru | New-Partition -DriveLetter $Using:targetDrive -UseMaximumSize | Format-Volume -NewFileSystemLabel AksHciData -AllocationUnitSize 64KB -FileSystem NTFS
                }
                elseif ($vDisk | Get-Disk | Where-Object PartitionStyle -eq 'GPT') {
                    $vDisk | Get-Disk | New-Partition -DriveLetter $Using:targetDrive -UseMaximumSize | Format-Volume -NewFileSystemLabel AksHciData -AllocationUnitSize 64KB -FileSystem NTFS
                }
            }
            TestScript = { 
                (Get-Volume -ErrorAction SilentlyContinue -FileSystemLabel AksHciData).FileSystem -eq 'NTFS'
            }
            GetScript  = {
                @{Ensure = if ((Get-Volume -FileSystemLabel AksHciData).FileSystem -eq 'NTFS') { 'Present' } Else { 'Absent' } }
            }
            DependsOn  = "[Script]VirtualDisk"
        }

        File "VMfolder" {
            Type            = 'Directory'
            DestinationPath = $targetVMPath
            DependsOn       = "[Script]FormatDisk"
        }

        if ($environment -eq "AD Domain") {
            File "ADfolder" {
                Type            = 'Directory'
                DestinationPath = $targetADPath
                DependsOn       = "[Script]FormatDisk"
            }
        }

        #### STAGE 1b - SET WINDOWS DEFENDER EXCLUSION FOR VM STORAGE ####

        Script defenderExclusions {
            SetScript  = {
                $exclusionPath = "$Using:targetDrive" + ":\"
                Add-MpPreference -ExclusionPath "$exclusionPath"               
            }
            TestScript = {
                $exclusionPath = "$Using:targetDrive" + ":\"
                (Get-MpPreference).ExclusionPath -contains "$exclusionPath"
            }
            GetScript  = {
                $exclusionPath = "$Using:targetDrive" + ":\"
                @{Ensure = if ((Get-MpPreference).ExclusionPath -contains "$exclusionPath") { 'Present' } Else { 'Absent' } }
            }
            DependsOn  = "[File]VMfolder"
        }

        #### STAGE 1c - REGISTRY & SCHEDULED TASK TWEAKS ####

        Registry "Disable Internet Explorer ESC for Admin" {
            Key       = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
            Ensure    = 'Present'
            ValueName = "IsInstalled"
            ValueData = "0"
            ValueType = "Dword"
        }

        Registry "Disable Internet Explorer ESC for User" {
            Key       = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
            Ensure    = 'Present'
            ValueName = "IsInstalled"
            ValueData = "0"
            ValueType = "Dword"
        }
        
        Registry "Disable Server Manager WAC Prompt" {
            Key       = "HKLM:\SOFTWARE\Microsoft\ServerManager"
            Ensure    = 'Present'
            ValueName = "DoNotPopWACConsoleAtSMLaunch"
            ValueData = "1"
            ValueType = "Dword"
        }

        Registry "Disable Network Profile Prompt" {
            Key       = 'HKLM:\System\CurrentControlSet\Control\Network\NewNetworkWindowOff'
            Ensure    = 'Present'
            ValueName = ''
        }

        if ($environment -eq "Workgroup") {
            Registry "Set Network Private Profile Default" {
                Key       = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\CurrentVersion\NetworkList\Signatures\010103000F0000F0010000000F0000F0C967A3643C3AD745950DA7859209176EF5B87C875FA20DF21951640E807D7C24'
                Ensure    = 'Present'
                ValueName = "Category"
                ValueData = "1"
                ValueType = "Dword"
            }
    
            Registry "SetWorkgroupDomain" {
                Key       = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
                Ensure    = 'Present'
                ValueName = "Domain"
                ValueData = "$DomainName"
                ValueType = "String"
            }
    
            Registry "SetWorkgroupNVDomain" {
                Key       = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
                Ensure    = 'Present'
                ValueName = "NV Domain"
                ValueData = "$DomainName"
                ValueType = "String"
            }
    
            Registry "NewCredSSPKey" {
                Key       = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly'
                Ensure    = 'Present'
                ValueName = ''
            }
    
            Registry "NewCredSSPKey2" {
                Key       = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation'
                ValueName = 'AllowFreshCredentialsWhenNTLMOnly'
                ValueData = '1'
                ValueType = "Dword"
                DependsOn = "[Registry]NewCredSSPKey"
            }
    
            Registry "NewCredSSPKey3" {
                Key       = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly'
                ValueName = '1'
                ValueData = "*.$DomainName"
                ValueType = "String"
                DependsOn = "[Registry]NewCredSSPKey2"
            }
        }

        ScheduledTask "Disable Server Manager at Startup" {
            TaskName = 'ServerManager'
            Enable   = $false
            TaskPath = '\Microsoft\Windows\Server Manager'
        }

        #### STAGE 1d - CUSTOM FIREWALL BASED ON ARM TEMPLATE ####

        if ($customRdpPort -ne "3389") {

            Registry "Set Custom RDP Port" {
                Key       = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp'
                ValueName = "PortNumber"
                ValueData = "$customRdpPort"
                ValueType = 'Dword'
            }
        
            Firewall AddFirewallRule {
                Name        = 'CustomRdpRule'
                DisplayName = 'Custom Rule for RDP'
                Ensure      = 'Present'
                Enabled     = 'True'
                Profile     = 'Any'
                Direction   = 'Inbound'
                LocalPort   = "$customRdpPort"
                Protocol    = 'TCP'
                Description = 'Firewall Rule for Custom RDP Port'
            }
        }

        #### STAGE 1e - ENABLE ROLES & FEATURES ####

        WindowsFeature DNS { 
            Ensure = "Present" 
            Name   = "DNS"		
        }

        WindowsFeature "Enable Deduplication" { 
            Ensure = "Present" 
            Name   = "FS-Data-Deduplication"		
        }

        Script EnableDNSDiags {
            SetScript  = { 
                Set-DnsServerDiagnostics -All $true
                Write-Verbose -Verbose "Enabling DNS client diagnostics" 
            }
            GetScript  = { @{} }
            TestScript = { $false }
            DependsOn  = "[WindowsFeature]DNS"
        }

        WindowsFeature DnsTools {
            Ensure    = "Present"
            Name      = "RSAT-DNS-Server"
            DependsOn = "[WindowsFeature]DNS"
        }

        DnsServerAddress "DnsServerAddress for $InterfaceAlias"
        { 
            Address        = '127.0.0.1'
            InterfaceAlias = $InterfaceAlias
            AddressFamily  = 'IPv4'
            DependsOn      = "[WindowsFeature]DNS"
        }

        if ($environment -eq "AD Domain") {

            WindowsFeature ADDSInstall { 
                Ensure    = "Present" 
                Name      = "AD-Domain-Services"
                DependsOn = "[WindowsFeature]DNS" 
            } 

            WindowsFeature ADDSTools {
                Ensure    = "Present"
                Name      = "RSAT-ADDS-Tools"
                DependsOn = "[WindowsFeature]ADDSInstall"
            }

            WindowsFeature ADAdminCenter {
                Ensure    = "Present"
                Name      = "RSAT-AD-AdminCenter"
                DependsOn = "[WindowsFeature]ADDSInstall"
            }
         
            xADDomain FirstDS {
                DomainName                    = $DomainName
                DomainAdministratorCredential = $DomainCreds
                SafemodeAdministratorPassword = $DomainCreds
                DatabasePath                  = "$targetADPath" + "\NTDS"
                LogPath                       = "$targetADPath" + "\NTDS"
                SysvolPath                    = "$targetADPath" + "\SYSVOL"
                DependsOn                     = @("[File]ADfolder", "[WindowsFeature]ADDSInstall")
            }
        }

        WindowsFeature "RSAT-Clustering" {
            Name   = "RSAT-Clustering"
            Ensure = "Present"
        }

        WindowsFeature "Install DHCPServer" {
            Name   = 'DHCP'
            Ensure = 'Present'
        }

        WindowsFeature DHCPTools {
            Ensure    = "Present"
            Name      = "RSAT-DHCP"
            DependsOn = "[WindowsFeature]Install DHCPServer"
        }

        Registry "DHCpConfigComplete" {
            Key       = 'HKLM:\SOFTWARE\Microsoft\ServerManager\Roles\12'
            ValueName = "ConfigurationState"
            ValueData = "2"
            ValueType = 'Dword'
            DependsOn = "[WindowsFeature]DHCPTools"
        }

        if ($environment -eq "AD Domain") {
            WindowsFeature "Hyper-V" {
                Name   = "Hyper-V"
                Ensure = "Present"
            }
        }
        else {
            WindowsFeature "Hyper-V" {
                Name      = "Hyper-V"
                Ensure    = "Present"
                DependsOn = "[Registry]NewCredSSPKey3"
            }
        }

        WindowsFeature "RSAT-Hyper-V-Tools" {
            Name      = "RSAT-Hyper-V-Tools"
            Ensure    = "Present"
            DependsOn = "[WindowsFeature]Hyper-V" 
        }

        #### STAGE 2a - HYPER-V vSWITCH CONFIG ####

        xVMHost "hpvHost"
        {
            IsSingleInstance          = 'yes'
            EnableEnhancedSessionMode = $true
            VirtualHardDiskPath       = $targetVMPath
            VirtualMachinePath        = $targetVMPath
            DependsOn                 = "[WindowsFeature]Hyper-V"
        }

        xVMSwitch "$vSwitchNameHost"
        {
            Name      = $vSwitchNameHost
            Type      = "Internal"
            DependsOn = "[WindowsFeature]Hyper-V"
        }

        IPAddress "New IP for vEthernet $vSwitchNameHost"
        {
            InterfaceAlias = "vEthernet `($vSwitchNameHost`)"
            AddressFamily  = 'IPv4'
            IPAddress      = '192.168.0.1/16'
            DependsOn      = "[xVMSwitch]$vSwitchNameHost"
        }

        NetIPInterface "Enable IP forwarding on vEthernet $vSwitchNameHost"
        {   
            AddressFamily  = 'IPv4'
            InterfaceAlias = "vEthernet `($vSwitchNameHost`)"
            Forwarding     = 'Enabled'
            DependsOn      = "[IPAddress]New IP for vEthernet $vSwitchNameHost"
        }

        NetAdapterRdma "EnableRDMAonvEthernet"
        {
            Name      = "vEthernet `($vSwitchNameHost`)"
            Enabled   = $true
            DependsOn = "[NetIPInterface]Enable IP forwarding on vEthernet $vSwitchNameHost"
        }

        DnsServerAddress "DnsServerAddress for vEthernet $vSwitchNameHost" 
        { 
            Address        = '127.0.0.1' 
            InterfaceAlias = "vEthernet `($vSwitchNameHost`)"
            AddressFamily  = 'IPv4'
            DependsOn      = "[IPAddress]New IP for vEthernet $vSwitchNameHost"
        }

        if ($environment -eq "AD Domain") {

            xDhcpServerAuthorization "Authorize DHCP" {
                Ensure    = 'Present'
                DependsOn = @('[WindowsFeature]Install DHCPServer')
                DnsName   = [System.Net.Dns]::GetHostByName($env:computerName).hostname
                IPAddress = '192.168.0.1'
            }
        }

        if ($environment -eq "Workgroup") {
            NetConnectionProfile SetProfile
            {
                InterfaceAlias  = 'Ethernet'
                NetworkCategory = 'Private'
            }
        }

        #### STAGE 2b - PRIMARY NIC CONFIG ####

        NetAdapterBinding DisableIPv6Host
        {
            InterfaceAlias = 'Ethernet'
            ComponentId    = 'ms_tcpip6'
            State          = 'Disabled'
        }

        #### STAGE 2c - CONFIGURE InternaNAT NIC

        script NAT {
            GetScript  = {
                $nat = "AKSHCINAT"
                $result = if (Get-NetNat -Name $nat -ErrorAction SilentlyContinue) { $true } else { $false }
                return @{ 'Result' = $result }
            }
        
            SetScript  = {
                $nat = "AKSHCINAT"
                New-NetNat -Name $nat -InternalIPInterfaceAddressPrefix "192.168.0.0/16"          
            }
        
            TestScript = {
                # Create and invoke a scriptblock using the $GetScript automatic variable, which contains a string representation of the GetScript.
                $state = [scriptblock]::Create($GetScript).Invoke()
                return $state.Result
            }
            DependsOn  = "[IPAddress]New IP for vEthernet $vSwitchNameHost"
        }

        NetAdapterBinding DisableIPv6NAT
        {
            InterfaceAlias = "vEthernet `($vSwitchNameHost`)"
            ComponentId    = 'ms_tcpip6'
            State          = 'Disabled'
            DependsOn      = "[Script]NAT"
        }

        #### STAGE 2d - CONFIGURE DHCP SERVER

        xDhcpServerScope "AksHciDhcpScope" { 
            Ensure        = 'Present'
            IPStartRange  = '192.168.0.3'
            IPEndRange    = '192.168.0.149' 
            ScopeId       = '192.168.0.0'
            Name          = 'AKS-HCI Lab Range'
            SubnetMask    = '255.255.0.0'
            LeaseDuration = '01.00:00:00'
            State         = "$dhcpStatus"
            AddressFamily = 'IPv4'
            DependsOn     = @("[WindowsFeature]Install DHCPServer", "[IPAddress]New IP for vEthernet $vSwitchNameHost")
        }

        xDhcpServerOption "AksHciDhcpServerOption" { 
            Ensure             = 'Present' 
            ScopeID            = '192.168.0.0' 
            DnsDomain          = "$DomainName"
            DnsServerIPAddress = '192.168.0.1'
            AddressFamily      = 'IPv4'
            Router             = '192.168.0.1'
            DependsOn          = "[xDhcpServerScope]AksHciDhcpScope"
        }

        if ($environment -eq "Workgroup") {

            xDnsServerPrimaryZone SetPrimaryDNSZone {
                Name          = "$DomainName"
                Ensure        = 'Present'
                DependsOn     = "[script]NAT"
                ZoneFile      = "$DomainName" + ".dns"
                DynamicUpdate = 'NonSecureAndSecure'
            }
    
            xDnsServerPrimaryZone SetReverseLookupZone {
                Name          = '0.168.192.in-addr.arpa'
                Ensure        = 'Present'
                DependsOn     = "[xDnsServerPrimaryZone]SetPrimaryDNSZone"
                ZoneFile      = '0.168.192.in-addr.arpa.dns'
                DynamicUpdate = 'NonSecureAndSecure'
            }
        }

        #### STAGE 2f - FINALIZE DHCP

        Script SetDHCPDNSSetting {
            SetScript  = { 
                Set-DhcpServerv4DnsSetting -DynamicUpdates "Always" -DeleteDnsRRonLeaseExpiry $True -UpdateDnsRRForOlderClients $True -DisableDnsPtrRRUpdate $false
                Write-Verbose -Verbose "Setting server level DNS dynamic update configuration settings"
            }
            GetScript  = { @{} 
            }
            TestScript = { $false }
            DependsOn  = "[xDhcpServerOption]AksHciDhcpServerOption"
        }

        if ($environment -eq "Workgroup") {

            DnsConnectionSuffix AddSpecificSuffixHostNic
            {
                InterfaceAlias           = 'Ethernet'
                ConnectionSpecificSuffix = "$DomainName"
                DependsOn                = "[xDnsServerPrimaryZone]SetPrimaryDNSZone"
            }
    
            DnsConnectionSuffix AddSpecificSuffixNATNic
            {
                InterfaceAlias           = "vEthernet `($vSwitchNameHost`)"
                ConnectionSpecificSuffix = "$DomainName"
                DependsOn                = "[xDnsServerPrimaryZone]SetPrimaryDNSZone"
            }

            #### STAGE 2h - CONFIGURE CREDSSP & WinRM

            xCredSSP Server {
                Ensure         = "Present"
                Role           = "Server"
                DependsOn      = "[DnsConnectionSuffix]AddSpecificSuffixNATNic"
                SuppressReboot = $true
            }
            xCredSSP Client {
                Ensure            = "Present"
                Role              = "Client"
                DelegateComputers = "$env:COMPUTERNAME" + ".$DomainName"
                DependsOn         = "[xCredSSP]Server"
                SuppressReboot    = $true
            }

            #### STAGE 3a - CONFIGURE WinRM

            Script ConfigureWinRM {
                SetScript  = {
                    Set-Item WSMan:\localhost\Client\TrustedHosts "*.$Using:DomainName" -Force
                }
                TestScript = {
                    (Get-Item WSMan:\localhost\Client\TrustedHosts).Value -contains "*.$Using:DomainName"
                }
                GetScript  = {
                    @{Ensure = if ((Get-Item WSMan:\localhost\Client\TrustedHosts).Value -contains "*.$Using:DomainName") { 'Present' } Else { 'Absent' } }
                }
                DependsOn  = "[xCredSSP]Client"
            }
        }

        #### STAGE 3b - INSTALL CHOCO, DEPLOY EDGE and Shortcuts

        cChocoInstaller InstallChoco {
            InstallDir = "c:\choco"
        }
            
        cChocoFeature allowGlobalConfirmation {
            FeatureName = "allowGlobalConfirmation"
            Ensure      = 'Present'
            DependsOn   = '[cChocoInstaller]installChoco'
        }
        
        cChocoFeature useRememberedArgumentsForUpgrades {
            FeatureName = "useRememberedArgumentsForUpgrades"
            Ensure      = 'Present'
            DependsOn   = '[cChocoInstaller]installChoco'
        }
        
        cChocoPackageInstaller "Install Chromium Edge" {
            Name        = 'microsoft-edge'
            Ensure      = 'Present'
            AutoUpgrade = $true
            DependsOn   = '[cChocoInstaller]installChoco'
        }

        cShortcut "Wac Shortcut"
        {
            Path      = 'C:\Users\Public\Desktop\Windows Admin Center.lnk'
            Target    = 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'
            Arguments = "https://$env:computerName"
            Icon      = 'shell32.dll,34'
        }

        #### STAGE 3c - Update Firewall

        Firewall WACInboundRule {
            Name        = 'WACInboundRule'
            DisplayName = 'Allow Windows Admin Center'
            Ensure      = 'Present'
            Enabled     = 'True'
            Profile     = 'Any'
            Direction   = 'Inbound'
            LocalPort   = "443"
            Protocol    = 'TCP'
            Description = 'Allow Windows Admin Center'
        }

        Firewall WACOutboundRule {
            Name        = 'WACOutboundRule'
            DisplayName = 'Allow Windows Admin Center'
            Ensure      = 'Present'
            Enabled     = 'True'
            Profile     = 'Any'
            Direction   = 'Outbound'
            LocalPort   = "443"
            Protocol    = 'TCP'
            Description = 'Allow Windows Admin Center'
        }
    }
}