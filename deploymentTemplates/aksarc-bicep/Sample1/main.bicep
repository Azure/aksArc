
targetScope='subscription'

param azureLocation string
param deploymentResourceGroupName string
param customLocationResourceID string

// Logical network
param logicalNetworkName string

// Provisioned cluster
param connectedClusterName string
param sshPublicKey string
param controlPlaneHostIP string
param kubernetesVersion string
param controlPlaneVMSize string
param controlPlaneNodeCount int
param nodePoolName string
param nodePoolVMSize string
param nodePoolOSType string
param nodePoolCount int
param nodePoolLabel string
param nodePoolLabelValue string
param nodePoolTaint string
param netWorkProfilNetworkPolicy string
param networkProfileLoadBalancerCount int

resource deploymentResourceGroup'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: deploymentResourceGroupName
  location: azureLocation
}

module aksarcModule 'aksarc.bicep' = {
  name: '${deployment().name}-aksarc'
  scope: resourceGroup(deploymentResourceGroupName)
  params:{
    kubernetesVersion: kubernetesVersion
    controlPlaneVMSize: controlPlaneVMSize
    controlPlaneNodeCount: controlPlaneNodeCount
    nodePoolName: nodePoolName
    nodePoolVMSize: nodePoolVMSize
    nodePoolLabel: nodePoolLabel
    nodePoolLabelValue: nodePoolLabelValue
    nodePoolTaint: nodePoolTaint
    networkProfileLoadBalancerCount: networkProfileLoadBalancerCount
    netWorkProfilNetworkPolicy: netWorkProfilNetworkPolicy
    connectedClusterName: connectedClusterName
    controlPlaneHostIP: controlPlaneHostIP
    sshPublicKey: sshPublicKey
    nodePoolOSType: nodePoolOSType
    nodePoolCount: nodePoolCount
    customLocationResourceID: customLocationResourceID
    azureLocation: azureLocation
    logicalNetworkName: logicalNetworkName
  }
  dependsOn: [
    deploymentResourceGroup
  ]
}
