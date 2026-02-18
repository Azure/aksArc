[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$userName,

    [Parameter(Mandatory = $true)]
    [string]$password,

    [Parameter()]
    [string]$GroupName = "jumpstart-rg",

    [Parameter(Mandatory = $true)]
    [ValidateSet("eastus", "eastus2", "westus2", "westeurope", "australiaeast")]
    [string]$Location = "eastus",

    [Parameter()]
    [string]$subscriptionId,

    [Parameter()]
    [int]$nodeCount = 1,

    [Parameter()]
    [string]$vmNamePrefix = "jumpstartVM",

    [Parameter()]
    [string]$vmSize = "Standard_E16s_v4",

    [Parameter()]
    [string]$vnetName = "jumpstartVNet",

    [Parameter()]
    [string]$subnetName = "jumpstartSubnet",

    [Parameter()]
    [int]$localDiskSizeGB = 1024,

    [Parameter()]
    [int]$sharedDiskSizeGB = 256,

    [Parameter()]
    [string]$availabilityZone = "1",

    [Parameter()]
    [string]$clusterName = "jumpstart-cluster"
)

$ErrorActionPreference = "Stop"

Write-Host "=== Multi-Node AKS Arc Jumpstart ==="
Write-Host "Nodes: $nodeCount | Location: $Location | VM Size: $vmSize"
Write-Host ""

# --- Step 1: Create Resource Group ---
Write-Host "[1/8] Creating resource group '$GroupName'..."
az group create --name $GroupName --location $Location
if ($LASTEXITCODE -ne 0) { throw "Failed to create resource group." }

# --- Step 2: Create VNet ---
Write-Host "[2/8] Creating virtual network..."
az deployment group create --resource-group $GroupName `
    --template-file ./configuration/vnet-template.json `
    --parameters vnetName=$vnetName location=$Location subnetName=$subnetName
if ($LASTEXITCODE -ne 0) { throw "Failed to create VNet." }

# --- Step 3: Create N VMs ---
Write-Host "[3/8] Creating $nodeCount VM(s)..."
az deployment group create --resource-group $GroupName `
    --template-file ./configuration/vm-template.json `
    --parameters vmNamePrefix=$vmNamePrefix nodeCount=$nodeCount adminUsername=$userName adminPassword=$password `
                 location=$Location vnetName=$vnetName vmSize=$vmSize subnetName=$subnetName localDiskSizeGB=$localDiskSizeGB `
                 availabilityZone=$availabilityZone
if ($LASTEXITCODE -ne 0) { throw "Failed to create VMs." }

