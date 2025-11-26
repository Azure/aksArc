
targetScope='resourceGroup'

param connectedClusterName string
param nodePoolName string
param nodePoolVMSize string
param nodePoolCount int
param nodePoolOSType string
param enableAutoScaling bool
param minCount int
param maxCount int
param nodeLabels object
param nodeTaints array

module nodepoolModule 'nodepool.bicep' = {
  name: '${deployment().name}-nodepool'
  params: {
    connectedClusterName: connectedClusterName
    nodePoolName: nodePoolName
    nodePoolVMSize: nodePoolVMSize
    nodePoolCount: nodePoolCount
    nodePoolOSType: nodePoolOSType
    enableAutoScaling: enableAutoScaling
    minCount: minCount
    maxCount: maxCount
    nodeLabels: nodeLabels
    nodeTaints: nodeTaints
  }
}
