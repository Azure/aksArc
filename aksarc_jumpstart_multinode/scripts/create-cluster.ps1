param(
    [int]$nodeCount = 1,
    [string]$vmNamePrefix = "jumpstartVM",
    [string]$clusterName = "jumpstart-cluster",
    [string]$clusterIP = "10.0.0.100",
    [string]$adminUsername = "aksadmin",
    [string]$adminPassword = ""
)

# Create an AD-less failover cluster across all nodes.
# Runs on node 1 via CustomScriptExtension (SYSTEM context).
# Uses a scheduled task running as admin user to handle cross-node auth.

Start-Transcript -Path "$env:LogDirectory\create-cluster.ps1.log" -Append

try {
    # Build node list
    $nodes = @()
    for ($i = 1; $i -le $nodeCount; $i++) {
        $nodes += "$vmNamePrefix-$i"
    }
    $nodesStr = ($nodes | ForEach-Object { "'$_'" }) -join ', '
    Write-Host "Cluster nodes: $($nodes -join ', ')"

    # Wait for all nodes to be reachable
    foreach ($node in $nodes) {
        Write-Host "Waiting for $node to be reachable..."
        $retries = 0
        while ($retries -lt 30) {
            try {
                Test-Connection -ComputerName $node -Count 1 -ErrorAction Stop | Out-Null
                Write-Host "$node is reachable."
                break
            } catch {
                $retries++
                Start-Sleep -Seconds 10
            }
        }
        if ($retries -eq 30) {
            throw "Timed out waiting for $node to become reachable."
        }
    }

    # Generate the cluster creation script to run as admin user
    $setupDir = 'C:\ClusterSetup'
    New-Item -Path $setupDir -ItemType Directory -Force | Out-Null

    $innerScript = @"
`$ErrorActionPreference = 'Stop'
Start-Transcript -Path '$setupDir\cluster-creation.log' -Force
try {
    Set-Item WSMan:\localhost\Client\TrustedHosts -Value '*' -Force
    `$nodes = @($nodesStr)
    Write-Host "Creating AD-less failover cluster as `$env:USERNAME..."

    foreach (`$node in `$nodes) {
        Write-Host "Testing `$node..."
        Test-WSMan -ComputerName `$node -ErrorAction Stop
    }

    # Use node 1 Azure IP for cluster static address (Azure doesn't allow arbitrary IPs)
    `$node1IP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { `$_.IPAddress -like '10.0.*' }).IPAddress
    Write-Host "Using cluster static address: `$node1IP"

    New-Cluster -Name '$clusterName' -Node `$nodes -StaticAddress `$node1IP -AdministrativeAccessPoint DNS -NoStorage -Force -WarningAction SilentlyContinue
    Write-Host "Cluster created!"

    # Add an IP Address resource to Cluster Group (required by MOC for multi-node)
    # AD-less clusters use Distributed Network Name which lacks an IP resource
    Write-Host "Adding Cluster IP Address resource for MOC..."
    `$ipRes = Add-ClusterResource -Name 'Cluster IP Address' -ResourceType 'IP Address' -Group 'Cluster Group' -ErrorAction Stop
    `$clusterNet = (Get-ClusterNetwork | Where-Object { `$_.Address -like '10.0.*' } | Select-Object -First 1).Name
    `$ipRes | Set-ClusterParameter -Multiple @{
        Address = '$clusterIP'
        SubnetMask = '255.255.255.0'
        Network = `$clusterNet
        EnableDhcp = 0
    }
    Start-ClusterResource -Name 'Cluster IP Address' -ErrorAction Continue
    Write-Host "Cluster IP Address resource: `$((Get-ClusterResource 'Cluster IP Address').State)"

    # Add cluster name to hosts file on all nodes for DNS resolution
    `$hostsEntry = "$clusterIP`t$clusterName"
    foreach (`$node in `$nodes) {
        Invoke-Command -ComputerName `$node -ScriptBlock {
            param(`$entry, `$name)
            `$f = 'C:\Windows\System32\drivers\etc\hosts'
            `$c = Get-Content `$f | Where-Object { `$_ -notmatch `$name }
            `$c += `$entry
            `$c | Set-Content `$f -Force
        } -ArgumentList `$hostsEntry, '$clusterName'
    }
    Clear-DnsClientCache
    Write-Host "Added $clusterName -> $clusterIP to hosts files."

    # Add DNS zone for cluster name (appliance VM resolves via internal DNS at 172.16.0.1)
    Write-Host "Adding DNS zone for $clusterName..."
    Add-DnsServerPrimaryZone -Name '$clusterName' -ZoneFile '$clusterName.dns' -ErrorAction SilentlyContinue
    Add-DnsServerResourceRecordA -Name '@' -ZoneName '$clusterName' -IPv4Address '$clusterIP' -ErrorAction SilentlyContinue
    Write-Host "DNS zone for $clusterName created."

    # Configure shared disk as Cluster Shared Volume (needed for MOC working dir)
    Write-Host "Configuring shared disk as CSV..."
    `$sharedDisk = Get-Disk | Where-Object { `$_.PartitionStyle -eq 'RAW' -and `$_.Number -gt 0 }
    if (`$sharedDisk) {
        Write-Host "Initializing shared disk (Disk `$(`$sharedDisk.Number))..."
        Initialize-Disk -Number `$sharedDisk.Number -PartitionStyle GPT
        New-Partition -DiskNumber `$sharedDisk.Number -UseMaximumSize -AssignDriveLetter
        `$letter = (Get-Partition -DiskNumber `$sharedDisk.Number | Where-Object Type -ne 'Reserved' | Select-Object -Last 1).DriveLetter
        Format-Volume -DriveLetter `$letter -FileSystem NTFS -NewFileSystemLabel 'ClusterStorage' -Confirm:`$false
        `$clusterDisk = Get-ClusterAvailableDisk | Add-ClusterDisk
        if (`$clusterDisk) {
            Add-ClusterSharedVolume -Name `$clusterDisk.Name
            Write-Host "Shared disk added as CSV at C:\ClusterStorage\Volume1"
        } else {
            Write-Warning "Could not add shared disk to cluster."
        }
    } else {
        Write-Warning "No shared disk found."
    }

    Get-Cluster | Format-List Name,Domain
    Get-ClusterNode | Format-Table Name,State -AutoSize
    Get-ClusterSharedVolume -ErrorAction SilentlyContinue | Format-Table Name,State -AutoSize
    'SUCCESS' | Out-File '$setupDir\result.txt' -Force
} catch {
    Write-Host "ERROR: `$_"
    'FAILED' | Out-File '$setupDir\result.txt' -Force
    throw
}
Stop-Transcript
"@

    $innerScript | Out-File "$setupDir\create-cluster-inner.ps1" -Force -Encoding UTF8

    # Run as admin user via scheduled task (SYSTEM can't auth to other nodes)
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-ExecutionPolicy Unrestricted -File $setupDir\create-cluster-inner.ps1"
    $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddSeconds(5)
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
    Register-ScheduledTask -TaskName 'CreateCluster' -Action $action -Trigger $trigger -Settings $settings -User $adminUsername -Password $adminPassword -RunLevel Highest -Force
    Start-ScheduledTask -TaskName 'CreateCluster'

    Write-Host "Cluster creation started as $adminUsername. Waiting..."
    $maxWait = 600
    $elapsed = 0
    do {
        Start-Sleep -Seconds 10
        $elapsed += 10
        $taskState = (Get-ScheduledTask -TaskName 'CreateCluster').State
        Write-Host "  Task state: $taskState (${elapsed}s)"
    } while ($taskState -eq 'Running' -and $elapsed -lt $maxWait)

    # Check result
    if (Test-Path "$setupDir\result.txt") {
        $result = Get-Content "$setupDir\result.txt"
        if ($result -ne 'SUCCESS') {
            if (Test-Path "$setupDir\cluster-creation.log") {
                Get-Content "$setupDir\cluster-creation.log" | Select-Object -Last 20
            }
            throw "Cluster creation failed."
        }
    } else {
        throw "Cluster creation timed out or did not produce a result."
    }

    if (Test-Path "$setupDir\cluster-creation.log") {
        Get-Content "$setupDir\cluster-creation.log" | Select-Object -Last 15
    }

    Unregister-ScheduledTask -TaskName 'CreateCluster' -Confirm:$false -ErrorAction SilentlyContinue

    Write-Host "Failover cluster '$clusterName' created successfully."
}
catch {
    Write-Error "Failed to create cluster: $($_.Exception.Message)"
    Unregister-ScheduledTask -TaskName 'CreateCluster' -Confirm:$false -ErrorAction SilentlyContinue
    throw
}

Stop-Transcript
