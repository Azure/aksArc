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

. "$PSScriptRoot/status-reporting.ps1"
Initialize-ExecutionStatus -ScriptName 'jumpstart.ps1'

# Create Resource Group
az group create --name $GroupName --location $Location
if ($LASTEXITCODE -ne 0) {
  Invoke-StepFailure -StepName "CreateResourceGroup" -ExitCode $LASTEXITCODE `
    -ErrorText "Failed to create resource group '$GroupName' in location '$Location'. Azure CLI command failed with exit code $LASTEXITCODE"
}
Add-CompletedStep -StepName "CreateResourceGroup"

# Create Vnet and VM
az deployment group create --resource-group $GroupName --template-file ./configuration/vnet-template.json --parameters vnetName=$vnetName location=$Location subnetName=$subnetName
if ($LASTEXITCODE -ne 0) {
  Invoke-StepFailure -StepName "CreateVirtualNetwork" -ExitCode $LASTEXITCODE `
    -ErrorText "Failed to create virtual network '$vnetName' and subnet '$subnetName'. Azure CLI command failed with exit code $LASTEXITCODE"
}
Add-CompletedStep -StepName "CreateVirtualNetwork"

az deployment group create --resource-group $GroupName --template-file ./configuration/vm-template.json --parameters adminUsername=$userName adminPassword=$password vmName=$vmName location=$Location vnetName=$vnetName vmSize="Standard_E16s_v4" subnetName=$subnetName
if ($LASTEXITCODE -ne 0) {
  Invoke-StepFailure -StepName "CreateVirtualMachine" -ExitCode $LASTEXITCODE `
    -ErrorText "Failed to create virtual machine '$vmName'. Azure CLI command failed with exit code $LASTEXITCODE"
}
Add-CompletedStep -StepName "CreateVirtualMachine"

# Assign Managed Identity and Contributor Role to VM
az vm identity assign --resource-group $GroupName --name $vmName
if ($LASTEXITCODE -ne 0) {
  Invoke-StepFailure -StepName "AssignManagedIdentity" -ExitCode $LASTEXITCODE `
    -ErrorText "Failed to assign managed identity to VM '$vmName'. Azure CLI command failed with exit code $LASTEXITCODE"
}
Add-CompletedStep -StepName "AssignManagedIdentity"
$principalId = az vm show --resource-group $GroupName --name $vmName --query identity.principalId -o tsv
az role assignment create --assignee $principalId --role Contributor --scope /subscriptions/$subscriptionId
if ($LASTEXITCODE -ne 0) {
  Invoke-StepFailure -StepName "AssignContributorRole" -ExitCode $LASTEXITCODE `
    -ErrorText "Failed to assign Contributor role to VM identity. Azure CLI command failed with exit code $LASTEXITCODE"
}
Add-CompletedStep -StepName "AssignContributorRole"

#az deployment group create --resource-group $GroupName --template-file a4s-template.json --parameters location=$Location vmName=$vmName arcResourceGroup=$GroupName subscriptionId=$subscriptionId tenantId=$tenantId
# Enable Nested Virtualization
az vm update   --resource-group $GroupName   --name $vmName --set additionalCapabilities.enableNestedVirtualization=true
if ($LASTEXITCODE -ne 0) {
  Invoke-StepFailure -StepName "EnableNestedVirtualization" -ExitCode $LASTEXITCODE `
    -ErrorText "Failed to enable nested virtualization on VM '$vmName'. Azure CLI command failed with exit code $LASTEXITCODE"
}
Add-CompletedStep -StepName "EnableNestedVirtualization"

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
  Invoke-VmScriptDeployment `
    -StepName       "ExecuteScript_$scriptName" `
    -ResourceGroup  $GroupName `
    -Location       $Location `
    -VmName         $vmName `
    -ScriptFileUri  $scriptUrl `
    -InnerScript    $scriptName
}

Write-Host "Login to the VM using Bastion or RDP. Wait for MOC install to finish. Then continue with aksarc deployment by running the script deployaksarc.ps1."

# Final execution status - Success
$script:ExecutionStatus.Status = "Success"
Write-ExecutionStatus