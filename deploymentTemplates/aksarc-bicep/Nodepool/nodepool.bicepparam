using 'main.bicep'

param provisionedClusterName = '<TODO>' // TODO: AKS Arc Cluster Name
param nodePoolName = '<TODO>' // TODO: Node Pool Name
param nodePoolVMSize = 'Standard_A4_v2' // TODO: add your node pool VM size
param nodePoolCount = 3 // TODO: add your node pool node count
param nodePoolOSType = 'Linux' // TODO: 'Linux' or 'Windows'
param enableAutoScaling = false // TODO: true or false
param minCount = 1 // TODO: minimum node count when autoscaling enabled
param maxCount = 10 // TODO: maximum node count when autoscaling enabled
param nodeLabels = {} // TODO: add node labels as key-value pairs
param nodeTaints = [] // TODO: add node taints array
