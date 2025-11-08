# AKS enabled by Azure Arc Jump Start

## IMPORTANT NOTICE

This software is provided “AS IS”, without warranty of any kind, express or implied, including but not limited to warranties of merchantability, fitness for a particular purpose, and non-infringement.

**DO NOT** use this software in production environments. It is intended solely for testing, evaluation, and development purposes. Using this software in production may result in unexpected behavior, data loss, security vulnerabilities, or system instability.
The authors and contributors assume no liability for any damages, losses, or issues arising from the use or misuse of this software. By using this software, you agree to these terms and accept all associated risks.

### Steps to deploy:

```
git clone https://github.com/Azure/aksArc.git
cd aksArc\aksarc_jumpstart
az login --use-device-code
powershell .\jumpstart.ps1 -userName <username> -password <password>  -subscription  <subscriptionid> -GroupName <> -Location <> -vNetName <> -VMName <> -subnetName <>
# Login to the VM using RDP or Bastion.
# MOC install would start in a powershell [This was done because Install-Moc has to be done directly or via CredSSP].
# Wait for it to complete. It should only take 2-3 minutes
powershell .\deployaksarc.ps1 -subscription  <subscriptionid> -GroupName <> -Location <> -vNetName <> -VMName <> -subnetName <>

```

### Steps to Cleanup

```
az group delete --name <groupname> --yes

```
