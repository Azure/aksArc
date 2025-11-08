param(
    [string]$resource_group = "jumpstart-rg",
    [string] $location,
    [string] $lnetName,
    [string] $customLocationName,
    [string] $subscription
)

Start-Transcript -Path "E:\log\deploylnet.ps1.log" -Append

$ipAllocationMethod = "Static"  
$vmSwitchName = "InternalNAT"  
$addressPrefix = "172.16.0.0/16"  
$dnsServers = "172.16.0.1"  
$gateway = "172.16.0.1"  
$vlan = "0"  
$ipPoolStart = "172.16.0.10"  
$ipPoolEnd = "172.16.0.254"  
$suffix = "jumpstart"

# if $dnsServers is comma sperated string, get first value out of string
if ($dnsServers.Contains(",")) {
    $dnsServers = $dnsServers.Split(",")[0]
}

az login --identity
az account set -s $subscription

$clId = az customlocation show --name $customLocationName --resource-group $resource_group --query "id" -o tsv

az stack-hci-vm network lnet create --subscription $subscription --resource-group $resource_group --custom-location $clId --location $location --name $lnetName --ip-allocation-method $ipAllocationMethod --address-prefix $addressPrefix --dns-servers $dnsServers --gateway $gateway --vlan $vlan --ip-pool-start $ipPoolStart --ip-pool-end $ipPoolEnd --vm-switch-name `"$vmSwitchName`"
$lnetId = az stack-hci-vm network lnet show --name $lnetName -g $resource_group --query id -o tsv
Stop-Transcript