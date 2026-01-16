param(
    [string]$resource_group = "jumpstart-rg",
    [string] $location,
    [string] $lnetName,
    [string] $customLocationName,
    [string] $subscription
)

Start-Transcript -Path "$env:LogDirectory\deploylnet.ps1.log" -Append
# $ErrorActionPreference = "Stop"
try {
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

    Write-Host "Creating logical network..."
    az stack-hci-vm network lnet create --subscription $subscription --resource-group $resource_group --custom-location $clId --location $location --name $lnetName --ip-allocation-method $ipAllocationMethod --address-prefix $addressPrefix --dns-servers $dnsServers --gateway $gateway --vlan $vlan --ip-pool-start $ipPoolStart --ip-pool-end $ipPoolEnd --vm-switch-name `"$vmSwitchName`"
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create logical network. Exit code: $LASTEXITCODE"
    }

    Write-Host "Retrieving logical network ID..."
    $lnetId = az stack-hci-vm network lnet show --name $lnetName -g $resource_group --query id -o tsv
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to retrieve logical network ID. Exit code: $LASTEXITCODE"
    }

    Write-Host "Logical network deployment completed successfully. LNet ID: $lnetId"
}
catch {
    Write-Error "An error occurred during logical network deployment: $_"
    Write-Error "Exception details: $($_.Exception.Message)"
    Write-Error "Stack trace: $($_.ScriptStackTrace)"
    throw
}
finally {
    Stop-Transcript
}