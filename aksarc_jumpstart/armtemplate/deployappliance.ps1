$VerbosePreference = "Continue"
$location = "eastus"
$resource_group = "madhanm-test"
$appliance_name = "madhanm-dev"
$workDirectory = "E:\HybridAKS"

md $workDirectory -ErrorAction SilentlyContinue

# Below dns server is used from Corp
New-ArcHciAksConfigFiles -subscriptionID $subscription -location $location -resourceGroup $resource_group -resourceName $appliance_name -workDirectory $workDirectory -vnetName "appliance-vnet" -vSwitchName "Default Switch" -gateway "172.16.0.1" -dnsservers "10.50.10.50" -ipaddressprefix "172.16.0.0/16" -k8snodeippoolstart "172.16.255.0" -k8snodeippoolend "172.16.255.12" -controlPlaneIP "172.16.255.250"

$configFilePath = $workDirectory + "\hci-appliance.yaml"
az arcappliance prepare hci --config-file $configFilePath
az arcappliance deploy hci --config-file $configFilePath --outfile $workDirectory\kubeconfig
az arcappliance create hci --config-file $configFilePath --kubeconfig $workDirectory\kubeconfig


$ArcApplianceResourceId=az arcappliance show -g $resource_group -n $appliance_name --query id -o tsv