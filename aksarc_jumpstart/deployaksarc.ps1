[CmdletBinding()]
param (
    [Parameter()]
    [string] $GroupName = "jumpstart-rg",
    [Parameter(Mandatory = $true)]
    [ValidateSet("eastus", "australiaeast")]
    [string] $Location = "eastus",
    [Parameter()]
    [string] $vnetName = "jumpstartVNet",
    [Parameter()]
    [string] $vmName = "jumpstartVM",
    [Parameter()]
    [string] $subnetName = "jumpstartSubnet",
    [Parameter(Mandatory = $true)]
    [string] $subscription,
    [Parameter()]
    [string] $applianceName,
    [Parameter()]
    [string] $ArcLnetName,
    [Parameter()]
    [string] $aksArcClusterName,
    [Parameter()]
    [string] $customLocationName,
    [Parameter()]
    [string] $workingDir
)

# Initialize execution status tracking
$executionStatus = @{
  Status = "InProgress"
  Script = "deployaksarc.ps1"
  StartTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  CompletedSteps = @()
  FailedStep = $null
  ErrorMessage = ""
  ExitCode = 0
}

# Print the execution status block (used on success and failure).
function Write-ExecutionStatus {
  $executionStatus.EndTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  Write-Host "`n===== EXECUTION STATUS ====="
  Write-Host "Status: $($executionStatus.Status)"
  if ($executionStatus.Status -eq "Failure") {
    Write-Host "Failed Step: $($executionStatus.FailedStep)"
    Write-Host "Error Message: $($executionStatus.ErrorMessage)"
  }
  Write-Host "Exit Code: $($executionStatus.ExitCode)"
  Write-Host "Completed Steps: $($executionStatus.CompletedSteps -join ', ')"
  Write-Host "Start Time: $($executionStatus.StartTime)"
  Write-Host "End Time: $($executionStatus.EndTime)"
  Write-Host "============================"
}

# Record a failed step, print status, and exit with the given code.
function Invoke-StepFailure {
  param(
    [Parameter(Mandatory = $true)] [string] $StepName,
    [Parameter(Mandatory = $true)] [string] $ErrorText,
    [Parameter()] [int] $ExitCode = 1
  )
  $executionStatus.Status = "Failure"
  $executionStatus.FailedStep = $StepName
  $executionStatus.ErrorMessage = $ErrorText
  $executionStatus.ExitCode = $ExitCode
  Write-ExecutionStatus
  exit $ExitCode
}

if ([string]::IsNullOrEmpty($workingDir)) {
    $workingDir = "E:\AKSArc"
}

if ([string]::IsNullOrEmpty($applianceName)) {
    $applianceName = "$vmName-appliance"
} 
if ([string]::IsNullOrEmpty($customLocationName)) {
    $customLocationName = "$applianceName-cl"
}
if ([string]::IsNullOrEmpty($ArcLnetName)) {
    $ArcLnetName = "$applianceName-lnet"
}
if ([string]::IsNullOrEmpty($aksArcClusterName)) {
    $aksArcClusterName = "$applianceName-aksarc"
}
# This is a continuation of jumpstart.ps1 to deploy ARB specific components
# At this point, MOC is expected to be installed.

$ErrorActionPreference = "Stop"

$gitSource = (git config --get remote.origin.url).Replace("github.com", "raw.githubusercontent.com").Replace("aksArc.git", "aksArc")
$branch = (git branch --show-current)
$scriptLocation = "$gitSource/refs/heads/$branch/aksarc_jumpstart/scripts"

$applianceName = "$vmName-appliance"
$scriptToExecute = [ordered] @{
    "$scriptLocation/installazmodules.ps1"      = "installazmodules.ps1 -arcHciVersion ""1.3.15""  ";
    "$scriptLocation/deployappliance.ps1"       = "deployappliance.ps1 -resource_group ""$GroupName"" -appliance_name ""$applianceName""  -location ""$Location"" -subscription ""$subscription"" ";
    "$scriptLocation/deployaksarcextension.ps1" = "deployaksarcextension.ps1 -resource_group ""$GroupName"" -appliance_name ""$applianceName""  -location ""$Location"" -subscription ""$subscription""";
    "$scriptLocation/deployvmssextension.ps1"   = "deployvmssextension.ps1 -resource_group ""$GroupName"" -appliance_name ""$applianceName""  -location ""$Location"" -subscription ""$subscription""";
    "$scriptLocation/deploycustomlocation.ps1"  = "deploycustomlocation.ps1 -resource_group ""$GroupName"" -appliance_name ""$applianceName"" -customLocationName ""$customLocationName"" -subscription ""$subscription""";
    "$scriptLocation/deploylnet.ps1"            = "deploylnet.ps1 -resource_group ""$GroupName""  -lnetName ""$ArcLnetName"" -customLocationName ""$customLocationName"" -location ""$Location"" -subscription ""$subscription""";
    "$scriptLocation/deployaksarccluster.ps1"   = "deployaksarccluster.ps1 -resource_group ""$GroupName"" -aksArcClusterName ""$aksArcClusterName"" -lnetName ""$ArcLnetName"" -customLocationName ""$customLocationName"" -subscription ""$subscription""";
}

foreach ($script in $scriptToExecute.GetEnumerator()) {
    $scriptUrl = $script.Key
    $scriptName = $script.Value
    $scriptBaseName = $scriptName.Split(" ")[0]

    $deploymentName = "executescript-$($vmName)-$($scriptBaseName.Replace('.ps1',''))"
    $commandToExecute = "powershell.exe -ExecutionPolicy Unrestricted -File $scriptName"
    Write-Host "Executing $commandToExecute  from $scriptUrl on VM $vmName ..."
    try {
        az deployment group create --name $deploymentName --resource-group $GroupName --template-file ./configuration/executescript-template.json --parameters location=$Location vmName=$vmName scriptFileUri=$scriptUrl commandToExecute=$commandToExecute # --debug
        if ($LASTEXITCODE -ne 0) {
            Invoke-StepFailure -StepName "ExecuteScript_$scriptBaseName" -ExitCode $LASTEXITCODE `
                -ErrorText "Failed to execute script '$scriptName' on VM '$vmName'. Azure CLI command failed with exit code $LASTEXITCODE"
        }
        $executionStatus.CompletedSteps += "ExecuteScript_$scriptBaseName"
    }
    catch {
        Write-Error "An error occurred during AKS Arc cluster deployment: $_"
        Write-Error "Exception details: $($_.Exception.Message)"
        Write-Error "Stack trace: $($_.ScriptStackTrace)"
        Invoke-StepFailure -StepName "ExecuteScript_$scriptBaseName" `
            -ErrorText "An error occurred during AKS Arc cluster deployment: $_"
    }
}

Write-Host "Setup is ready for AKS Arc deployment"

# Final execution status - Success
$executionStatus.Status = "Success"
Write-ExecutionStatus