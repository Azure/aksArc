param(
  [string]$resource_group = "jumpstart-rg",
  [string]$appliance_name = "aks_arc_appliance",
  [string] $workDirectory = "E:\AKSArc",
  [string] $location = "eastus2",
  [string] $subscription
)

Start-Transcript -Path "E:\log\deployvmssextension.ps1.log" -Append
$release_train = "stable"
$arcvmversion = "5.12.10"
$arcvmExtName = "vmss-hci"

Import-Module ((Get-Module "ArcHci" -ListAvailable | Sort-Object Version -Descending)[0].ModuleBase + "\ArcHci.psm1")

$vmExtensionConfigFileName = "vm-extension-config.json"
$vmExtensionConfigFilePath = join-path $workDirectory $vmExtensionConfigFileName

Add-ExtensionConfigToFile -configFilePath $vmExtensionConfigFilePath -key "Microsoft.CustomLocation.ServiceAccount" -value "default"
Add-ExtensionConfigToFile -configFilePath $vmExtensionConfigFilePath -key "infraCheck" -value "false"


az login --identity
az account set -s $subscription
Import-Module ArcHci 

$mocConfigFilePath = join-path $workDirectory "\hci-config.json"
New-ArcHciIdentityFiles -workDirectory $workDirectory

az k8s-extension create -g $resource_group -c $appliance_name --cluster-type appliances --name $arcvmExtName `
  --extension-type Microsoft.AZStackHCI.Operator --scope cluster --release-namespace helm-operator2 `
  --config-protected-file $mocConfigFilePath --config-file $vmExtensionConfigFilePath `
  --release-train $release_train --version $arcvmversion --auto-upgrade-minor-version $false
Stop-Transcript