param(
    [string]$resource_group = "jumpstart-rg",
    [string]$appliance_name = "aks_arc_appliance",
    [string] $workDirectory,
    [string] $location = "eastus",
    [string] $subscription
)

if ([string]::IsNullOrEmpty($workDirectory)) {
    $workDirectory = "$env:WorkingDir"
}
Start-Transcript -Path "$env:LogDirectory\deployappliance.ps1.log" -Append
$ErrorActionPreference = "Stop"
try {
    $VerbosePreference = "Continue"

    Write-Host "Creating work directory..."
    md $workDirectory -ErrorAction SilentlyContinue

    Write-Host "Creating Arc HCI AKS configuration files..."
    # Below dns server is used from Corp
    New-ArcHciAksConfigFiles -subscriptionID $subscription -location $location -resourceGroup $resource_group `
        -resourceName $appliance_name -workDirectory $workDirectory -vnetName "appliance-vnet" `
        -vSwitchName "InternalNAT" -gateway "172.16.0.1" -dnsservers "172.16.0.1" -ipaddressprefix "172.16.0.0/16" `
        -k8snodeippoolstart "172.16.255.0" -k8snodeippoolend "172.16.255.12" -controlPlaneIP "172.16.255.250"

    $configFilePath = $workDirectory + "\hci-appliance.yaml"

    Write-Host "Logging into Azure with managed identity..."
    az login --identity
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to login to Azure with managed identity. Exit code: $LASTEXITCODE"
    }

    az account set -s $subscription
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to set Azure subscription. Exit code: $LASTEXITCODE"
    }

    Write-Host "Preparing Arc appliance..."
    az arcappliance prepare hci --config-file $configFilePath
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to prepare Arc appliance. Exit code: $LASTEXITCODE"
    }

    Write-Host "Deploying Arc appliance..."
    az arcappliance deploy hci --config-file $configFilePath --outfile $workDirectory\kubeconfig
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to deploy Arc appliance. Exit code: $LASTEXITCODE"
    }

    Write-Host "Creating Arc appliance..."
    az arcappliance create hci --config-file $configFilePath --kubeconfig $workDirectory\kubeconfig
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create Arc appliance. Exit code: $LASTEXITCODE"
    }

    Write-Host "Arc appliance deployment completed successfully."
}
catch {
    Write-Error "An error occurred during Arc appliance deployment: $_"
    Write-Error "Exception details: $($_.Exception.Message)"
    Write-Error "Stack trace: $($_.ScriptStackTrace)"
    throw
}
finally {
    Stop-Transcript
}