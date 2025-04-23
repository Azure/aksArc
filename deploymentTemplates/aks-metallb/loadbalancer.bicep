param parentResourceId string
param loadBalancerName string
param addresses array
@allowed([
  'ARP'
  'BGP'
  'Both'
])
param advertiseMode string
param serviceSelector object = {}
param bgpPeers array = []

resource parent 'Microsoft.Kubernetes/connectedClusters@2024-01-01' existing = {
  name: split(parentResourceId, '/')[8]
}

resource loadBalancer 'Microsoft.KubernetesRuntime/loadBalancers@2024-03-01' = {
  scope: parent
  name: loadBalancerName
  properties: {
    addresses: addresses
    advertiseMode: advertiseMode
    serviceSelector: serviceSelector
    bgpPeers: bgpPeers
  }
}
