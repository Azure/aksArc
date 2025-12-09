param(
    [string]$resource_group = "matt-aksarc-demo-rg",
    [string]$appliance_name = "jumpstartVM-appliance",
    [string] $subscription,
    [string] $customLocationName,
    [string] $location
)

Start-Transcript -Path "E:\log\deploycustomlocation.ps1.log" -Append

$aksarcExtName = "hybridaksextension"
$arcvmExtName = "vmss-hci"

$ArcApplianceResourceId=az arcappliance show -g $resource_group -n $appliance_name --query id -o tsv

$AksarcClusterExtensionResourceId=az k8s-extension show -g $resource_group -c $appliance_name --cluster-type appliances --name $aksarcExtName --query id -o tsv
$ArcvmClusterExtensionResourceId=az k8s-extension show -g $resource_group -c $appliance_name --cluster-type appliances --name $arcvmExtName --query id -o tsv

az login --identity
az account set -s $subscription

az customlocation create -g $resource_group -n $customLocationName --namespace "default" --host-resource-id $ArcApplianceResourceId --cluster-extension-ids $AksarcClusterExtensionResourceId $ArcvmClusterExtensionResourceId --location $location

$clId = az customlocation show --name $customLocationName --resource-group $resource_group --query "id" -o tsv
Stop-Transcript