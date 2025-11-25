using 'main.bicep'

param customLocationResourceID = '<TODO>' // The custom location resource ID
param provisionedClusterName = '<TODO>' // The existing provisioned cluster name

// Logical network - existing logical network reference
param logicalNetworkName = '<TODO>'

// Provisioned cluster
param sshPublicKey = '<TODO>' // Full public key copied from the .pub file.
param controlPlaneHostIP = '<TODO>'
param kubernetesVersion = '<TODO>'
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