# --- Step 4: Create and link shared disk (multi-node only) ---
if ($nodeCount -gt 1) {
    Write-Host "[4/9] Creating shared disk..."
    $sharedDiskName = "$vmNamePrefix-shared-disk"
    az deployment group create --resource-group $GroupName `
        --template-file ./configuration/shared-disk-template.json `
        --parameters diskName=$sharedDiskName diskSizeGB=$sharedDiskSizeGB maxShares=$nodeCount `
                     location=$Location availabilityZone=$availabilityZone
    if ($LASTEXITCODE -ne 0) { throw "Failed to create shared disk." }

    # Link shared disk to each VM as LUN 1
    Write-Host "    Linking shared disk to VMs..."
    $diskId = az disk show --resource-group $GroupName --name $sharedDiskName --query id -o tsv
    for ($i = 1; $i -le $nodeCount; $i++) {
        $currentVM = "$vmNamePrefix-$i"
        Write-Host "    Linking to $currentVM..."
        az vm disk attach --resource-group $GroupName --vm-name $currentVM --name $sharedDiskName --lun 1
        if ($LASTEXITCODE -ne 0) { throw "Failed to link shared disk to $currentVM." }
    }
} else {
    Write-Host "[4/9] Skipping shared disk (single node)."
}

# --- Step 5: Add secondary IP to node 1 NIC for cluster IP Address resource ---
Write-Host "[5/9] Adding secondary IP for cluster IP resource..."
$nicName = az vm show --resource-group $GroupName --name "$vmNamePrefix-1" --query "networkProfile.networkInterfaces[0].id" -o tsv | Split-Path -Leaf
az network nic ip-config create --resource-group $GroupName --nic-name $nicName --name clusterIP --private-ip-address 10.0.0.100
if ($LASTEXITCODE -ne 0) { throw "Failed to add secondary IP for cluster." }

# --- Step 6: Enable nested virtualization on all VMs ---
# NOTE: Standard_E16s_v4 supports nested virt natively, no explicit enabling needed
Write-Host "[6/9] Nested virtualization enabled (built-in for $vmSize)."

# --- Step 6: Run init scripts on all VMs ---
$gitSource = (git config --get remote.origin.url).Replace("github.com", "raw.githubusercontent.com") -replace '\.git$', ''
$branch = (git branch --show-current)
$scriptLocation = "$gitSource/refs/heads/$branch/aksarc_jumpstart_multinode/scripts"

$initScripts = [ordered]@{
    "$scriptLocation/initializedisk.ps1"        = "initializedisk.ps1"
    "$scriptLocation/install-features.ps1"      = "install-features.ps1"
    "$scriptLocation/configure-networking.ps1"  = "configure-networking.ps1 -nodeIndex NODE_INDEX -nodeCount $nodeCount"
    "$scriptLocation/install-prerequisites.ps1" = "install-prerequisites.ps1 -adminUsername $userName -adminPassword $password"
}

Write-Host "[7/9] Running init scripts on all $nodeCount VM(s)..."
for ($i = 1; $i -le $nodeCount; $i++) {
    $currentVM = "$vmNamePrefix-$i"
    Write-Host "  --- $currentVM ---"
    foreach ($script in $initScripts.GetEnumerator()) {
        $scriptUrl = $script.Key
        $scriptCmd = $script.Value.Replace("NODE_INDEX", "$i")
        $scriptBaseName = $scriptCmd.Split(" ")[0].Replace('.ps1', '')
        $deploymentName = "init-$currentVM-$scriptBaseName"
        $commandToExecute = "powershell.exe -ExecutionPolicy Unrestricted -File $scriptCmd"

        Write-Host "    Running $scriptBaseName on $currentVM..."
        az deployment group create --name $deploymentName --resource-group $GroupName `
            --template-file ./configuration/executescript-template.json `
            --parameters location=$Location vmName=$currentVM scriptFileUri=$scriptUrl commandToExecute=$commandToExecute
        if ($LASTEXITCODE -ne 0) { throw "Failed to run $scriptBaseName on $currentVM." }
    }
}

# --- Step 8: Run clustering scripts on node 1 ---
Write-Host "[8/9] Running clustering scripts on $vmNamePrefix-1..."
$node1 = "$vmNamePrefix-1"

$clusterScripts = [ordered]@{
    "$scriptLocation/create-cluster.ps1" = "create-cluster.ps1 -nodeCount $nodeCount -vmNamePrefix ""$vmNamePrefix"" -clusterName ""$clusterName"" -clusterIP ""10.0.0.100"" -adminUsername ""$userName"" -adminPassword ""$password"""
    "$scriptLocation/install-moc.ps1"    = "install-moc.ps1 -nodeCount $nodeCount -vmNamePrefix ""$vmNamePrefix"" -adminUsername ""$userName"" -adminPassword ""$password"""
}

foreach ($script in $clusterScripts.GetEnumerator()) {
    $scriptUrl = $script.Key
    $scriptCmd = $script.Value
    $scriptBaseName = $scriptCmd.Split(" ")[0].Replace('.ps1', '')
    $deploymentName = "cluster-$node1-$scriptBaseName"
    $commandToExecute = "powershell.exe -ExecutionPolicy Unrestricted -File $scriptCmd"

    Write-Host "    Running $scriptBaseName on $node1..."
    az deployment group create --name $deploymentName --resource-group $GroupName `
        --template-file ./configuration/executescript-template.json `
        --parameters location=$Location vmName=$node1 scriptFileUri=$scriptUrl commandToExecute=$commandToExecute
    if ($LASTEXITCODE -ne 0) { throw "Failed to run $scriptBaseName on $node1." }
}

# --- Step 9: Done ---
Write-Host ""
Write-Host "[9/9] Phase 1 complete!"
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Wait for MOC install to finish (scheduled task on $node1)"
Write-Host "  2. Run: .\deployaksarc.ps1 -Location $Location -subscription $subscriptionId"
