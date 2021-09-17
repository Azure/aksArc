


$password =  ConvertTo-SecureString "[your admin account user password]" -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential("$env:COMPUTERNAME\[your admin account]", $password)
$command = $file = $PSScriptRoot + "\installAksHci.ps1"
Enable-PSRemoting –force
Invoke-Command -FilePath $command -Credential $credential -ComputerName $env:COMPUTERNAME