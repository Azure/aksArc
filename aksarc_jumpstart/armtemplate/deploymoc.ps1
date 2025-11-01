Install-Module -Name PowershellGet -Force -Confirm:$false -SkipPublisherCheck
Get-NetFirewallRule -Name FPS-SMB* | Set-NetFirewallRule -Enabled True
Install-PackageProvider -Name NuGet -Force
Install-Module -Name MOC -Repository PSGallery -AcceptLicense -Force
Set-MocConfig -workingDir "C:\MOC"
Install-Moc