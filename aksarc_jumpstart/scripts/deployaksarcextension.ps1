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

Start-Transcript -Path "$env:LogDirectory\deployaksarcextension.ps1.log" -Append
# $ErrorActionPreference = "Stop"
try {
    $release_train = "stable"
    $aksarcversion = "4.0.69"
    $aksarcExtName = "hybridaksextension"

    Write-Host "Importing ArcHci module..."
    ipmo ((Get-Module "ArcHci" -ListAvailable | Sort-Object Version -Descending)[0].ModuleBase + "\ArcHci.psm1")

    $azCloudContext = $(az cloud show | ConvertFrom-Json)
    $aksExtensionConfigFileName = "aks-extension-config.json"
    $aksExtensionConfigFilePath = join-path $workDirectory $aksExtensionConfigFileName

    Write-Host "Adding extension configuration to file..."
    Add-ExtensionConfigToFile -configFilePath $aksExtensionConfigFilePath -key "Microsoft.CustomLocation.ServiceAccount" -value "default"

    Write-Host "Logging into Azure with managed identity..."
    az login --identity
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to login to Azure with managed identity. Exit code: $LASTEXITCODE"
    }

    az account set -s $subscription
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to set Azure subscription. Exit code: $LASTEXITCODE"
    }

    Write-Host "Creating k8s-extension for AKS Arc..."
    az k8s-extension create -g $resource_group -c $appliance_name --cluster-type appliances --name $aksarcExtName `
      --extension-type Microsoft.HybridAKSOperator --config-file $aksExtensionConfigFilePath `
      --release-train $release_train --version $aksarcversion --auto-upgrade-minor-version $false

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create k8s-extension. Exit code: $LASTEXITCODE"
    }

    Write-Host "AKS Arc extension deployment completed successfully."
}
catch {
    Write-Error "An error occurred during AKS Arc extension deployment: $_"
    Write-Error "Exception details: $($_.Exception.Message)"
    Write-Error "Stack trace: $($_.ScriptStackTrace)"
    throw
}
finally {
    Stop-Transcript
}