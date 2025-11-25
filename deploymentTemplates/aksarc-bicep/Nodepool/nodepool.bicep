param provisionedClusterName string
param nodePoolName string
param nodePoolVMSize string
param nodePoolCount int
@allowed(['Linux', 'Windows'])
param nodePoolOSType string
param enableAutoScaling bool = false
param minCount int = 1
param maxCount int = 5
param nodeLabels object = {}
param nodeTaints array = []

// Reference the existing connected cluster
resource connectedCluster 'Microsoft.Kubernetes/ConnectedClusters@2024-01-01' existing = {
  name: provisionedClusterName
}

// Create or update the nodepool
resource agentPool 'Microsoft.HybridContainerService/provisionedClusterInstances/agentPools@2024-01-01' = {
  name: 'default/${nodePoolName}'
  scope: connectedCluster
  properties: {
    count: nodePoolCount
    osType: nodePoolOSType
    vmSize: nodePoolVMSize
    enableAutoScaling: enableAutoScaling
    minCount: enableAutoScaling ? minCount : null
    maxCount: enableAutoScaling ? maxCount : null
    nodeLabels: !empty(nodeLabels) ? nodeLabels : null
    nodeTaints: !empty(nodeTaints) ? nodeTaints : null
  }
}
