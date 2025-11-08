param(
    [string]$resource_group = "test-rg",
    [string] $aksArcClusterName,
    [string] $lnetName,
    [string] $customLocationName,
    [string] $subscription
)

Start-Transcript -Path "E:\log\deployaksarccluster.ps1.log" -Append

az login --identity
az account set -s $subscription

$clId = az customlocation show --name $customLocationName --resource-group $resource_group --query "id" -o tsv

$lnetId = az stack-hci-vm network lnet show --name $lnetName -g $resource_group --query id -o tsv
az aksarc create --name $aksArcClusterName --resource-group $resource_group --custom-location $clId --vnet-ids $lnetId  --generate-ssh-keys

Stop-Transcript