
targetScope='resourceGroup'

param customLocationResourceID string
param provisionedClusterName string

// Logical network
param logicalNetworkName string

// Aks Arc cluster
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
param nodePoolTaints array
param netWorkProfilNetworkPolicy string
param networkProfileLoadBalancerCount int
param enableAzureHybridBenefit string
param enableNfsCsiDriver bool
param enableSmbCsiDriver bool

module aksarcModule 'aksarc.bicep' = {
  name: '${deployment().name}-aksarc'
  params:{
    kubernetesVersion: kubernetesVersion
    controlPlaneVMSize: controlPlaneVMSize
    controlPlaneNodeCount: controlPlaneNodeCount
    nodePoolName: nodePoolName
    nodePoolVMSize: nodePoolVMSize
    nodePoolLabel: nodePoolLabel
    nodePoolLabelValue: nodePoolLabelValue
    nodePoolTaints: nodePoolTaints
    networkProfileLoadBalancerCount: networkProfileLoadBalancerCount
    netWorkProfilNetworkPolicy: netWorkProfilNetworkPolicy
    provisionedClusterName: provisionedClusterName
    controlPlaneHostIP: controlPlaneHostIP
    sshPublicKey: sshPublicKey
    nodePoolOSType: nodePoolOSType
    nodePoolCount: nodePoolCount
    customLocationResourceID: customLocationResourceID
    logicalNetworkName: logicalNetworkName
    enableAzureHybridBenefit: enableAzureHybridBenefit
    enableNfsCsiDriver: enableNfsCsiDriver
    enableSmbCsiDriver: enableSmbCsiDriver
  }
}
