# Changelog

All notable changes to this project are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versioning follows
[Semantic Versioning](https://semver.org/spec/v2.0.0.html). While this is pre-1.0, breaking changes
can land in a minor bump, and they're called out explicitly below.

The version here is the extension's own version, declared once in `extension/FabricLocalExtension.csproj`
and read back off the assembly at startup. Tags are `vMAJOR.MINOR.PATCH` and match it.

## [Unreleased]

### Added

- `docs/tenant-settings-guidance.md`, giving rationale and a preferred posture for all 169 tenant settings,
  grounded in the Fabric tenant settings index, the Well-Architected security guidance, and the
  Microsoft cloud security benchmark baseline for Fabric.
- `-Sanitise` switch on `scripts/get-tenant-settings.ps1`, replacing security group object IDs and
  names with placeholders for output destined somewhere public.

### Changed

- README restructured to lead with what the repo does and why, a worked Bicep example, and a table of
  the layout rather than a bare list.

## [0.2.0] - 2026-07-31

### Added

- `tenantSettings` array param, so any number of tenant settings can be declared rather than the
  single one the template started with.
- `delegateToCapacity` and `delegateToDomain` on `TenantSetting`. The API exposes three independent
  delegation scopes and only `delegateToWorkspace` was modelled; a setting can support any
  combination of them.
- `properties` on `TenantSetting`, for the handful of settings carrying typed values beyond the
  on/off flag (e.g. `ConfigureFabricIdentityTenantLimit`, which holds an `Integer`).
- `excludedSecurityGroups` on `TenantSetting`, from the API contract. No setting in the tenant this
  was built against actually populates it.
- `scripts/get-tenant-settings.ps1`, which dumps the tenant's live settings, optionally as a
  paste-ready `param tenantSettings = [...]` block. `-Sanitise` replaces security group object IDs
  and names with placeholders for output destined somewhere public.
- `deploy/tenant-settings.all.bicepparam`, a sanitised capture of all 169 settings the reference
  tenant exposes, as a lookup for names and supported properties. (Superseded in Unreleased by
  `tenant-settings.baseline.bicepparam`.)

### Changed

- **Breaking.** `tenantSettingName` (string) is replaced by `tenantSettings` (array). Move the old
  scalar into a single-element array to migrate.
- **Breaking.** `spCreatorsGroupId` and `spCreatorsGroupName` params are removed. Group scoping now
  lives in each `tenantSettings` entry's `enabledSecurityGroups`, so it isn't split across two
  places.
- The tenant setting update body is now built as a dictionary, with unset optional properties
  omitted from the JSON rather than serialised as null. The API rejects group scoping on settings
  whose `canSpecifySecurityGroups` is false, and the delegation flags on settings that don't support
  them, so "not specified" has to mean absent. Passing an empty array or `false` is a real value and
  will be sent.
- Failed tenant setting updates now include the API's response body. A 400 here names the property
  it objected to, which `EnsureSuccessStatusCode()` was discarding.
- The extension version is declared once in the csproj and read off the assembly, instead of being a
  literal in `Program.cs`.

### Fixed

- The example params referenced a tenant setting named `CreateWorkspaces`, which doesn't exist. The
  real name is `CreateAppWorkspaces`. The portal shows "Create workspaces" while the API kept the
  legacy "App", which is the whole reason these need reading from the API rather than inferring.

## [0.1.0] - 2026-07-30

### Added

- Bicep local extension for Fabric (.NET, `Azure.Bicep.Local.Extension`) with `Workspace`, `Domain`,
  and `TenantSetting` resource handlers.
- Entra security groups, service principal, and Key Vault via the Microsoft Graph Bicep extension.
- Fabric F2 capacity via the AVM module.
- `deploy/` template covering domains, nested domains, workspaces assigned to domains, and a single
  tenant setting.
- `AzureCliCredential` fallback when the `FABRIC_CLIENT_ID`/`SECRET`/`TENANT_ID` env vars aren't set,
  for a faster local inner loop.
- Architecture diagram in the README.

### Fixed

- Workspace admin role grants tolerate a 409 when the role assignment already exists.

[Unreleased]: https://github.com/awood-ops/bicep-fabric-extension/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/awood-ops/bicep-fabric-extension/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/awood-ops/bicep-fabric-extension/releases/tag/v0.1.0
