# bicep-fabric-extension

A [Bicep local extension](https://github.com/Azure/bicep/blob/main/docs/experimental/local-deploy-dotnet-quickstart.md) for Microsoft Fabric workspaces, `Create`/`Delete` only, plus the Entra security groups, service principal, Fabric capacity, and Key Vault around it, all declared as Bicep.

Written up in full on the blog: [awood.tech](https://awood.tech).

## Layout

- `capacity/` - Fabric F2 capacity via the [AVM module](https://github.com/Azure/bicep-registry-modules/tree/main/avm/res/fabric/capacity)
- `identity/` - four Entra security groups (one per Fabric workspace role), an app registration + service principal, and a Key Vault, all via the [Microsoft Graph Bicep extension](https://learn.microsoft.com/en-us/graph/templates/bicep/whats-new)
- `extension/` - the local extension itself (.NET, `Azure.Bicep.Local.Extension`)
- `deploy/` - the `.bicep`/`.bicepparam` that actually declares a `Workspace` resource via the extension

## Running it

Requires .NET 10 SDK and Bicep CLI 0.44.1+.

```bash
cd extension
dotnet publish --configuration release -r win-x64 .
bicep publish-extension --bin-win-x64 ./bin/release/net10.0/win-x64/publish/bicep-ext-fabric.exe --target ./bin/bicep-ext-fabric --force

cd ../deploy
$env:FABRIC_TENANT_ID = "..."
$env:FABRIC_CLIENT_ID = "..."
$env:FABRIC_CLIENT_SECRET = "..."
bicep local-deploy main.bicepparam
```

The service principal needs to be allow-listed against the Fabric tenant settings "Service principals can create workspaces..." and "Service principals can call Fabric public APIs" first (see the blog post for the full setup, including a gotcha around capacity-level Contributor permissions).
