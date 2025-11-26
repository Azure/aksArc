using 'main.bicep'

param azureLocation = 'eastus' // TODO: add your Azure location.
// This ID should refer to an existing custom location resource.
param customLocationResourceID = '<TODO>'

// Logical network parameters.
// These are not needed if you have an existing logical network. In which case you have to modify the 'aksarc.bicep'
// template file to refer to the existing logical network instead of creating a new one.
param logicalNetworkName = '<TODO>'
param addressPrefix = '<TODO>'
param dnsServers = ['<TODO>']
param vmSwitchName = '<TODO>'
param ipAllocationMethod = '<TODO>'
param vipPoolStart = '<TODO>'
param vipPoolEnd = '<TODO>'
param nextHopIpAddress = '<TODO>'
param vlan = 0 // TODO: add your vlan.

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
