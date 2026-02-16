param(
    [int]$nodeCount = 1,
    [string]$vmNamePrefix = "jumpstartVM",
    [string]$catalog = "aks-hci-asz-stable-catalogs-int",
    [string]$ring = "monthly"
)

# Install MOC on the failover cluster.
# Runs on node 1. Uses Set-MocConfig with -nodes for multi-node.
# Deferred to RunOnce because MOC install requires CredSSP/local session.

Start-Transcript -Path "$env:LogDirectory\install-moc.ps1.log" -Append

try {
    $nodes = @()
    for ($i = 1; $i -le $nodeCount; $i++) {
        $nodes += "$vmNamePrefix-$i"
    }
    $nodeList = $nodes -join ","

    # Build the MOC install script that runs on next boot
    $scriptContent = @"
`$ErrorActionPreference = 'Stop'
Start-Transcript -Path "$env:WorkingDir\log\InstallMocStack.log" -Append
try {
    Set-MocConfig -workingDir "$env:WorkingDir" -catalog "$catalog" -ring "$ring" -nodes $nodeList
    Install-Moc
    Write-Host "MOC installation completed successfully."
} catch {
    Write-Error "MOC installation failed: `$(`$_.Exception.Message)"
    throw
}
Stop-Transcript
"@

    mkdir c:\mocscripts -ErrorAction SilentlyContinue
    $scriptFilePath = "c:\mocscripts\InstallMocStack.ps1"
    $scriptContent | Out-File -FilePath $scriptFilePath -Encoding UTF8

    New-ItemProperty `
        -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" `
        -Name "InitScript" `
        -Value "powershell.exe -ExecutionPolicy Bypass -File $scriptFilePath" `
        -Force

    Write-Host "MOC install script staged for RunOnce. Nodes: $nodeList"
    Write-Host "MOC will be installed on next boot."
}
catch {
    Write-Error "Failed to stage MOC install: $($_.Exception.Message)"
    throw
}

Stop-Transcript
Restart-Computer -Force
