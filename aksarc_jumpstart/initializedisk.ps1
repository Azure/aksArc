# Get all raw disks (no partition)
$disk = Get-Disk | Where-Object PartitionStyle -Eq 'RAW'

# Initialize the disk with GPT partition style
Initialize-Disk -Number $disk.Number -PartitionStyle GPT

# Create a new partition using all space and assign drive letter
New-Partition -DiskNumber $disk.Number -UseMaximumSize -AssignDriveLetter

# Format the volume as NTFS
$driveLetter =  (Get-Partition -DiskNumber $disk.Number | select -Last 1).DriveLetter
Format-Volume -DriveLetter $driveLetter -FileSystem NTFS -Confirm:$false

# Initialize log directory
mkdir e:\log