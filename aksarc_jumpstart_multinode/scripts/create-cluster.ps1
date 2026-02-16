param(
    [int]$nodeCount = 1,
    [string]$vmNamePrefix = "jumpstartVM",
    [string]$clusterName = "jumpstart-cluster",
    [string]$clusterIP = "172.16.0.200",
    [string]$adminUsername = "aksadmin",
    [string]$adminPassword = ""
)

# Create an AD-less failover cluster across all nodes.
# Runs on node 1, targeting all nodes.
# Uses shared disk as cluster witness.

Start-Transcript -Path "$env:LogDirectory\create-cluster.ps1.log" -Append

try {
    # Build node list
    $nodes = @()
    for ($i = 1; $i -le $nodeCount; $i++) {
        $nodes += "$vmNamePrefix-$i"
    }
    Write-Host "Cluster nodes: $($nodes -join ', ')"

    # Setup credentials for cross-node access
    if ($adminPassword) {
        $secPassword = ConvertTo-SecureString $adminPassword -AsPlainText -Force
        $cred = New-Object System.Management.Automation.PSCredential("$env:COMPUTERNAME\$adminUsername", $secPassword)

        # Ensure WinRM trust for all nodes
        foreach ($node in $nodes) {
            Write-Host "Adding $node to TrustedHosts and storing credentials..."
            cmdkey /add:$node /user:$adminUsername /pass:$adminPassword
        }
    }

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

    # Validate cluster configuration
    Write-Host "Validating cluster configuration..."
    Test-Cluster -Node $nodes -Include "Inventory","Network","System Configuration" -ErrorAction SilentlyContinue

    # Create AD-less failover cluster
    Write-Host "Creating AD-less failover cluster '$clusterName'..."
    if ($nodeCount -eq 1) {
        New-Cluster -Name $clusterName -Node $nodes -StaticAddress $clusterIP -AdministrativeAccessPoint DNS -NoStorage
    } else {
        New-Cluster -Name $clusterName -Node $nodes -StaticAddress $clusterIP -AdministrativeAccessPoint DNS -NoStorage
    }

    # Configure shared disk as cluster witness (disk witness)
    Write-Host "Configuring shared disk..."
    # The shared disk should appear as a raw disk on LUN 1
    $sharedDisk = Get-Disk | Where-Object { $_.PartitionStyle -eq 'RAW' -and $_.Number -gt 0 }
    if ($sharedDisk) {
        Write-Host "Initializing shared disk (Disk $($sharedDisk.Number))..."
        Initialize-Disk -Number $sharedDisk.Number -PartitionStyle GPT
        New-Partition -DiskNumber $sharedDisk.Number -UseMaximumSize -AssignDriveLetter
        $sharedDriveLetter = (Get-Partition -DiskNumber $sharedDisk.Number | Where-Object Type -ne 'Reserved' | Select-Object -Last 1).DriveLetter
        Format-Volume -DriveLetter $sharedDriveLetter -FileSystem NTFS -NewFileSystemLabel "ClusterWitness" -Confirm:$false

        # Add disk to cluster and set as witness
        $clusterDisk = Get-ClusterAvailableDisk | Add-ClusterDisk
        if ($clusterDisk) {
            Set-ClusterQuorum -DiskWitness $clusterDisk.Name
            Write-Host "Shared disk configured as cluster witness."
        } else {
            Write-Warning "Could not add shared disk to cluster. Using node majority quorum."
        }
    } else {
        Write-Warning "No shared disk found. Using node majority quorum."
    }

    Write-Host "Failover cluster '$clusterName' created successfully."
    Get-Cluster | Format-List *
    Get-ClusterNode | Format-Table Name, State
}
catch {
    Write-Error "Failed to create cluster: $($_.Exception.Message)"
    throw
}

Stop-Transcript
