
Start-Transcript -Path "E:\log\deploymoc.ps1.log" -Append
#Get-NetFirewallRule -Name FPS-SMB* | Set-NetFirewallRule -Enabled True
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$false
Install-Module -Name PowershellGet -Force -Confirm:$false -SkipPublisherCheck
$VerbosePreference = "Continue"
# Install MOC Module
Install-Module -Name MOC -Repository PSGallery -Force

netsh int ipv4 add ex tcp 45000 1 store=persistent
netsh int ipv4 add ex tcp 45001 1 store=persistent
netsh int ipv4 add ex tcp 55000 1 store=persistent
netsh int ipv4 add ex tcp 65000 1 store=persistent
New-NetFirewallRule -Name WSSDAgents-TCP-In -LocalPort 45000,55000,45001,65000 -DisplayName WSSDAgents -Protocol TCP

$scriptContent = @"
Set-MocConfig -workingDir "E:\MOC" -catalog "aks-hci-asz-stable-catalogs-int" -ring "monthly" 
Install-Moc
"@

mkdir c:\mocscripts
$scriptFilePath = "c:\mocscripts\InstallMocStack.ps1"
$scriptContent | Out-File -FilePath $scriptFilePath -Encoding UTF8

New-ItemProperty `
  -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" `
  -Name "InitScript" `
  -Value "powershell.exe -ExecutionPolicy Bypass -File $scriptFilePath"

Stop-Transcript

Restart-Computer -Force