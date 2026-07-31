using Azure.Bicep.Types.Concrete;
using Bicep.Local.Extension.Types.Attributes;

public class WorkspaceIdentifiers
{
    [TypeProperty(
        "The workspace display name. This is what identifies the resource to Bicep, since the Fabric-assigned workspace ID isn't known until after creation.",
        ObjectTypePropertyFlags.Identifier | ObjectTypePropertyFlags.Required)]
    public required string DisplayName { get; set; }
}

[ResourceType("Workspace")]
public class Workspace : WorkspaceIdentifiers
{
    [TypeProperty("Optional workspace description.")]
    public string? Description { get; set; }

    [TypeProperty(
        "Entra object ID of a user to grant the Admin workspace role, in addition to this extension's own service principal. " +
        "Needed because capacity assignment requires a workspace Admin role the SP doesn't automatically extend to a human.",
        ObjectTypePropertyFlags.Required)]
    public required string AdminObjectId { get; set; }

    [TypeProperty(
        "The Fabric-assigned domain ID to assign this workspace to. Resolve this from a Domain resource's " +
        "id property rather than hardcoding a GUID.")]
    public string? DomainId { get; set; }

    [TypeProperty("The Fabric-assigned workspace ID, populated after creation.")]
    public string? Id { get; set; }
}

public class DomainIdentifiers
{
    [TypeProperty(
        "The domain display name. This is what identifies the resource to Bicep, since the Fabric-assigned domain ID isn't known until after creation.",
        ObjectTypePropertyFlags.Identifier | ObjectTypePropertyFlags.Required)]
    public required string DisplayName { get; set; }
}

[ResourceType("Domain")]
public class Domain : DomainIdentifiers
{
    [TypeProperty("Optional domain description.")]
    public string? Description { get; set; }

    [TypeProperty("Optional parent domain ID, for nested domains.")]
    public string? ParentDomainId { get; set; }

    [TypeProperty(
        "Entra security group object IDs to assign the domain Admins role, via the bulk role-assignment API. " +
        "Unlike capacity Contributor permissions, this is a real REST API that accepts groups and service " +
        "principals directly (no portal-only step). Scoped to groups here since that's the pattern the rest " +
        "of this lab uses for RBAC, though the API also accepts individual users and service principals.")]
    public string[]? AdminGroupIds { get; set; }

    [TypeProperty("Entra security group object IDs to assign the domain Contributors role.")]
    public string[]? ContributorGroupIds { get; set; }

    [TypeProperty("The Fabric-assigned domain ID, populated after creation.")]
    public string? Id { get; set; }
}

public class TenantSettingIdentifiers
{
    [TypeProperty(
        "The tenant setting's technical name (e.g. 'ServicePrincipalAccessToCreateMonitoringWorkspaceSetting'), as returned by GET /v1/admin/tenantsettings.",
        ObjectTypePropertyFlags.Identifier | ObjectTypePropertyFlags.Required)]
    public required string Name { get; set; }
}

[ResourceType("TenantSetting")]
public class TenantSetting : TenantSettingIdentifiers
{
    [TypeProperty("Whether the setting is enabled.", ObjectTypePropertyFlags.Required)]
    public required bool Enabled { get; set; }

    [TypeProperty(
        "Entra security groups the setting is scoped to, matching the Fabric API's enabledSecurityGroups " +
        "shape directly. Fabric tenant settings have no real delete operation, so removing this resource " +
        "from a template disables the setting and clears this list rather than deleting anything.")]
    public TenantSettingSecurityGroup[]? EnabledSecurityGroups { get; set; }

    [TypeProperty(
        "Entra security groups explicitly excluded from the setting. Only meaningful for settings whose " +
        "canSpecifySecurityGroups is true; left unset the property is omitted from the update payload " +
        "entirely, since sending it against a setting that doesn't support group scoping is rejected.")]
    public TenantSettingSecurityGroup[]? ExcludedSecurityGroups { get; set; }

    [TypeProperty(
        "Whether workspace admins may override this setting at workspace level. Only a subset of settings " +
        "are delegatable; omitted from the update payload when unset rather than defaulting to false, so " +
        "a non-delegatable setting isn't sent a property it will reject.")]
    public bool? DelegateToWorkspace { get; set; }
}

public class TenantSettingSecurityGroup
{
    [TypeProperty("The Entra group's object ID.", ObjectTypePropertyFlags.Required)]
    public required string GraphId { get; set; }

    [TypeProperty("The Entra group's display name.", ObjectTypePropertyFlags.Required)]
    public required string Name { get; set; }
}
