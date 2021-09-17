[CmdletBinding()]
param 
(
    [Parameter(Mandatory)]
    [string]$rgName,
    [Parameter(Mandatory)]
    [string]$location,
    [Parameter(Mandatory)]
    [string]$subId,
    [Parameter(Mandatory)]
    [string]$tenantId,
    [Parameter(Mandatory)]
    [string]$domainName,
    [Parameter(Mandatory)]
    [string]$adminUsername,
    [Parameter(Mandatory)]
    [string]$userName,
    [Parameter(Mandatory)]
    [string]$adminPassword,
    [Parameter(Mandatory)]
    [string]$appId,
    [Parameter(Mandatory)]
    [string]$appSecret,
    [Parameter(Mandatory)]
    [string]$installWAC,
    [Parameter(Mandatory)]
    [string]$aksHciNetworking,
    [Parameter(Mandatory)]
    [string]$kubernetesVersion,
    [Parameter(Mandatory)]
    [int]$controlPlaneNodes,
    [Parameter(Mandatory)]
    [string]$controlPlaneNodeSize,
    [Parameter(Mandatory)]
    [string]$loadBalancerSize,
    [Parameter(Mandatory)]
    [int]$linuxWorkerNodes,
    [Parameter(Mandatory)]
    [string]$linuxWorkerNodeSize,
    [Parameter(Mandatory)]
    [int]$windowsWorkerNodes,
    [Parameter(Mandatory)]
    [string]$windowsWorkerNodeSize
)
function Log($out) {
    $out = [System.DateTime]::Now.ToString("yyyy.MM.dd hh:mm:ss") + " ---- " + $out;
    Write-Output $out;
}

