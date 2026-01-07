param(
    [string]$resource_group = "jumpstart-rg",
    [string]$appliance_name = "aks_arc_appliance",
    [string] $workDirectory,
    [string] $location = "southeastasia",
    [string] $subscription,
    [switch] $useLockdown
)

if ([string]::IsNullOrEmpty($workDirectory)) {
    $workDirectory = "$env:WorkingDir"
}
Start-Transcript -Path "$env:LogDirectory\deployappliance.ps1.log" -Append

$VerbosePreference = "Continue"


md $workDirectory -ErrorAction SilentlyContinue
# Below dns server is used from Corp
if ($useLockdown) {
    Write-Host "Configuring appliance with proxy settings for network isolation..."
    New-ArcHciAksConfigFiles -subscriptionID $subscription -location $location -resourceGroup $resource_group `
        -resourceName $appliance_name -workDirectory $workDirectory -vnetName "appliance-vnet" `
        -vSwitchName "InternalNAT" -gateway "172.16.0.1" -dnsservers "172.16.0.1" -ipaddressprefix "172.16.0.0/16" `
        -k8snodeippoolstart "172.16.255.0" -k8snodeippoolend "172.16.255.12" -controlPlaneIP "172.16.255.250" `
        -proxyServerHTTP "10.0.1.4:8080" -proxyServerHTTPS "10.0.1.4:8443" -proxyServerNoProxy "localhost,127.0.0.1,.svc,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
} else {
    Write-Host "Configuring appliance without proxy settings..."
    New-ArcHciAksConfigFiles -subscriptionID $subscription -location $location -resourceGroup $resource_group `
        -resourceName $appliance_name -workDirectory $workDirectory -vnetName "appliance-vnet" `
        -vSwitchName "InternalNAT" -gateway "172.16.0.1" -dnsservers "172.16.0.1" -ipaddressprefix "172.16.0.0/16" `
        -k8snodeippoolstart "172.16.255.0" -k8snodeippoolend "172.16.255.12" -controlPlaneIP "172.16.255.250"
}

$configFilePath = $workDirectory + "\hci-appliance.yaml"

az login --identity
az account set -s $subscription
az arcappliance prepare hci --config-file $configFilePath
az arcappliance deploy hci --config-file $configFilePath --outfile $workDirectory\kubeconfig
az arcappliance create hci --config-file $configFilePath --kubeconfig $workDirectory\kubeconfig

Stop-Transcript