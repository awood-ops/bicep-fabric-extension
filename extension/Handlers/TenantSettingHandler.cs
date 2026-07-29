using System.Net.Http.Headers;
using System.Net.Http.Json;
using Bicep.Local.Extension.Host.Handlers;

public class TenantSettingHandler(IHttpClientFactory httpClientFactory) : TypedResourceHandler<TenantSetting, TenantSettingIdentifiers>
{
    private const string BaseUrl = "https://api.fabric.microsoft.com/v1";

    protected override Task<ResourceResponse> Preview(ResourceRequest request, CancellationToken cancellationToken)
        => Task.FromResult(GetResponse(request));

    protected override async Task<ResourceResponse> CreateOrUpdate(ResourceRequest request, CancellationToken cancellationToken)
    {
        await UpdateAsync(httpClientFactory, request.Properties.Name, request.Properties.Enabled, request.Properties.EnabledSecurityGroups, cancellationToken);
        return GetResponse(request);
    }

    protected override async Task<ResourceResponse> Delete(ReferenceRequest request, CancellationToken cancellationToken)
    {
        // Fabric tenant settings aren't deletable - there's no DELETE endpoint, only update. Removing
        // this resource from a template disables the setting and clears its group scope instead, which
        // is the closest equivalent of "undoing" a declarative change.
        await UpdateAsync(httpClientFactory, request.Identifiers.Name, enabled: false, enabledSecurityGroups: null, cancellationToken);
        return GetResponse(request, properties: null);
    }

    protected override TenantSettingIdentifiers GetIdentifiers(TenantSetting properties)
        => new() { Name = properties.Name };

    private static async Task UpdateAsync(IHttpClientFactory httpClientFactory, string name, bool enabled, TenantSettingSecurityGroup[]? enabledSecurityGroups, CancellationToken cancellationToken)
    {
        var http = httpClientFactory.CreateClient();
        var token = await FabricAuth.GetAccessTokenAsync(http, cancellationToken);
        http.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var body = new
        {
            enabled,
            enabledSecurityGroups = (enabledSecurityGroups ?? [])
                .Select(g => new { graphId = g.GraphId, name = g.Name })
                .ToArray(),
        };

        using var response = await http.PostAsJsonAsync($"{BaseUrl}/admin/tenantsettings/{name}/update", body, cancellationToken);
        response.EnsureSuccessStatusCode();
    }
}
