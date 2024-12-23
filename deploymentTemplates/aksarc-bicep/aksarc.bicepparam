using './main.bicep'
param ClusterName = 'aksarc-bicep'
param SSHPublicKey = 'SSH_Public_Key'
param LogicalNetworkName = 'LNet_Name'
param CustomLocationName = 'Custom_Location_Name'
param aksNodePoolOSType = 'Linux'
param aksNodePoolNodeCount = 1
param aksNodePoolName = 'np1'
param aksControlPlaneNodeSize = 'x.x.x.x'