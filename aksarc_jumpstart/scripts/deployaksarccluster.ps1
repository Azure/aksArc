param(
    [string]$resource_group = "test-rg",
    [param(Mandatory=$true)]
    [string] $lnetName,
    [param(Mandatory=$true)]
    [string] $customLocationName,
    [param(Mandatory=$true)]
    [string] $subscription
)

Start-Transcript -Path "E:\log\deploylnet.ps1.log" -Append

$suffix = "jumpstart"

az login --identity
az account set -s $subscription

$clId = az customlocation show --name $customLocationName --resource-group $resource_group --query "id" -o tsv

$lnetId = az stack-hci-vm network lnet show --name $lnetName -g $resource_group --query id -o tsv
az aksarc create --name "test-cluster-$suffix" --resource-group $resource_group --custom-location $clId --vnet-ids $lnetId  --generate-ssh-keys

Stop-Transcript