param(
    [string]$resource_group = "jumpstart-rg",
    [string]$aksArcClusterName,
    [string]$lnetName,
    [string]$customLocationName,
    [string]$subscription
)

Start-Transcript -Path "$env:LogDirectory\deployaksarccluster.ps1.log" -Append

try {
    az login --identity
    if ($LASTEXITCODE -ne 0) { throw "Failed to login. Exit code: $LASTEXITCODE" }
    az account set -s $subscription
    if ($LASTEXITCODE -ne 0) { throw "Failed to set subscription. Exit code: $LASTEXITCODE" }

    $clId = az customlocation show --name $customLocationName --resource-group $resource_group --query "id" -o tsv
    if ($LASTEXITCODE -ne 0) { throw "Failed to get custom location ID. Exit code: $LASTEXITCODE" }

    $lnetId = az stack-hci-vm network lnet show --name $lnetName -g $resource_group --query id -o tsv
    if ($LASTEXITCODE -ne 0) { throw "Failed to get logical network ID. Exit code: $LASTEXITCODE" }

    Write-Host "Creating AKS Arc cluster '$aksArcClusterName'..."
    az aksarc create --name $aksArcClusterName --resource-group $resource_group --custom-location $clId --vnet-ids $lnetId --generate-ssh-keys
    if ($LASTEXITCODE -ne 0) { throw "Failed to create AKS Arc cluster. Exit code: $LASTEXITCODE" }

    Write-Host "AKS Arc cluster deployed successfully."
}
catch {
    Write-Error "AKS Arc cluster deployment failed: $_"
    throw
}
finally {
    Stop-Transcript
}
