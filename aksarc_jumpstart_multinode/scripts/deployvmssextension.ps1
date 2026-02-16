param(
    [string]$resource_group = "jumpstart-rg",
    [string]$appliance_name = "jumpstart-appliance",
    [string]$workDirectory,
    [string]$location = "eastus",
    [string]$subscription
)

if ([string]::IsNullOrEmpty($workDirectory)) {
    $workDirectory = "$env:WorkingDir"
}

Start-Transcript -Path "$env:LogDirectory\deployvmssextension.ps1.log" -Append

try {
    $release_train = "stable"
    $arcvmExtName = "vmss-hci"

    Import-Module ((Get-Module "ArcHci" -ListAvailable | Sort-Object Version -Descending)[0].ModuleBase + "\ArcHci.psm1")

    $vmExtensionConfigFilePath = Join-Path $workDirectory "vm-extension-config.json"
    Add-ExtensionConfigToFile -configFilePath $vmExtensionConfigFilePath -key "Microsoft.CustomLocation.ServiceAccount" -value "default"
    Add-ExtensionConfigToFile -configFilePath $vmExtensionConfigFilePath -key "infraCheck" -value "false"

    az login --identity
    if ($LASTEXITCODE -ne 0) { throw "Failed to login. Exit code: $LASTEXITCODE" }
    az account set -s $subscription
    if ($LASTEXITCODE -ne 0) { throw "Failed to set subscription. Exit code: $LASTEXITCODE" }

    Import-Module ArcHci
    New-ArcHciIdentityFiles -workDirectory $workDirectory

    $mocConfigFilePath = Join-Path $workDirectory "hci-config.json"

    Write-Host "Creating VMSS extension..."
    az k8s-extension create -g $resource_group -c $appliance_name --cluster-type appliances --name $arcvmExtName `
        --extension-type Microsoft.AZStackHCI.Operator --scope cluster --release-namespace helm-operator2 `
        --config-protected-file $mocConfigFilePath --config-file $vmExtensionConfigFilePath `
        --release-train $release_train --auto-upgrade-minor-version $true

    if ($LASTEXITCODE -ne 0) { throw "Failed to create VMSS extension. Exit code: $LASTEXITCODE" }
    Write-Host "VMSS extension deployed successfully."
}
catch {
    Write-Error "VMSS extension deployment failed: $_"
    throw
}
finally {
    Stop-Transcript
}