function DecodeParam($parameter) {
    if ($parameter.StartsWith("base64:")) {
        $encodedParameter = $parameter.Split(':', 2)[1]
        $decodedArray = [System.Convert]::FromBase64String($encodedParameter);
        $parameter = [System.Text.Encoding]::UTF8.GetString($decodedArray); 
    }
    return $parameter
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$Global:VerbosePreference = "Continue"
$Global:ErrorActionPreference = 'Stop'
$Global:ProgressPreference = 'SilentlyContinue'

$ScriptLocation = Get-Location

### SET LOG LOCATION ###
$logPath = "$($env:SystemDrive)\InstallAksHciLog"

if (![System.IO.Directory]::Exists("$logPath")) {
    New-Item -Path $logPath -ItemType Directory -Force -ErrorAction Stop
}

### CONFIG POWER OPTIONS ###
Log "Configure Power Options to High performance mode."
POWERCFG.EXE /S SCHEME_MIN

### START LOGGING ###
$runTime = $(Get-Date).ToString("MMdd-HHmmss")
$fullLogPath = "$logPath\InstallAksHci$runTime.txt"
Start-Transcript -Path "$fullLogPath" -Append
Log "Creating log folder"
Log "Log folder has been created at $logPath"
Log "Log file stored at $fullLogPath"
Log "Starting logging"
Log "Log started at $runTime"

### DECODING PARAMETERS
Log "Decoding secure parameters passed from ARM template"
Log "adminUsername"
$adminUsername = DecodeParam $adminUsername
Log "adminUsername"
$adminPassword = DecodeParam $adminPassword
Log "appId"
$appId = DecodeParam $appId
Log "appSecret"
$appSecret = DecodeParam $appSecret
Log "appSecret = $appSecret"

### CREATE STRONG PASSWORDS ###
Log "Configuring strong passwords for the user accounts"
$strAdminPassword = ConvertTo-SecureString $adminPassword -Force -AsPlainText -Verbose
$strAppSecret = ConvertTo-SecureString $appSecret -Force -AsPlainText -Verbose

### CREATE CREDENTIALS ###
Log "Configuring credential objects"
Log "Domain Name = $domainName"
Log "Admin User = $adminUsername"
Log "App ID = $appId"
Log "Creating domain creds"
$domainCreds = New-Object System.Management.Automation.PSCredential ("$domainName\$adminUsername", $strAdminPassword)
Log "Creating node local creds"
$nodeLocalCreds = New-Object System.Management.Automation.PSCredential ($adminUsername, $strAdminPassword)
Log "Creating SP creds"
$spCreds = New-Object System.Management.Automation.PSCredential ($appId, $strAppSecret)

$targetDrive = "V"
$targetAksPath = "$targetDrive" + ":\AKS-HCI"
$loadBalancerSize = ($loadBalancerSize).Split(" ", 2)[0]
$controlPlaneNodeSize = ($controlPlaneNodeSize).Split(" ", 2)[0]
$linuxWorkerNodeSize = ($linuxWorkerNodeSize).Split(" ", 2)[0]
$windowsWorkerNodeSize = ($windowsWorkerNodeSize).Split(" ", 2)[0]

Log "Current user is $(whoami)"
Log "Resource group = $rgName"
Log "Location = $location"
Log "SubID = $subId"
Log "tenantID = $tenantId"
Log "Domain Name = $domainName"
Log "Admin User = $adminUsername"
Log "App ID = $appId"
Log "Install WAC = $installWAC"
Log "Networking config = $aksHciNetworking"
Log "Kubernetes Version = $kubernetesVersion"
Log "Number of Control Plane Nodes = $controlPlaneNodes of size: $controlPlaneNodeSize"
Log "Number of Linux Nodes = $linuxWorkerNodes of size: $linuxWorkerNodeSize"
Log "Number of Windows Plane Nodes = $windowsWorkerNodes of size: $windowsWorkerNodeSize"
Log "LB Size = $loadBalancerSize"

# Initialize AKS-HCI
try {
    $initialized = Test-Path -Path "C:\AksHciAutoDeploy\InitializeAksHci.txt"
    if (!$initialized) {
        Log "Node has not been previously initialized - initializing now"
        Invoke-Command -Credential $domainCreds -Authentication Credssp -ComputerName localhost -ScriptBlock {
            Initialize-AksHciNode
            New-item -Path C:\AksHciAutoDeploy\ -Name "InitializeAksHci.txt" -ItemType File -Force -Verbose
        }
        Log "Initialization completed"
    }
    else {
        Log "Node has been previously initialized - Moving to next step"
    }
}
catch {
    Log "Something went wrong with running Initialize-AksHci. Please review the log file at $fullLogPath and redeploy your VM."
    Set-Location $ScriptLocation
    throw $_.Exception.Message
    return
}

<# Set Network Settings
Log 'Setting the network configuration'
try {
    if ($aksHciNetworking -eq "DHCP") {
        Log "$aksHciNetworking is the chosen network type - configuring network settings"
        $vnet = New-AksHciNetworkSetting -Name "akshci-main-network" -vSwitchName "InternalNAT" `
            -vipPoolStart "192.168.0.150" -vipPoolEnd "192.168.0.250"
    } 
    else {
        Log "$aksHciNetworking is the chosen network type - configuring network settings"
        $vnet = New-AksHciNetworkSetting -Name "akshci-main-network" -vSwitchName "InternalNAT" -gateway "192.168.0.1" -dnsservers "192.168.0.1" `
            -ipaddressprefix "192.168.0.0/16" -k8snodeippoolstart "192.168.0.3" -k8snodeippoolend "192.168.0.149" `
            -vipPoolStart "192.168.0.150" -vipPoolEnd "192.168.0.250"
    }
    Log "Network configuration completed"
}
catch {
    Log "Something went wrong with configuring the network. Please review the log file at $fullLogPath and redeploy your VM."
    Set-Location $ScriptLocation
    throw $_.Exception.Message
    return
} #>

# Set AKS-HCI Config
Log 'Defining the network and AKS-HCI configuration'
try {
    Invoke-Command -Credential $domainCreds -Authentication Credssp -ComputerName localhost -ScriptBlock {
        $date = (Get-Date).ToString("MMddyy-HHmmss")
        $clusterRoleName = "akshci-mgmt-cluster-$date"
        if ($Using:aksHciNetworking -eq "DHCP") {
            $vnet = New-AksHciNetworkSetting -Name "akshci-main-network" -vSwitchName "InternalNAT" `
                -vipPoolStart "192.168.0.150" -vipPoolEnd "192.168.0.250"
        } 
        else {
            $vnet = New-AksHciNetworkSetting -Name "akshci-main-network" -vSwitchName "InternalNAT" -gateway "192.168.0.1" -dnsservers "192.168.0.1" `
                -ipaddressprefix "192.168.0.0/16" -k8snodeippoolstart "192.168.0.3" -k8snodeippoolend "192.168.0.149" `
                -vipPoolStart "192.168.0.150" -vipPoolEnd "192.168.0.250"
        }
        Set-AksHciConfig -vnet $vnet -imageDir "$Using:targetAksPath\Images" -workingDir "$Using:targetAksPath\WorkingDir" `
            -cloudConfigLocation "$Using:targetAksPath\Config" -clusterRoleName $clusterRoleName -Verbose
    }
    Log "AKS-HCI Config successfully completed"
}
catch {
    Log "Something went wrong with setting the AKS-HCI config. Please review the log file at $fullLogPath and redeploy your VM."
    Set-Location $ScriptLocation
    throw $_.Exception.Message
    return
}

$endTime = $(Get-Date).ToString("MMdd-HHmmss")
Log "Logging stopped at $endTime"
Stop-Transcript -ErrorAction SilentlyContinue