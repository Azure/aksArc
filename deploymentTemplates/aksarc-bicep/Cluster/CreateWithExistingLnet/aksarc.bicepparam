using 'main.bicep'

param azureLocation = 'eastus' // TODO: add your Azure location.
// This ID should refer to an existing custom location resource.
param customLocationResourceID = '<TODO>'

// Existing logical network
param logicalNetworkName = '<TODO>'

// Aks Arc cluster
param connectedClusterName = 'bicepConnectedCluster' // TODO: add your Aks Arc cluster name.
param sshPublicKey = '<TODO>' // Full public key copied from the .pub file.
param controlPlaneHostIP = '<TODO>'
param kubernetesVersion = '<TODO>'
// You may leave the following values as is for simplicity.
param controlPlaneVMSize = 'Standard_A4_v2' // TODO: add your control plane node size.
param controlPlaneNodeCount = 1 // TODO: add your control plane node count.
param nodePoolName = 'nodepool1' // TODO: add your node pool node name.
param nodePoolVMSize = 'Standard_A4_v2' // TODO: add your node pool VM size.
param nodePoolOSType = 'Linux' // TODO: add your node pool OS type.
param nodePoolCount = 1 // TODO: add your node pool node count.
param nodePoolLabel = 'myLabel' // TODO: add your node pool label key.
param nodePoolLabelValue = 'myValue' // TODO: add your node pool label value.
param nodePoolTaints = [] // TODO: add your node pool taints array
param netWorkProfilNetworkPolicy = 'calico' // TODO: add your networkProfile's networkPolicy.
param networkProfileLoadBalancerCount = 0 // TODO: add your networkProfile's loadBalancerProfile.count.
param enableAzureHybridBenefit = 'False' // TODO: 'True' or 'False'
param enableNfsCsiDriver = true // TODO: true or false
param enableSmbCsiDriver = true // TODO: true or false
