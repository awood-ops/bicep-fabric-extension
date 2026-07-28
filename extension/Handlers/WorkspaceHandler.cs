using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json.Serialization;
using Bicep.Local.Extension.Host.Handlers;

public class WorkspaceHandler(IHttpClientFactory httpClientFactory) : TypedResourceHandler<Workspace, WorkspaceIdentifiers>
{
    private const string BaseUrl = "https://api.fabric.microsoft.com/v1";

    protected override Task<ResourceResponse> Preview(ResourceRequest request, CancellationToken cancellationToken)
        => Task.FromResult(GetResponse(request));

    protected override async Task<ResourceResponse> CreateOrUpdate(ResourceRequest request, CancellationToken cancellationToken)
    {
        var http = await GetAuthenticatedClientAsync(httpClientFactory, cancellationToken);

        // Deliberately no capacityId here: assigning a workspace to a capacity at creation time
        // requires the caller to hold Contributor (or Admin) permission *on the capacity*, which
        // has no public REST API to grant to a service principal (portal-UI-only, as of writing).
        // The workspace is created capacity-less instead, and capacity assignment is done as a
        // separate step by a human who already holds the capacity Admin role.
        var createBody = new
        {
            displayName = request.Properties.DisplayName,
            description = request.Properties.Description,
        };

        using var response = await http.PostAsJsonAsync($"{BaseUrl}/workspaces", createBody, cancellationToken);
        response.EnsureSuccessStatusCode();

        var created = await response.Content.ReadFromJsonAsync<WorkspaceApiResponse>(cancellationToken: cancellationToken)
            ?? throw new InvalidOperationException("Failed to deserialize workspace create response.");

        request.Properties.Id = created.Id;

        // The SP is Admin on the workspace it just created, but nobody else is yet -
        // grant the human admin the Admin role too so they can act on the workspace afterward
        // (including the capacity assignment step above).
        var roleAssignmentBody = new
        {
            principal = new { id = request.Properties.AdminObjectId, type = "User" },
            role = "Admin",
        };

        using var roleResponse = await http.PostAsJsonAsync($"{BaseUrl}/workspaces/{created.Id}/roleAssignments", roleAssignmentBody, cancellationToken);
        roleResponse.EnsureSuccessStatusCode();

        return GetResponse(request);
    }

    protected override async Task<ResourceResponse> Delete(ReferenceRequest request, CancellationToken cancellationToken)
    {
        var http = await GetAuthenticatedClientAsync(httpClientFactory, cancellationToken);

        // Delete only gets the identifiers (displayName), not the Fabric-assigned ID,
        // so the workspace has to be resolved by listing and matching on displayName first.
        var list = await http.GetFromJsonAsync<WorkspaceListResponse>($"{BaseUrl}/workspaces", cancellationToken)
            ?? throw new InvalidOperationException("Failed to list workspaces.");

        var match = list.Value.FirstOrDefault(w => w.DisplayName == request.Identifiers.DisplayName)
            ?? throw new ResourceErrorException("NotFound", $"No workspace found with display name '{request.Identifiers.DisplayName}'.");

        using var response = await http.DeleteAsync($"{BaseUrl}/workspaces/{match.Id}", cancellationToken);
        response.EnsureSuccessStatusCode();

        return GetResponse(request, properties: null);
    }

    protected override WorkspaceIdentifiers GetIdentifiers(Workspace properties)
        => new() { DisplayName = properties.DisplayName };

    private static async Task<HttpClient> GetAuthenticatedClientAsync(IHttpClientFactory httpClientFactory, CancellationToken cancellationToken)
    {
        var http = httpClientFactory.CreateClient();
        var token = await FabricAuth.GetAccessTokenAsync(http, cancellationToken);
        http.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
        return http;
    }

    private class WorkspaceApiResponse
    {
        [JsonPropertyName("id")]
        public required string Id { get; set; }

        [JsonPropertyName("displayName")]
        public required string DisplayName { get; set; }
    }

    private class WorkspaceListResponse
    {
        [JsonPropertyName("value")]
        public required List<WorkspaceApiResponse> Value { get; set; }
    }
}
