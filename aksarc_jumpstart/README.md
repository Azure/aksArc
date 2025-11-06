# AKS enabled by Azure Arc Jump Start

### Steps to deploy:
```
git clone https://github.com/Azure/aksArc.git
cd aksArc\aksarc_jumpstart
az login --use-device-code
powershell .\jumpstart.ps1 -userName <username> -password <password>  -subscription  <subscriptionid> -GroupName <> -Location <> -vNetName <> -VMName <> -subnetName <>
# Login to the VM using RDP or Bastion.
# MOC install would start in a powershell [This was done because Install-Moc has to be done directly or via CredSSP]. 
# Wait for it to complete. It should only take 2-3 minutes
powershell .\deployaksarc.ps1 -subscription  <subscriptionid>

```


### Steps to Cleanup

```
az group delete --name <groupname> --yes

```
