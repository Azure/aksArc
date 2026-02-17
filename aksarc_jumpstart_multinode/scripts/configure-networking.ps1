param(
    [string]$nodeIndex = "1",
    [string]$nodeCount = "1"
)

[int]$nodeIndex = [int]$nodeIndex
[int]$nodeCount = [int]$nodeCount

# Configure networking: External vSwitch bridged to Ethernet adapter.
# Nested VMs (appliance, AKS workers) get Azure VNet IPs directly.

Start-Transcript -Path "$env:LogDirectory\configure-networking.ps1.log" -Append

# Wait for Hyper-V to be ready
while ($true) {
    try {
        Get-VMSwitch -ErrorAction Stop | Out-Null
        break
    } catch {
        Write-Host "Waiting for Hyper-V to be ready..."
        Start-Sleep -Seconds 10
    }
}

# Create external vSwitch bridged to the primary Ethernet adapter
$primaryAdapter = Get-NetAdapter | Where-Object { $_.Name -like "Ethernet*" -and $_.Status -eq "Up" } | Select-Object -First 1
if (-not $primaryAdapter) {
    throw "No active Ethernet adapter found."
}

Write-Host "Creating external vSwitch on adapter: $($primaryAdapter.Name)..."
New-VMSwitch -Name "ExternalSwitch" -NetAdapterName $primaryAdapter.Name -AllowManagementOS $true

Write-Host "Networking configured for node ${nodeIndex}."
Stop-Transcript
