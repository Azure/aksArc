param(
    [string] $resource_group = "jumpstart-rg",
    [string] $aksArcClusterName,
    [string] $lnetName,
    [string] $customLocationName,
    [string] $subscription,
    [string] $additionalParameters = "--generate-ssh-keys"
)

Start-Transcript -Path "E:\log\deployaksarccluster.ps1.log" -Append

az login --identity
az account set -s $subscription

$clId = az customlocation show --name $customLocationName --resource-group $resource_group --query "id" -o tsv

$lnetId = az stack-hci-vm network lnet show --name $lnetName -g $resource_group --query id -o tsv

# Remove any surrounding quotes from additionalParameters if present
$cleanParams = $additionalParameters.Trim("'").Trim('"')

# Split parameters and build argument array
$paramArray = $cleanParams -split '\s+'
$azCommand = @('aksarc', 'create', '--name', $aksArcClusterName, '--resource-group', $resource_group, '--custom-location', $clId, '--vnet-ids', $lnetId) + $paramArray

& az @azCommand

Stop-Transcript
