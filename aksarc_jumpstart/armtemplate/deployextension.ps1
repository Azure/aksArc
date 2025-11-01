
$releaseTrain = "prerelease"
$defaultNamespace = "default"
$extensionType = "Microsoft.AZStackHCI.Operator"
$extensionName = "vmss-hci"
$mocConfigFilePath = ($workDirectory + "\hci-config.json")
ipmo archci
New-ArcHciIdentityFiles

## The current pairing is cli: 1.2.3 k8s extension: 5.2.5
az k8s-extension create -g $resource_group -c $appliance_name --cluster-type appliances --name $extensionName  `
    --extension-type $extensionType --release-train $releaseTrain `
    --scope cluster --release-namespace helm-operator2 --configuration-settings Microsoft.CustomLocation.ServiceAccount=$defaultNamespace infraCheck=false `
    --config-protected-file $mocConfigFilePath --auto-upgrade $false --version 5.2.5

$extName = "aksarc-hci"; $defaultNamespace = "default"; $extensionType = "Microsoft.HybridAKSOperator"

az k8s-extension create -g $resource_group -c $appliance_name --cluster-type appliances --name $extName --auto-upgrade-minor-version false --extension-type Microsoft.HybridAKSOperator --release-train  "stable" --config Microsoft.CustomLocation.ServiceAccount=$defaultNamespace --auto-upgrade $true # --version "1.0.36"

$ClusterExtensionResourceId=az k8s-extension show -g $resource_group -c $appliance_name --cluster-type appliances --name $extName --query id -o tsv

$customLocationName = ($appliance_name + "-hybridaks-cl")
az customlocation create -g $resource_group -n $customLocationName -l $location --namespace "default" --host-resource-id $ArcApplianceResourceId --cluster-extension-ids $ClusterExtensionResourceId
$clId = az customlocation show --name $customLocationName --resource-group $resource_group --query "id" -o tsv