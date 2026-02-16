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

Start-Transcript -Path "$env:LogDirectory\deployaksarcextension.ps1.log" -Append

try {
    $release_train = "stable"
    $aksarcExtName = "hybridaksextension"

    ipmo ((Get-Module "ArcHci" -ListAvailable | Sort-Object Version -Descending)[0].ModuleBase + "\ArcHci.psm1")

    $aksExtensionConfigFilePath = Join-Path $workDirectory "aks-extension-config.json"
    Add-ExtensionConfigToFile -configFilePath $aksExtensionConfigFilePath -key "Microsoft.CustomLocation.ServiceAccount" -value "default"

    az login --identity
    if ($LASTEXITCODE -ne 0) { throw "Failed to login. Exit code: $LASTEXITCODE" }
    az account set -s $subscription
    if ($LASTEXITCODE -ne 0) { throw "Failed to set subscription. Exit code: $LASTEXITCODE" }

    Write-Host "Creating AKS Arc extension..."
    az k8s-extension create -g $resource_group -c $appliance_name --cluster-type appliances --name $aksarcExtName `
        --extension-type Microsoft.HybridAKSOperator --config-file $aksExtensionConfigFilePath `
        --release-train $release_train --auto-upgrade-minor-version $true

    if ($LASTEXITCODE -ne 0) { throw "Failed to create AKS Arc extension. Exit code: $LASTEXITCODE" }
    Write-Host "AKS Arc extension deployed successfully."
}
catch {
    Write-Error "AKS Arc extension deployment failed: $_"
    throw
}
finally {
    Stop-Transcript
}
