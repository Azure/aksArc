param(
    [string]$resource_group = "test-rg",
    [string]$appliance_name = "aks_arc_appliance",
    [string] $workDirectory = "E:\AKSArc",
    [string] $location = "eastus2",
    [string] $subscription
)

Start-Transcript -Path "E:\log\deploycustomlocation.ps1.log" -Append
$releaseTrain = "prerelease"
$defaultNamespace = "default"
$extensionType = "Microsoft.AZStackHCI.Operator"
$extensionName = "vmss-hci"
$mocConfigFilePath = ($workDirectory + "\hci-config.json")
$release_train = "stable"
$aksarcversion = "4.0.69"
$aksarcExtName = "hybridaksextension"
$customLocationName = ($appliance_name + "-hybridaks-cl")

$ArcApplianceResourceId=az arcappliance show -g $resource_group -n $appliance_name --query id -o tsv

$AksarcClusterExtensionResourceId=az k8s-extension show -g $resource_group -c $appliance_name --cluster-type appliances --name $aksarcExtName --query id -o tsv
# $ArcvmClusterExtensionResourceId=az k8s-extension show -g $resource_group -c $appliance_name --cluster-type appliances --name $arcvmExtName --query id -o tsv

az login --identity
az account set -s $subscription

az customlocation create -g $resource_group -n $customLocationName --namespace "default" --host-resource-id $ArcApplianceResourceId --cluster-extension-ids $AksarcClusterExtensionResourceId # $ArcvmClusterExtensionResourceId

$clId = az customlocation show --name $customLocationName --resource-group $resource_group --query "id" -o tsv
Stop-Transcript