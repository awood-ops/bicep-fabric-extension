using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json.Serialization;
using Bicep.Local.Extension.Host.Handlers;

public class DomainHandler(IHttpClientFactory httpClientFactory) : TypedResourceHandler<Domain, DomainIdentifiers>
{
    private const string BaseUrl = "https://api.fabric.microsoft.com/v1";

    protected override Task<ResourceResponse> Preview(ResourceRequest request, CancellationToken cancellationToken)
        => Task.FromResult(GetResponse(request));

    protected override async Task<ResourceResponse> CreateOrUpdate(ResourceRequest request, CancellationToken cancellationToken)
    {
        var http = await GetAuthenticatedClientAsync(httpClientFactory, cancellationToken);

        var createBody = new
        {
            displayName = request.Properties.DisplayName,
            description = request.Properties.Description,
            parentDomainId = request.Properties.ParentDomainId,
        };

        using var response = await http.PostAsJsonAsync($"{BaseUrl}/admin/domains", createBody, cancellationToken);
        response.EnsureSuccessStatusCode();

        var created = await response.Content.ReadFromJsonAsync<DomainApiResponse>(cancellationToken: cancellationToken)
            ?? throw new InvalidOperationException("Failed to deserialize domain create response.");

        request.Properties.Id = created.Id;

        // Unlike the capacity Contributor permission (portal-UI-only, no public API), domain role
        // assignment genuinely is a REST API, and it accepts groups and service principals directly.
        if (request.Properties.AdminGroupIds is { Length: > 0 } admins)
            await BulkAssignAsync(http, created.Id, "Admins", admins, cancellationToken);

        if (request.Properties.ContributorGroupIds is { Length: > 0 } contributors)
            await BulkAssignAsync(http, created.Id, "Contributors", contributors, cancellationToken);

        return GetResponse(request);
    }

    protected override async Task<ResourceResponse> Delete(ReferenceRequest request, CancellationToken cancellationToken)
    {
        var http = await GetAuthenticatedClientAsync(httpClientFactory, cancellationToken);

        // Delete only gets the identifiers (displayName), not the Fabric-assigned ID,
        // so the domain has to be resolved by listing and matching on displayName first -
        // same shape as WorkspaceHandler.Delete.
        var list = await http.GetFromJsonAsync<DomainListResponse>($"{BaseUrl}/admin/domains", cancellationToken)
            ?? throw new InvalidOperationException("Failed to list domains.");

        var match = list.Domains.FirstOrDefault(d => d.DisplayName == request.Identifiers.DisplayName)
            ?? throw new ResourceErrorException("NotFound", $"No domain found with display name '{request.Identifiers.DisplayName}'.");

        using var response = await http.DeleteAsync($"{BaseUrl}/admin/domains/{match.Id}", cancellationToken);
        response.EnsureSuccessStatusCode();

        return GetResponse(request, properties: null);
    }

    protected override DomainIdentifiers GetIdentifiers(Domain properties)
        => new() { DisplayName = properties.DisplayName };

    private static async Task BulkAssignAsync(HttpClient http, string domainId, string roleType, string[] groupIds, CancellationToken cancellationToken)
    {
        var body = new
        {
            type = roleType,
            principals = groupIds.Select(id => new { id, type = "Group" }).ToArray(),
        };

        using var response = await http.PostAsJsonAsync($"{BaseUrl}/admin/domains/{domainId}/roleAssignments/bulkAssign", body, cancellationToken);
        response.EnsureSuccessStatusCode();
    }

    private static async Task<HttpClient> GetAuthenticatedClientAsync(IHttpClientFactory httpClientFactory, CancellationToken cancellationToken)
    {
        var http = httpClientFactory.CreateClient();
        var token = await FabricAuth.GetAccessTokenAsync(http, cancellationToken);
        http.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
        return http;
    }

    private class DomainApiResponse
    {
        [JsonPropertyName("id")]
        public required string Id { get; set; }

        [JsonPropertyName("displayName")]
        public required string DisplayName { get; set; }
    }

    private class DomainListResponse
    {
        [JsonPropertyName("domains")]
        public required List<DomainApiResponse> Domains { get; set; }
    }
}
