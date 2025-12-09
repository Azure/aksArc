param(
    [string]$resource_group = "jumpstart-rg",
    [string]$appliance_name = "aks_arc_appliance",
    [string] $workDirectory,
    [string] $location = "southeastasia",
    [string] $subscription
)

if ([string]::IsNullOrEmpty($workDirectory)) {
    $workDirectory = "$env:WorkingDir"
}

Start-Transcript -Path "$env:LogDirectory\deployaksarcextension.ps1.log" -Append
$release_train = "stable"
$aksarcversion = "4.0.69"
$aksarcExtName = "hybridaksextension"

ipmo ((Get-Module "ArcHci" -ListAvailable | Sort-Object Version -Descending)[0].ModuleBase + "\ArcHci.psm1")

$azCloudContext = $(az cloud show | ConvertFrom-Json)
$aksExtensionConfigFileName = "aks-extension-config.json"
$aksExtensionConfigFilePath = join-path $workDirectory $aksExtensionConfigFileName

Add-ExtensionConfigToFile -configFilePath $aksExtensionConfigFilePath -key "Microsoft.CustomLocation.ServiceAccount" -value "default"

az login --identity
az account set -s $subscription

az k8s-extension create -g $resource_group -c $appliance_name --cluster-type appliances --name $aksarcExtName `
  --extension-type Microsoft.HybridAKSOperator --config-file $aksExtensionConfigFilePath `
  --release-train $release_train --version $aksarcversion --auto-upgrade-minor-version $false

Stop-Transcript