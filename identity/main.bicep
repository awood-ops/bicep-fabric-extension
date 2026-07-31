extension microsoftGraphV1

@description('Object ID of the human admin to add to the workspace admin group (so the workspace is visible in the portal during the lab).')
param labAdminObjectId string

@description('''
Object ID of the extension's service principal. Created outside this template (az ad app create
+ az ad sp create), not via the Microsoft.Graph/applications and servicePrincipals resources -
the Graph extension's ARM-side handler currently can't expose appId/id back out at all, even as
a same-resource output ("The language expression property 'appId' doesn't exist"), which rules out
both creating the SP inline and reading its id back out of this template.
''')
param spObjectId string

@description('Location for the Key Vault.')
param location string = resourceGroup().location

var workspaceSlug = 'bicepextlab'

resource sgAdmin 'Microsoft.Graph/groups@v1.0' = {
  displayName: 'sg-fabric-${workspaceSlug}-admin'
  uniqueName: 'sg-fabric-${workspaceSlug}-admin'
  mailEnabled: false
  mailNickname: 'sg-fabric-${workspaceSlug}-admin'
  securityEnabled: true
  members: {
    relationships: [
      labAdminObjectId
    ]
  }
}

resource sgMember 'Microsoft.Graph/groups@v1.0' = {
  displayName: 'sg-fabric-${workspaceSlug}-member'
  uniqueName: 'sg-fabric-${workspaceSlug}-member'
  mailEnabled: false
  mailNickname: 'sg-fabric-${workspaceSlug}-member'
  securityEnabled: true
}

resource sgContributor 'Microsoft.Graph/groups@v1.0' = {
  displayName: 'sg-fabric-${workspaceSlug}-contributor'
  uniqueName: 'sg-fabric-${workspaceSlug}-contributor'
  mailEnabled: false
  mailNickname: 'sg-fabric-${workspaceSlug}-contributor'
  securityEnabled: true
}

resource sgViewer 'Microsoft.Graph/groups@v1.0' = {
  displayName: 'sg-fabric-${workspaceSlug}-viewer'
  uniqueName: 'sg-fabric-${workspaceSlug}-viewer'
  mailEnabled: false
  mailNickname: 'sg-fabric-${workspaceSlug}-viewer'
  securityEnabled: true
}

// Tenant-setting allow-list group: membership here is what lets the extension's
// service principal call the Fabric "create workspace" API at all.
resource sgSpWorkspaceCreators 'Microsoft.Graph/groups@v1.0' = {
  displayName: 'sg-fabric-sp-workspace-creators'
  uniqueName: 'sg-fabric-sp-workspace-creators'
  mailEnabled: false
  mailNickname: 'sg-fabric-sp-workspace-creators'
  securityEnabled: true
  members: {
    relationships: [
      spObjectId
    ]
  }
}

// The workspace's own service principal is the officially-supported identity for Key Vault
// access. Fabric's "workspace identity" feature doesn't list Key Vault as a supported
// connection target (ADLS Gen2, SQL Server, Blobs and Azure Analysis Services only), so
// Key Vault access is wired to this SP rather than to the workspace identity.
resource keyVault 'Microsoft.KeyVault/vaults@2024-11-01' = {
  name: 'kv-bicepfablab-uks-02'
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enableSoftDelete: true
  }
}

resource kvSecretsUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, 'bicep-fabric-local-ext-lab', 'KeyVaultSecretsUser')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
    principalId: spObjectId
    principalType: 'ServicePrincipal'
  }
}

output adminGroupId string = sgAdmin.id
output memberGroupId string = sgMember.id
output contributorGroupId string = sgContributor.id
output viewerGroupId string = sgViewer.id
output spCreatorsGroupId string = sgSpWorkspaceCreators.id
output keyVaultName string = keyVault.name
