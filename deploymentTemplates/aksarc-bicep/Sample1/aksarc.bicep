param azureLocation string
param customLocationResourceID string

// Logical network
param logicalNetworkName string
param dnsServers array
param addressPrefix string
param vmSwitchName string
param ipAllocationMethod string
param vlan int
param vipPoolStart string
param vipPoolEnd string
param nextHopIpAddress string

// Provisioned cluster
param connectedClusterName string
param sshPublicKey string
param controlPlaneHostIP string
param kubernetesVersion string
param controlPlaneVMSize string
param controlPlaneNodeCount int
param nodePoolName string
param nodePoolVMSize string
@allowed(['Linux', 'Windows'])
param nodePoolOSType string
param nodePoolCount int
param nodePoolLabel string
param nodePoolLabelValue string
param nodePoolTaint string
param netWorkProfilNetworkPolicy string
param networkProfileLoadBalancerCount int

// You can replace the creation code with the below commented-out code to reference an existing logical network.
resource logicalNetwork 'Microsoft.AzureStackHCI/logicalNetworks@2024-01-01' existing = {
  name: logicalNetworkName
}

// Create the connected cluster.
// This is the Arc representation of the AKS cluster, used to create a Managed Identity for the provisioned cluster.
resource connectedCluster 'Microsoft.Kubernetes/ConnectedClusters@2024-01-01' = {
  location: azureLocation
  name: connectedClusterName
  identity: {
    type: 'SystemAssigned'
  }
  kind: 'ProvisionedCluster'
  properties: {
    // agentPublicKeyCertificate must be empty for provisioned clusters that will be created next.
    agentPublicKeyCertificate: ''
    aadProfile: {
      enableAzureRBAC: false
    }
  }
}

// Create the provisioned cluster instance. 
// This is the actual AKS cluster and provisioned on your Azure Local cluster via the Arc Resource Bridge.
resource provisionedClusterInstance 'Microsoft.HybridContainerService/provisionedClusterInstances@2024-01-01' = {
  name: 'default'
  scope: connectedCluster
  extendedLocation: {
    type: 'CustomLocation'
    name: customLocationResourceID
  }
  properties: {
    kubernetesVersion: kubernetesVersion
    linuxProfile: {
      ssh: {
        publicKeys: [
          {
            keyData: sshPublicKey
          }
        ]
      }
    }
    controlPlane: {
      count: controlPlaneNodeCount
      controlPlaneEndpoint: {
        hostIP: controlPlaneHostIP
      }
      vmSize: controlPlaneVMSize
    }
    networkProfile: {
      networkPolicy: netWorkProfilNetworkPolicy
      loadBalancerProfile: {
        count: networkProfileLoadBalancerCount
      }
    }
    agentPoolProfiles: [
      {
        name: nodePoolName
        count: nodePoolCount
        vmSize: nodePoolVMSize
        osType: nodePoolOSType
        nodeLabels: {
          '${nodePoolLabel}': nodePoolLabelValue
        }
        nodeTaints: [
          nodePoolTaint
        ]
      }
    ]
    cloudProviderProfile: {
      infraNetworkProfile: {
        vnetSubnetIds: [
          logicalNetwork.id
        ]
      }
    }
    storageProfile: {
      nfsCsiDriver: {
        enabled: true
      }
      smbCsiDriver: {
        enabled: true
      }
    }
  }
}
