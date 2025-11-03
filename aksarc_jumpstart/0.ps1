Start-Transcript -Path "E:\log\0.ps1.log" -Append

Install-WindowsFeature -Name DNS -IncludeManagementTools -Verbose; 
Install-WindowsFeature -Name DHCP -IncludeManagementTools -Verbose
Install-WindowsFeature -name Hyper-V  -IncludeAllSubFeature -IncludeManagementTools -Restart -Verbose

Stop-Transcript
