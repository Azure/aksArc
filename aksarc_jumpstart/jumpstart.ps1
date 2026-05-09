[CmdletBinding()]
param (
  [Parameter()]
  [string]
  $userName,
  [Parameter()]
  [string]
  $password,
  [Parameter()]
  [string]
  $GroupName = "jumpstart-rg",
  [Parameter(Mandatory = $true)]
  [ValidateSet("eastus", "australiaeast")]
  [string] $Location = "eastus",
  [Parameter()]
  [string]
  $vnetName = "jumpstartVNet",
  [Parameter()]
  [string]
  $vmName = "jumpstartVM",
  [Parameter()]
  [string]
  $subnetName = "jumpstartSubnet",
  [Parameter()]
  [string]
  $subscriptionId
)

# Initialize execution status tracking
$executionStatus = @{
  Status = "InProgress"
  Script = "jumpstart.ps1"
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

# Create Resource Group
az group create --name $GroupName --location $Location
if ($LASTEXITCODE -ne 0) {
  Invoke-StepFailure -StepName "CreateResourceGroup" -ExitCode $LASTEXITCODE `
    -ErrorText "Failed to create resource group '$GroupName' in location '$Location'. Azure CLI command failed with exit code $LASTEXITCODE"
}
$executionStatus.CompletedSteps += "CreateResourceGroup"

# Create Vnet and VM
az deployment group create --resource-group $GroupName --template-file ./configuration/vnet-template.json --parameters vnetName=$vnetName location=$Location subnetName=$subnetName
if ($LASTEXITCODE -ne 0) {
  Invoke-StepFailure -StepName "CreateVirtualNetwork" -ExitCode $LASTEXITCODE `
    -ErrorText "Failed to create virtual network '$vnetName' and subnet '$subnetName'. Azure CLI command failed with exit code $LASTEXITCODE"
}
$executionStatus.CompletedSteps += "CreateVirtualNetwork"

az deployment group create --resource-group $GroupName --template-file ./configuration/vm-template.json --parameters adminUsername=$userName adminPassword=$password vmName=$vmName location=$Location vnetName=$vnetName vmSize="Standard_E16s_v4" subnetName=$subnetName
if ($LASTEXITCODE -ne 0) {
  Invoke-StepFailure -StepName "CreateVirtualMachine" -ExitCode $LASTEXITCODE `
    -ErrorText "Failed to create virtual machine '$vmName'. Azure CLI command failed with exit code $LASTEXITCODE"
}
$executionStatus.CompletedSteps += "CreateVirtualMachine"

# Assign Managed Identity and Contributor Role to VM
az vm identity assign --resource-group $GroupName --name $vmName
if ($LASTEXITCODE -ne 0) {
  Invoke-StepFailure -StepName "AssignManagedIdentity" -ExitCode $LASTEXITCODE `
    -ErrorText "Failed to assign managed identity to VM '$vmName'. Azure CLI command failed with exit code $LASTEXITCODE"
}
$executionStatus.CompletedSteps += "AssignManagedIdentity"
$principalId = az vm show --resource-group $GroupName --name $vmName --query identity.principalId -o tsv
az role assignment create --assignee $principalId --role Contributor --scope /subscriptions/$subscriptionId
if ($LASTEXITCODE -ne 0) {
  Invoke-StepFailure -StepName "AssignContributorRole" -ExitCode $LASTEXITCODE `
    -ErrorText "Failed to assign Contributor role to VM identity. Azure CLI command failed with exit code $LASTEXITCODE"
}
$executionStatus.CompletedSteps += "AssignContributorRole"

#az deployment group create --resource-group $GroupName --template-file a4s-template.json --parameters location=$Location vmName=$vmName arcResourceGroup=$GroupName subscriptionId=$subscriptionId tenantId=$tenantId
# Enable Nested Virtualization
az vm update   --resource-group $GroupName   --name $vmName --set additionalCapabilities.enableNestedVirtualization=true
if ($LASTEXITCODE -ne 0) {
  Invoke-StepFailure -StepName "EnableNestedVirtualization" -ExitCode $LASTEXITCODE `
    -ErrorText "Failed to enable nested virtualization on VM '$vmName'. Azure CLI command failed with exit code $LASTEXITCODE"
}
$executionStatus.CompletedSteps += "EnableNestedVirtualization"

$gitSource = (git config --get remote.origin.url).Replace("github.com", "raw.githubusercontent.com").Replace("aksArc.git", "aksArc")
$branch = (git branch --show-current)
$scriptLocation = "$gitSource/refs/heads/$branch/aksarc_jumpstart/scripts"

$scriptToExecute = [ordered] @{
  "$scriptLocation/initializedisk.ps1" = "initializedisk.ps1";
  "$scriptLocation/0.ps1"              = "0.ps1";
  "$scriptLocation/1.ps1"              = "1.ps1";
  "$scriptLocation/deployazcli.ps1"    = "deployazcli.ps1";
  "$scriptLocation/deploymoc.ps1"      = "deploymoc.ps1";
}

foreach ($script in $scriptToExecute.GetEnumerator()) {
  $scriptUrl = $script.Key
  $scriptName = $script.Value
  $deploymentName = "executescript-$($vmName)-$($scriptName.Replace('.ps1',''))"
  $commandToExecute = "powershell.exe -ExecutionPolicy Unrestricted -File $scriptName"
  Write-Host "Executing $scriptName from $scriptUrl on VM $vmName ..."
  try {
    az deployment group create --name $deploymentName --resource-group $GroupName --template-file ./configuration/executescript-template.json --parameters location=$Location vmName=$vmName scriptFileUri=$scriptUrl commandToExecute=$commandToExecute
    if ($LASTEXITCODE -ne 0) {
      Invoke-StepFailure -StepName "ExecuteScript_$scriptName" -ExitCode $LASTEXITCODE `
        -ErrorText "Failed to execute script '$scriptName' on VM '$vmName'. Azure CLI command failed with exit code $LASTEXITCODE"
    }
    $executionStatus.CompletedSteps += "ExecuteScript_$scriptName"
  }
  catch {
    Write-Error "An error occurred during AKS Arc cluster deployment: $_"
    Write-Error "Exception details: $($_.Exception.Message)"
    Write-Error "Stack trace: $($_.ScriptStackTrace)"
    Invoke-StepFailure -StepName "ExecuteScript_$scriptName" `
      -ErrorText "An error occurred during script execution: $_"
  }
}

Write-Host "Login to the VM using Bastion or RDP. Wait for MOC install to finish. Then continue with aksarc deployment by running the script deployaksarc.ps1."

# Final execution status - Success
$executionStatus.Status = "Success"
Write-ExecutionStatus