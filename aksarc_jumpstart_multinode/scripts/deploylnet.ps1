param(
    [string]$resource_group = "jumpstart-rg",
    [string]$location,
    [string]$lnetName,
    [string]$customLocationName,
    [string]$subscription
)

Start-Transcript -Path "$env:LogDirectory\deploylnet.ps1.log" -Append

try {
    $ipAllocationMethod = "Static"
    $vmSwitchName = "ExternalSwitch"
    $addressPrefix = "10.0.0.0/24"
    $dnsServers = "8.8.8.8"
    $gateway = "10.0.0.1"
    $vlan = "0"
    $ipPoolStart = "10.0.0.10"
    $ipPoolEnd = "10.0.0.30"

    az login --identity
    if ($LASTEXITCODE -ne 0) { throw "Failed to login. Exit code: $LASTEXITCODE" }
    az account set -s $subscription
    if ($LASTEXITCODE -ne 0) { throw "Failed to set subscription. Exit code: $LASTEXITCODE" }

    $clId = az customlocation show --name $customLocationName --resource-group $resource_group --query "id" -o tsv
    if ($LASTEXITCODE -ne 0) { throw "Failed to get custom location ID. Exit code: $LASTEXITCODE" }

    Write-Host "Creating logical network '$lnetName'..."
    az stack-hci-vm network lnet create --subscription $subscription --resource-group $resource_group --custom-location $clId `
        --location $location --name $lnetName --ip-allocation-method $ipAllocationMethod --address-prefix $addressPrefix `
        --dns-servers $dnsServers --gateway $gateway --vlan $vlan --ip-pool-start $ipPoolStart --ip-pool-end $ipPoolEnd `
        --vm-switch-name `"$vmSwitchName`"
    if ($LASTEXITCODE -ne 0) { throw "Failed to create logical network. Exit code: $LASTEXITCODE" }

    $lnetId = az stack-hci-vm network lnet show --name $lnetName -g $resource_group --query id -o tsv
    Write-Host "Logical network created. ID: $lnetId"
}
catch {
    Write-Error "Logical network deployment failed: $_"
    throw
}
finally {
    Stop-Transcript
}
