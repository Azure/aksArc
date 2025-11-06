param(
    [string]$arcHciVersion = "1.3.15"
)

Start-Transcript -Path "E:\log\installazmodules.ps1.log" -Append

$VerbosePreference = "Continue"
Install-Module -Name ArcHci -Repository PSGallery -AcceptLicense -Force -RequiredVersion $arcHciVersion

az provider register --namespace Microsoft.Kubernetes --wait
az provider register --namespace Microsoft.KubernetesConfiguration --wait
az provider register --namespace Microsoft.ExtendedLocation --wait
az provider register --namespace Microsoft.ResourceConnector --wait
az provider register --namespace Microsoft.HybridConnectivity --wait
az provider register --namespace Microsoft.HybridContainerService --wait

az extension add --name k8s-extension --upgrade --yes
az extension add --name customlocation --upgrade --yes
az extension add --name aksarc --upgrade --yes
az extension add --name connectedk8s --upgrade --yes
az extension add --name arcappliance --upgrade --yes
az extension add --name stack-hci-vm --upgrade --yes

Stop-Transcript