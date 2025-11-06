# AKS enabled by Azure Arc Jump Start

Steps:
```
git clone https://github.com/Azure/aksArc.git
cd aksArc\aksarc_jumpstart
powershell .\jumpstart.ps1 -userName <username> -password <password> 
# Login to the VM using RDP or Bastion.
# MOC install would start in a powershell [This was done because Install-Moc has to be done directly or via CredSSP]. 
# Wait for it to complete. It should only take 2-3 minutes
powershell .\deployaksarc.ps1 -subscription  <subscriptionid>
```