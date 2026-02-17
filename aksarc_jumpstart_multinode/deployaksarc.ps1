[CmdletBinding()]
param (
    [Parameter()]
    [string]$GroupName = "jumpstart-rg",

    [Parameter(Mandatory = $true)]
    [ValidateSet("eastus", "eastus2", "westus2", "westeurope", "australiaeast")]
    [string]$Location = "eastus",

    [Parameter()]
    [string]$vmNamePrefix = "jumpstartVM",

    [Parameter(Mandatory = $true)]
    [string]$subscription,

    [Parameter()]
    [string]$applianceName,

    [Parameter()]
    [string]$customLocationName,

    [Parameter()]
    [string]$ArcLnetName,

    [Parameter()]
    [string]$aksArcClusterName,

    [Parameter()]
    [string]$workingDir,

    [Parameter()]
    [string]$arcHciVersion = "1.3.15",

    [Parameter(Mandatory = $true)]
    [string]$userName,

    [Parameter(Mandatory = $true)]
    [string]$password
)

$ErrorActionPreference = "Stop"

# Node 1 is the primary — all deployment scripts run on it
$primaryVM = "$vmNamePrefix-1"

if ([string]::IsNullOrEmpty($applianceName)) {
    $applianceName = "$vmNamePrefix-appliance"
}
if ([string]::IsNullOrEmpty($customLocationName)) {
    $customLocationName = "$applianceName-cl"
}
if ([string]::IsNullOrEmpty($ArcLnetName)) {
    $ArcLnetName = "$applianceName-lnet"
}
if ([string]::IsNullOrEmpty($aksArcClusterName)) {
    $aksArcClusterName = "$applianceName-aksarc"
}

Write-Host "=== Multi-Node AKS Arc Deployment (Phase 2) ==="
Write-Host "Primary VM: $primaryVM | Location: $Location"
Write-Host ""

$gitSource = (git config --get remote.origin.url).Replace("github.com", "raw.githubusercontent.com") -replace '\.git$', ''
$branch = (git branch --show-current)
$scriptLocation = "$gitSource/refs/heads/$branch/aksarc_jumpstart_multinode/scripts"

$scriptToExecute = [ordered]@{
    "$scriptLocation/installazmodules.ps1"      = "installazmodules.ps1 -arcHciVersion ""$arcHciVersion"" -adminUsername ""$userName"" -adminPassword ""$password"""
    "$scriptLocation/deployappliance.ps1"       = "deployappliance.ps1 -resource_group ""$GroupName"" -appliance_name ""$applianceName"" -location ""$Location"" -subscription ""$subscription"" -adminUsername ""$userName"" -adminPassword ""$password"""
    "$scriptLocation/deployaksarcextension.ps1" = "deployaksarcextension.ps1 -resource_group ""$GroupName"" -appliance_name ""$applianceName"" -location ""$Location"" -subscription ""$subscription"""
    "$scriptLocation/deployvmssextension.ps1"   = "deployvmssextension.ps1 -resource_group ""$GroupName"" -appliance_name ""$applianceName"" -location ""$Location"" -subscription ""$subscription"""
    "$scriptLocation/deploycustomlocation.ps1"  = "deploycustomlocation.ps1 -resource_group ""$GroupName"" -appliance_name ""$applianceName"" -customLocationName ""$customLocationName"" -subscription ""$subscription"""
    "$scriptLocation/deploylnet.ps1"            = "deploylnet.ps1 -resource_group ""$GroupName"" -lnetName ""$ArcLnetName"" -customLocationName ""$customLocationName"" -location ""$Location"" -subscription ""$subscription"""
    "$scriptLocation/deployaksarccluster.ps1"   = "deployaksarccluster.ps1 -resource_group ""$GroupName"" -aksArcClusterName ""$aksArcClusterName"" -lnetName ""$ArcLnetName"" -customLocationName ""$customLocationName"" -subscription ""$subscription"""
}

$step = 1
$total = $scriptToExecute.Count

foreach ($script in $scriptToExecute.GetEnumerator()) {
    $scriptUrl = $script.Key
    $scriptCmd = $script.Value
    $scriptBaseName = $scriptCmd.Split(" ")[0].Replace('.ps1', '')
    $deploymentName = "deploy-$primaryVM-$scriptBaseName"
    $commandToExecute = "powershell.exe -ExecutionPolicy Unrestricted -File $scriptCmd"

    Write-Host "[$step/$total] Running $scriptBaseName on $primaryVM..."
    try {
        az deployment group create --name $deploymentName --resource-group $GroupName `
            --template-file ./configuration/executescript-template.json `
            --parameters location=$Location vmName=$primaryVM scriptFileUri=$scriptUrl commandToExecute=$commandToExecute
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to execute $scriptBaseName on $primaryVM. Exit code: $LASTEXITCODE"
        }
    }
    catch {
        Write-Error "Deployment failed at step $step ($scriptBaseName): $_"
        throw
    }
    $step++
}

Write-Host ""
Write-Host "=== Phase 2 complete! ==="
Write-Host "AKS Arc cluster '$aksArcClusterName' is ready."
