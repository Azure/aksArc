# Install Az CLI
Start-Transcript -Path "E:\log\deployazcli.ps1.log" -Append

Write-Host "Installing Azure CLI... "
Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile .\AzureCLI.msi; 
Start-Process msiexec.exe -ArgumentList '/I AzureCLI.msi /quiet' -NoNewWindow -Wait; 
Remove-Item .\AzureCLI.msi

Install-Module -Name Az.AksArc -Repository PSGallery -Force -RequiredVersion 0.1.1
Stop-Transcript