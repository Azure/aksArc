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
Start-Transcript -Path "$env:LogDirectory\deployvmssextension.ps1.log" -Append
$ErrorActionPreference = "Stop"

try {
    $release_train = "stable"
    $arcvmversion = "5.12.10"
    $arcvmExtName = "vmss-hci"

    Write-Host "Importing ArcHci module..."
    Import-Module ((Get-Module "ArcHci" -ListAvailable | Sort-Object Version -Descending)[0].ModuleBase + "\ArcHci.psm1")

    $vmExtensionConfigFileName = "vm-extension-config.json"
    $vmExtensionConfigFilePath = join-path $workDirectory $vmExtensionConfigFileName

    Write-Host "Adding extension configuration to file..."
    Add-ExtensionConfigToFile -configFilePath $vmExtensionConfigFilePath -key "Microsoft.CustomLocation.ServiceAccount" -value "default"
    Add-ExtensionConfigToFile -configFilePath $vmExtensionConfigFilePath -key "infraCheck" -value "false"

    Write-Host "Logging into Azure with managed identity..."
    az login --identity
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to login to Azure with managed identity. Exit code: $LASTEXITCODE"
    }

    az account set -s $subscription
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to set Azure subscription. Exit code: $LASTEXITCODE"
    }

    Import-Module ArcHci 

    $mocConfigFilePath = join-path $workDirectory "\hci-config.json"
    
    Write-Host "Creating Arc HCI identity files..."
    New-ArcHciIdentityFiles -workDirectory $workDirectory

    Write-Host "Creating k8s-extension for VMSS..."
    az k8s-extension create -g $resource_group -c $appliance_name --cluster-type appliances --name $arcvmExtName `
      --extension-type Microsoft.AZStackHCI.Operator --scope cluster --release-namespace helm-operator2 `
      --config-protected-file $mocConfigFilePath --config-file $vmExtensionConfigFilePath `
      --release-train $release_train --version $arcvmversion --auto-upgrade-minor-version $false

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create k8s-extension. Exit code: $LASTEXITCODE"
    }

    Write-Host "VMSS extension deployment completed successfully."
}
catch {
    Write-Error "An error occurred during VMSS extension deployment: $_"
    Write-Error "Exception details: $($_.Exception.Message)"
    Write-Error "Stack trace: $($_.ScriptStackTrace)"
    throw
}
finally {
    Stop-Transcript
}