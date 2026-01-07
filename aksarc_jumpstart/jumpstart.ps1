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
  [Parameter()]
  [string]
  $Location = "eastus2",
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
  $subscriptionId,
  [Parameter()]
  [switch]
  $lockdown
)

# Create Resource Group
az group create --name $GroupName --location $Location 
# Create Vnet and VM
if ($lockdown) {
  Write-Host "Deploying with firewall and network isolation..."
  az deployment group create --resource-group $GroupName --template-file ./configuration/vnet-fw-rt-template.json --parameters location=$Location vnetName=$vnetName vNetAddressPrefix="10.0.0.0/16" subnetName=$subnetName subnetPrefix="10.0.0.0/24" firewallSubnetPrefix="10.0.1.0/26" bastionSubnetPrefix="10.0.2.0/26" nsgName="$($vnetName)-nsg" firewallName="$($vnetName)-firewall" firewallPolicyName="$($vnetName)-firewall-policy" routeTableName="$($vnetName)-rt" bastionName="$($vnetName)-bastion" bastionPublicIpName="$($vnetName)-bastion-pip"
} else {
  Write-Host "Deploying with standard network configuration..."
  az deployment group create --resource-group $GroupName --template-file ./configuration/vnet-template.json --parameters location=$Location vnetName=$vnetName subnetName=$subnetName
}
az deployment group create --resource-group $GroupName --template-file ./configuration/vm-template.json --parameters adminUsername=$userName adminPassword=$password vmName=$vmName location=$Location vnetName=$vnetName vmSize="Standard_E16s_v4" subnetName=$subnetName

if ($LASTEXITCODE -ne 0) {
  Write-Host "Azure CLI command failed with exit code $LASTEXITCODE"
  exit $LASTEXITCODE
}

# Assign Managed Identity and Contributor Role to VM
az vm identity assign --resource-group $GroupName --name $vmName
$principalId = az vm show --resource-group $GroupName --name $vmName --query identity.principalId -o tsv
az role assignment create --assignee $principalId --role Contributor --scope /subscriptions/$subscriptionId

az deployment group create --resource-group $GroupName --template-file a4s-template.json --parameters location=$Location vmName=$vmName arcResourceGroup=$GroupName subscriptionId=$subscriptionId tenantId=$tenantId
# Enable Nested Virtualization
az vm update   --resource-group $GroupName   --name $vmName --set additionalCapabilities.enableNestedVirtualization=true

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
  az deployment group create --name $deploymentName --resource-group $GroupName --template-file ./configuration/executescript-template.json --parameters location=$Location vmName=$vmName scriptFileUri=$scriptUrl commandToExecute=$commandToExecute
  if ($LASTEXITCODE -ne 0) {
    Write-Host "Azure CLI command failed with exit code $LASTEXITCODE"
    exit $LASTEXITCODE
  }
}

Write-Host "Login to the VM using Bastion or RDP. Wait for MOC install to finish. Then continue with aksarc deployment by running the script deployaksarc.ps1."