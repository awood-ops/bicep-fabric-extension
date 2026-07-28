targetScope = 'subscription'

@description('Fabric capacity name. Constraint from ARM: lowercase alphanumeric only, no hyphens.')
param capacityName string = 'fcbiceplabuks01'

@description('Resource group name for the lab.')
param resourceGroupName string = 'rg-bicep-fabric-lab-dev-uksouth-01'

param location string = 'uksouth'

@description('UPN of the capacity administrator.')
param adminUpn string

resource rg 'Microsoft.Resources/resourceGroups@2025-04-01' = {
  name: resourceGroupName
  location: location
}

module capacity 'br/public:avm/res/fabric/capacity:0.1.2' = {
  name: 'deploy-fabric-capacity'
  scope: rg
  params: {
    name: capacityName
    location: location
    adminMembers: [
      adminUpn
    ]
    skuName: 'F2'
  }
}

output capacityId string = capacity.outputs.resourceId
output resourceGroupName string = rg.name
