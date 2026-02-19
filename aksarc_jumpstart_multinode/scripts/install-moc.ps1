param(
    [int]$nodeCount = 1,
    [string]$vmNamePrefix = "jumpstartVM",
    [string]$catalog = "aks-hci-asz-stable-catalogs-int",
    [string]$ring = "monthly",
    [string]$adminUsername = "aksadmin",
    [string]$adminPassword = ""
)

# Install MOC on the failover cluster.
# Runs on node 1 via CustomScriptExtension (SYSTEM context).
# Uses scheduled task to run as admin user (needs WinRM credentials).
# MOC auto-detects cluster nodes; working dir must be on CSV for multi-node.

Start-Transcript -Path "$env:LogDirectory\install-moc.ps1.log" -Append

try {
    $nodes = @()
    for ($i = 1; $i -le $nodeCount; $i++) {
        $nodes += "$vmNamePrefix-$i"
    }

    # Use CSV path if cluster with CSV exists, otherwise local path (single-node without cluster)
    $clusterExists = $false
    if (Get-Command Get-Cluster -ErrorAction SilentlyContinue) {
        $clusterExists = [bool](Get-Cluster -ErrorAction SilentlyContinue)
    }
    $workingDir = if ($clusterExists -and (Test-Path 'C:\ClusterStorage\Volume1')) {
        'C:\ClusterStorage\Volume1\ArcHCI'
    } else {
        "$env:WorkingDir\ArcHCI"
    }

    # Build the MOC install script — cloudServiceIP only for multi-node with cluster IP
    $mocConfigParams = "-workingDir '$workingDir' -catalog '$catalog' -ring '$ring'"
    if ($clusterExists) {
        $mocConfigParams += " -cloudServiceIP '10.0.0.100' -skipValidationCheck"
    }

    $scriptContent = @"
`$ErrorActionPreference = 'Stop'
Start-Transcript -Path 'C:\ClusterSetup\install-moc.log' -Force
try {
    Set-Item WSMan:\localhost\Client\TrustedHosts -Value '*' -Force
    Import-Module Moc -WarningAction SilentlyContinue
    New-Item -Path '$workingDir' -ItemType Directory -Force | Out-Null
    Write-Host 'Setting MOC config (workingDir: $workingDir)...'
    Set-MocConfig $mocConfigParams
    Write-Host 'Installing MOC...'
    Install-Moc
    Write-Host 'MOC installation completed.'
    'SUCCESS' | Out-File 'C:\ClusterSetup\moc-result.txt' -Force
} catch {
    Write-Host "ERROR: `$_"
    'FAILED' | Out-File 'C:\ClusterSetup\moc-result.txt' -Force
    throw
}
Stop-Transcript
"@

    $setupDir = 'C:\ClusterSetup'
    New-Item -Path $setupDir -ItemType Directory -Force | Out-Null
    $scriptFilePath = "$setupDir\InstallMocStack.ps1"
    $scriptContent | Out-File -FilePath $scriptFilePath -Encoding UTF8

    # Run as admin user via scheduled task (SYSTEM can't do WinRM to other nodes)
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-ExecutionPolicy Unrestricted -File $scriptFilePath"
    $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddSeconds(5)
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 2)
    Register-ScheduledTask -TaskName 'InstallMoc' -Action $action -Trigger $trigger -Settings $settings -User $adminUsername -Password $adminPassword -RunLevel Highest -Force
    Start-ScheduledTask -TaskName 'InstallMoc'

    Write-Host "MOC install started as $adminUsername. Monitoring..."
    $maxWait = 3600
    $elapsed = 0
    do {
        Start-Sleep -Seconds 60
        $elapsed += 60
        $taskState = (Get-ScheduledTask -TaskName 'InstallMoc').State
        if (Test-Path "$setupDir\install-moc.log") {
            $lastLine = Get-Content "$setupDir\install-moc.log" -Tail 1 -ErrorAction SilentlyContinue
            Write-Host "  [$([math]::Round($elapsed/60))min] $taskState | $lastLine"
        } else {
            Write-Host "  [$([math]::Round($elapsed/60))min] $taskState"
        }
    } while ($taskState -eq 'Running' -and $elapsed -lt $maxWait)

    # Check result
    if (Test-Path "$setupDir\moc-result.txt") {
        $result = Get-Content "$setupDir\moc-result.txt"
        if ($result -ne 'SUCCESS') {
            if (Test-Path "$setupDir\install-moc.log") {
                Get-Content "$setupDir\install-moc.log" | Select-Object -Last 20
            }
            throw "MOC installation failed."
        }
    } else {
        throw "MOC installation timed out."
    }

    Unregister-ScheduledTask -TaskName 'InstallMoc' -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "MOC installation completed successfully."
}
catch {
    Write-Error "Failed to install MOC: $($_.Exception.Message)"
    Unregister-ScheduledTask -TaskName 'InstallMoc' -Confirm:$false -ErrorAction SilentlyContinue
    throw
}

Stop-Transcript
