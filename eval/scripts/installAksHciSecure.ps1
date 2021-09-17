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


### CREATE CREDENTIALS ###
Log "Configuring credential objects"
#[System.Management.Automation.PSCredential]$domainCreds = New-Object System.Management.Automation.PSCredential ("${domainName}\$($adminUsername)", $adminPassword)
#[System.Management.Automation.PSCredential]$nodeLocalCreds = New-Object System.Management.Automation.PSCredential ($adminUsername, $adminPassword)
#[System.Management.Automation.PSCredential]$spCreds = New-Object System.Management.Automation.PSCredential ($appId, $appSecret)

$targetDrive = "V"
$targetAksPath = "$targetDrive" + ":\AKS-HCI"
$loadBalancerSize = ($loadBalancerSize).Split(" ", 2)[0]
$controlPlaneNodeSize = ($controlPlaneNodeSize).Split(" ", 2)[0]
$linuxWorkerNodeSize = ($linuxWorkerNodeSize).Split(" ", 2)[0]
$windowsWorkerNodeSize = ($windowsWorkerNodeSize).Split(" ", 2)[0]

<# Initialize AKS-HCI
try {
    $initialized = Test-Path -Path "C:\AksHciAutoDeploy\InitializeAksHci.txt"
    if (!$initialized) {
        Log "Node has not been previously initialized - initializing now"
        Initialize-AksHciNode
        New-item -Path C:\AksHciAutoDeploy\ -Name "InitializeAksHci.txt" -ItemType File -Force -Verbose
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
} #>

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

$endTime = $(Get-Date).ToString("MMdd-HHmmss")
Log "Logging stopped at $endTime"
Stop-Transcript -ErrorAction SilentlyContinue