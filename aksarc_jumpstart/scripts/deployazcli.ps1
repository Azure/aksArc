# Install Az CLI
Start-Transcript -Path "$env:LogDirectory\deployazcli.ps1.log" -Append

Write-Host "Installing Azure CLI... "
Register-PSRepository -Default -ErrorAction SilentlyContinue

Install-PackageProvider -Name NuGet -Force
Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile .\AzureCLI.msi; 
Start-Process msiexec.exe -ArgumentList '/I AzureCLI.msi /quiet' -NoNewWindow -Wait; 
Remove-Item .\AzureCLI.msi

Write-Host "Installing Az.AksArc module... "
Install-Module -Name Az.AksArc -Repository PSGallery -Force
Stop-Transcript