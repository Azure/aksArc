param(
    [int]$nodeCount = 1
)

# Install Windows features required for AKS Arc:
# Hyper-V always; Failover Clustering only for multi-node.

Start-Transcript -Path "$env:LogDirectory\install-features.ps1.log" -Append

try {
    Write-Host "Installing Hyper-V..."
    Install-WindowsFeature -Name Hyper-V -IncludeAllSubFeature -IncludeManagementTools -Verbose
    if ($nodeCount -gt 1) {
        Write-Host "Installing Failover Clustering (multi-node)..."
        Install-WindowsFeature -Name Failover-Clustering -IncludeManagementTools -Verbose
    } else {
        Write-Host "Skipping Failover Clustering (single-node)."
    }
    Write-Host "All features installed. Restarting..."
}
catch {
    Write-Error "Failed to install features: $($_.Exception.Message)"
}

Stop-Transcript
Restart-Computer -Force -Confirm:$false
