using 'main.bicep'

param azureLocation = 'eastus' // TODO: add your Azure location.
param deploymentResourceGroupName = '<TODO>' // The resource group where bicep template deploys to.
// The resource group where azure local custom location already exists.
// You can also have your logical network in that resource group, but the template will have to be updated to refer to
// that existing logical network since currently it creates a new one.
param azureResourceGroupName = '<TODO>'
param customLocationName = '<TODO>'

// Logical network parameters.
// These are not needed if you have an existing logical network. In which case you have to modify the 'aksarc.bicep'
// template file to refer to the existing logical network instead of creating a new one.
param addressPrefix = '<TODO>'
param dnsServers = ['<TODO>']
param vmSwitchName = '<TODO>'
param ipAllocationMethod = '<TODO>'
param vipPoolStart = '<TODO>'
param vipPoolEnd = '<TODO>'
param gateway = '<TODO>'
param vlan = 0 // TODO: add your vlan.

// Provisioned cluster
param connectedClusterName = 'bicepConnectedCluster' // TODO: add your connected cluster name.
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
param nodePoolTaint = 'myTaint' // TODO: add your node pool taint.
param netWorkProfilNetworkPolicy = 'calico' // TODO: add your networkProfile's networkPolicy.
param networkProfileLoadBalancerCount = 0 // TODO: add your networkProfile's loadBalancerProfile.count.
