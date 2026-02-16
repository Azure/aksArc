# Initialize the local data disk (LUN 0) for AKS Arc working directory.
# The shared disk (LUN 1, if present) is left uninitialized — clustering manages it.

$disk = Get-Disk | Where-Object { $_.PartitionStyle -eq 'RAW' -and $_.Number -ne 0 }

# Pick the first RAW disk at LUN 0 (local data disk)
$localDisk = Get-Disk | Where-Object { $_.PartitionStyle -eq 'RAW' } | Sort-Object Number | Select-Object -First 1

if (-not $localDisk) {
    Write-Error "No RAW disk found for initialization."
    exit 1
}

Write-Host "Initializing disk $($localDisk.Number) (Size: $($localDisk.Size / 1GB) GB) ..."
Initialize-Disk -Number $localDisk.Number -PartitionStyle GPT
New-Partition -DiskNumber $localDisk.Number -UseMaximumSize -AssignDriveLetter
$driveLetter = (Get-Partition -DiskNumber $localDisk.Number | Where-Object Type -ne 'Reserved' | Select-Object -Last 1).DriveLetter
Format-Volume -DriveLetter $driveLetter -FileSystem NTFS -Confirm:$false

$workingDir = "$($driveLetter):\AKSArc"
$logDirectory = "$workingDir\log"

[System.Environment]::SetEnvironmentVariable("WorkingDir", "$workingDir", "Machine")
[System.Environment]::SetEnvironmentVariable("LogDirectory", "$logDirectory", "Machine")
mkdir $logDirectory -Force

Write-Host "Local disk initialized. WorkingDir=$workingDir"
Restart-Computer -Force -Confirm:$false
