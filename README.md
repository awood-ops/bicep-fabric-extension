# bicep-fabric-extension

A [Bicep local extension](https://github.com/Azure/bicep/blob/main/docs/experimental/local-deploy-dotnet-quickstart.md) for Microsoft Fabric, covering `Workspace`, `Domain`, and `TenantSetting` resources (`Create`/`Delete`, `Create`/`Update` for the latter), plus the Entra security groups, service principal, Fabric capacity, and Key Vault around it, all declared as Bicep.

Written up in full on the blog: [awood.tech](https://awood.tech).

## Layout

- `capacity/` - Fabric F2 capacity via the [AVM module](https://github.com/Azure/bicep-registry-modules/tree/main/avm/res/fabric/capacity)
- `identity/` - four Entra security groups (one per Fabric workspace role) plus a Key Vault, via the [Microsoft Graph Bicep extension](https://learn.microsoft.com/en-us/graph/templates/bicep/whats-new). Takes the extension's app/service principal object ID as a param rather than creating them, see the note below.
- `extension/` - the local extension itself (.NET, `Azure.Bicep.Local.Extension`), with `Workspace`, `Domain`, and `TenantSetting` resource handlers
- `deploy/` - the `.bicep`/`.bicepparam` that declares domains, nested domains, workspaces (assigned to domains), and a tenant setting, all via the extension

## A known Graph extension limitation

The Microsoft Graph Bicep extension's ARM-side handler for `Microsoft.Graph/applications` currently doesn't expose `appId` or `id` back out at all, not as a cross-resource reference, not even as a plain output on the same resource:

```
The language expression property 'appId' doesn't exist,
available properties are 'uniqueName, displayName, owners'.
```

That rules out creating the app registration and service principal via Bicep if you need their IDs for anything downstream, which you always do. The workaround used here: create them with plain `az ad app create` / `az ad sp create`, and pass the resulting object IDs into `identity/main.bicep` as parameters (`spObjectId`) instead. Everything else, the four RBAC groups, the Key Vault, the role assignment, stays declarative.

## Running it

Requires .NET 10 SDK and Bicep CLI 0.44.1+.

```bash
# One-time: app registration + service principal (see "A known Graph extension limitation" above)
az ad app create --display-name "bicep-fabric-local-ext-lab"
az ad sp create --id <appId-from-above>
az ad app credential reset --id <appId-from-above> --display-name "bicep-local-deploy-lab"

cd identity
bicep build main.bicep --outfile main.json   # sidesteps az CLI's own (newer, currently incompatible) embedded Bicep compiler
az deployment group create --resource-group <rg> --template-file main.json \
  --parameters labAdminObjectId=<your-object-id> spObjectId=<sp-object-id-from-above>

cd ../extension
dotnet publish --configuration release -r win-x64 .
bicep publish-extension --bin-win-x64 ./bin/release/net10.0/win-x64/publish/bicep-ext-fabric.exe --target ./bin/bicep-ext-fabric --force

cd ../deploy
$env:FABRIC_TENANT_ID = "..."
$env:FABRIC_CLIENT_ID = "..."       # the appId from above
$env:FABRIC_CLIENT_SECRET = "..."   # the password from credential reset
bicep local-deploy main.bicepparam
```

The service principal needs to be allow-listed against several Fabric tenant settings first: "Service principals can create workspaces..." and "Service principals can call Fabric public APIs" for `Workspace`, plus "Service principals can access read-only admin APIs" and "...admin APIs used for updates" for `Domain` and `TenantSetting` (the latter two have to be granted by a human/delegated token first, a service principal can't grant itself admin API access). See the blog post for the full setup, including gotchas around capacity-level Contributor permissions, a stale security group that silently blocked admin API access, and a few Bicep language quirks (self-referencing resource loops, a ternary over resource-array indices that doesn't behave the way the docs say it should, and the `.?` safe-dereference operator).

### Running as yourself instead of the service principal

For local iteration, `extension/FabricAuth.cs` falls back to `AzureCliCredential` (from `Azure.Identity`) whenever `FABRIC_CLIENT_ID`/`FABRIC_CLIENT_SECRET`/`FABRIC_TENANT_ID` aren't set, reusing whatever's already logged in via `az login`. Skip the `$env:FABRIC_*` block above and just make sure you're logged in:

```bash
az login
cd deploy
bicep local-deploy main.bicepparam
```

This runs as your own identity rather than the SP, so none of the tenant-setting allow-listing above is needed if you're already a Fabric Administrator, useful for quickly iterating on the extension itself. It's not a substitute for testing the actual least-privilege SP story this lab is about, just a faster inner loop.

`bicep local-deploy` has no state file, so retrying a failed or partial deployment can create duplicate domains/workspaces rather than being idempotent. Fabric domains do reject a duplicate display name outright (`409 Conflict`); workspaces don't, so check what already exists before rerunning after a partial failure.
