param(
    [string]$resource_group = "jumpstart-rg",
    [string]$appliance_name = "aks_arc_appliance",
    [string] $subscription,
    [string] $customLocationName
)

Start-Transcript -Path "$env:LogDirectory\deploycustomlocation.ps1.log" -Append
# $ErrorActionPreference = "Stop"
try {
    $aksarcExtName = "hybridaksextension"
    $arcvmExtName = "vmss-hci"

    Write-Host "Getting Arc Appliance resource ID..."
    $ArcApplianceResourceId = az arcappliance show -g $resource_group -n $appliance_name --query id -o tsv
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to get Arc Appliance resource ID. Exit code: $LASTEXITCODE"
    }

    Write-Host "Getting AKS Arc cluster extension resource ID..."
    $AksarcClusterExtensionResourceId = az k8s-extension show -g $resource_group -c $appliance_name --cluster-type appliances --name $aksarcExtName --query id -o tsv
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to get AKS Arc cluster extension resource ID. Exit code: $LASTEXITCODE"
    }

    Write-Host "Getting Arc VM cluster extension resource ID..."
    $ArcvmClusterExtensionResourceId = az k8s-extension show -g $resource_group -c $appliance_name --cluster-type appliances --name $arcvmExtName --query id -o tsv
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to get Arc VM cluster extension resource ID. Exit code: $LASTEXITCODE"
    }

    Write-Host "Logging into Azure with managed identity..."
    az login --identity
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to login to Azure with managed identity. Exit code: $LASTEXITCODE"
    }

    az account set -s $subscription
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to set Azure subscription. Exit code: $LASTEXITCODE"
    }

    Write-Host "Creating custom location..."
    az customlocation create -g $resource_group -n $customLocationName --namespace "default" --host-resource-id $ArcApplianceResourceId --cluster-extension-ids $AksarcClusterExtensionResourceId $ArcvmClusterExtensionResourceId
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create custom location. Exit code: $LASTEXITCODE"
    }

    Write-Host "Retrieving custom location ID..."
    $clId = az customlocation show --name $customLocationName --resource-group $resource_group --query "id" -o tsv
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to retrieve custom location ID. Exit code: $LASTEXITCODE"
    }

    Write-Host "Custom location deployment completed successfully. Custom Location ID: $clId"
}
catch {
    Write-Error "An error occurred during custom location deployment: $_"
    Write-Error "Exception details: $($_.Exception.Message)"
    Write-Error "Stack trace: $($_.ScriptStackTrace)"
    throw
}
finally {
    Stop-Transcript
}