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

    [TypeProperty("The Fabric-assigned workspace ID, populated after creation.")]
    public string? Id { get; set; }
}
