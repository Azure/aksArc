# az config set auto-upgrade.enable=yes
# make sure the extensions are latest
az extension add --name k8s-extension
az extension add --name customlocation
az extension add --name connectedk8s
az extension add --name arcappliance --upgrade
az extension add --name aksarc
az extension add -n stack-hci-vm --version 1.2.3
az upgrade

Install-Module -Name Az.AksArc -Repository PSGallery -AcceptLicense -Force -RequiredVersion 0.1.1
Install-Module -Name ArcHci -Repository PSGallery -AcceptLicense -Force -RequiredVersion 0.2.38
