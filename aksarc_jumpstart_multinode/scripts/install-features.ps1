# Install Windows features required for multi-node AKS Arc:
# Hyper-V, DNS, DHCP, and Failover Clustering.

Start-Transcript -Path "$env:LogDirectory\install-features.ps1.log" -Append

try {
    Write-Host "Installing Hyper-V, DNS, DHCP, and Failover Clustering..."
    Install-WindowsFeature -Name Hyper-V -IncludeAllSubFeature -IncludeManagementTools -Verbose
    Install-WindowsFeature -Name DNS -IncludeManagementTools -Verbose
    Install-WindowsFeature -Name DHCP -IncludeManagementTools -Verbose
    Install-WindowsFeature -Name Failover-Clustering -IncludeManagementTools -Verbose
    Write-Host "All features installed. Restarting..."
}
catch {
    Write-Error "Failed to install features: $($_.Exception.Message)"
}

Stop-Transcript
Restart-Computer -Force -Confirm:$false
