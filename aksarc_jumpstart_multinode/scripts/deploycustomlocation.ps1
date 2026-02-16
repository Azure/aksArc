param(
    [string]$resource_group = "jumpstart-rg",
    [string]$appliance_name = "jumpstart-appliance",
    [string]$subscription,
    [string]$customLocationName
)

Start-Transcript -Path "$env:LogDirectory\deploycustomlocation.ps1.log" -Append

try {
    $aksarcExtName = "hybridaksextension"
    $arcvmExtName = "vmss-hci"

    $ArcApplianceResourceId = az arcappliance show -g $resource_group -n $appliance_name --query id -o tsv
    if ($LASTEXITCODE -ne 0) { throw "Failed to get appliance ID. Exit code: $LASTEXITCODE" }

    $AksarcClusterExtensionResourceId = az k8s-extension show -g $resource_group -c $appliance_name --cluster-type appliances --name $aksarcExtName --query id -o tsv
    if ($LASTEXITCODE -ne 0) { throw "Failed to get AKS extension ID. Exit code: $LASTEXITCODE" }

    $ArcvmClusterExtensionResourceId = az k8s-extension show -g $resource_group -c $appliance_name --cluster-type appliances --name $arcvmExtName --query id -o tsv
    if ($LASTEXITCODE -ne 0) { throw "Failed to get VM extension ID. Exit code: $LASTEXITCODE" }

    az login --identity
    if ($LASTEXITCODE -ne 0) { throw "Failed to login. Exit code: $LASTEXITCODE" }
    az account set -s $subscription
    if ($LASTEXITCODE -ne 0) { throw "Failed to set subscription. Exit code: $LASTEXITCODE" }

    Write-Host "Creating custom location '$customLocationName'..."
    az customlocation create -g $resource_group -n $customLocationName --namespace "default" --host-resource-id $ArcApplianceResourceId --cluster-extension-ids $AksarcClusterExtensionResourceId $ArcvmClusterExtensionResourceId
    if ($LASTEXITCODE -ne 0) { throw "Failed to create custom location. Exit code: $LASTEXITCODE" }

    $clId = az customlocation show --name $customLocationName --resource-group $resource_group --query "id" -o tsv
    Write-Host "Custom location created. ID: $clId"
}
catch {
    Write-Error "Custom location deployment failed: $_"
    throw
}
finally {
    Stop-Transcript
}
