# Install prerequisites: Azure CLI, NuGet, MOC module, firewall rules, WinRM for clustering.
# Runs on all nodes.

param(
    [string]$adminUsername = "aksadmin",
    [string]$adminPassword = ""
)

Start-Transcript -Path "$env:LogDirectory\install-prerequisites.ps1.log" -Append

try {
    # Azure CLI
    Write-Host "Installing Azure CLI..."
    Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile .\AzureCLI.msi
    Start-Process msiexec.exe -ArgumentList '/I AzureCLI.msi /quiet' -NoNewWindow -Wait
    Remove-Item .\AzureCLI.msi

    # PowerShell modules
    Write-Host "Installing NuGet and PowerShellGet..."
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$false
    Install-Module -Name PowershellGet -Force -Confirm:$false -SkipPublisherCheck

    Write-Host "Installing MOC module..."
    Install-Module -Name MOC -Repository PSGallery -Force -Confirm:$false

    Write-Host "Installing Az.AksArc module..."
    Install-Module -Name Az.AksArc -Repository PSGallery -Force -Confirm:$false

    Write-Host "Installing ArcHci module..."
    Install-Module -Name ArcHci -Repository PSGallery -Force -Confirm:$false

    # Firewall rules for MOC
    Write-Host "Configuring firewall rules..."
    netsh int ipv4 add ex tcp 45000 1 store=persistent
    netsh int ipv4 add ex tcp 45001 1 store=persistent
    netsh int ipv4 add ex tcp 55000 1 store=persistent
    netsh int ipv4 add ex tcp 65000 1 store=persistent
    New-NetFirewallRule -Name WSSDAgents-TCP-In -LocalPort 45000,55000,45001,65000 -DisplayName WSSDAgents -Protocol TCP

    # Firewall rules for failover clustering
    Write-Host "Configuring clustering firewall rules..."
    New-NetFirewallRule -Name "FailoverCluster-In" -DisplayName "Failover Cluster" -Direction Inbound -Protocol TCP -LocalPort 135,445,3343,5985,5986 -Action Allow
    New-NetFirewallRule -Name "FailoverCluster-UDP-In" -DisplayName "Failover Cluster UDP" -Direction Inbound -Protocol UDP -LocalPort 3343 -Action Allow
    Get-NetFirewallRule -Name FPS-SMB* | Set-NetFirewallRule -Enabled True

    # Enable WinRM for cross-node cluster management
    Write-Host "Configuring WinRM..."
    Enable-PSRemoting -Force -SkipNetworkProfileCheck
    Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force
    Set-Item WSMan:\localhost\Service\AllowUnencrypted -Value $true -Force
    Set-Item WSMan:\localhost\Service\Auth\Basic -Value $true -Force
    Restart-Service WinRM

    # Enable auto-logon for cluster admin (needed for New-Cluster cross-node auth)
    if ($adminUsername -and $adminPassword) {
        Write-Host "Enabling auto-logon for cluster operations..."
        $secPassword = ConvertTo-SecureString $adminPassword -AsPlainText -Force
        $cred = New-Object System.Management.Automation.PSCredential($adminUsername, $secPassword)
        # Store credential so cluster creation can use it
        cmdkey /add:* /user:$adminUsername /pass:$adminPassword
    }

    Write-Host "Prerequisites installed."
}
catch {
    Write-Error "Failed to install prerequisites: $($_.Exception.Message)"
    throw
}

Stop-Transcript
