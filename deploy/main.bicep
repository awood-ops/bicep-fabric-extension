targetScope = 'local'
extension fabric

@description('The workspace display name.')
param workspaceName string

@description('Entra object ID of the human to grant the Admin workspace role.')
param adminObjectId string

resource ws 'Workspace' = {
  displayName: workspaceName
  description: 'Created by the bicep-ext-fabric local extension lab.'
  adminObjectId: adminObjectId
}

output workspaceId string = ws.id
