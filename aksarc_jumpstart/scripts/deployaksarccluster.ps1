param(
    [string]$resource_group = "jumpstart-rg",
    [string] $aksArcClusterName,
    [string] $lnetName,
    [string] $customLocationName,
    [string] $subscription
)

Start-Transcript -Path "$env:LogDirectory\deployaksarccluster.ps1.log" -Append
$ErrorActionPreference = "Stop"
try {
    Write-Host "Logging into Azure with managed identity..."
    az login --identity
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to login to Azure with managed identity. Exit code: $LASTEXITCODE"
    }

    az account set -s $subscription
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to set Azure subscription. Exit code: $LASTEXITCODE"
    }

    Write-Host "Getting custom location ID..."
    $clId = az customlocation show --name $customLocationName --resource-group $resource_group --query "id" -o tsv
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to get custom location ID. Exit code: $LASTEXITCODE"
    }

    Write-Host "Getting logical network ID..."
    $lnetId = az stack-hci-vm network lnet show --name $lnetName -g $resource_group --query id -o tsv
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to get logical network ID. Exit code: $LASTEXITCODE"
    }

    Write-Host "Creating AKS Arc cluster..."
    az aksarc create --name $aksArcClusterName --resource-group $resource_group --custom-location $clId --vnet-ids $lnetId --generate-ssh-keys
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create AKS Arc cluster. Exit code: $LASTEXITCODE"
    }

    Write-Host "AKS Arc cluster deployment completed successfully."
}
catch {
    Write-Error "An error occurred during AKS Arc cluster deployment: $_"
    Write-Error "Exception details: $($_.Exception.Message)"
    Write-Error "Stack trace: $($_.ScriptStackTrace)"
    throw
}
finally {
    Stop-Transcript
}