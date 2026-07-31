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
        await UpdateAsync(httpClientFactory, request.Properties, cancellationToken);
        return GetResponse(request);
    }

    protected override async Task<ResourceResponse> Delete(ReferenceRequest request, CancellationToken cancellationToken)
    {
        // Fabric tenant settings aren't deletable - there's no DELETE endpoint, only update. Removing
        // this resource from a template disables the setting and clears its group scope instead, which
        // is the closest equivalent of "undoing" a declarative change. delegateToWorkspace is left out
        // of the payload rather than forced to false, since it isn't valid on every setting.
        await UpdateAsync(
            httpClientFactory,
            new TenantSetting { Name = request.Identifiers.Name, Enabled = false },
            cancellationToken);
        return GetResponse(request, properties: null);
    }

    protected override TenantSettingIdentifiers GetIdentifiers(TenantSetting properties)
        => new() { Name = properties.Name };

    private static async Task UpdateAsync(IHttpClientFactory httpClientFactory, TenantSetting setting, CancellationToken cancellationToken)
    {
        var http = httpClientFactory.CreateClient();
        var token = await FabricAuth.GetAccessTokenAsync(http, cancellationToken);
        http.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        // Built as a dictionary rather than an anonymous type so unset optional properties are omitted
        // from the JSON entirely. The update endpoint rejects delegateToWorkspace on settings that
        // aren't delegatable, and the security-group collections on settings whose
        // canSpecifySecurityGroups is false - so "not specified" has to serialise as absent, not null.
        var body = new Dictionary<string, object?> { ["enabled"] = setting.Enabled };

        if (setting.EnabledSecurityGroups is not null)
        {
            body["enabledSecurityGroups"] = MapGroups(setting.EnabledSecurityGroups);
        }

        if (setting.ExcludedSecurityGroups is not null)
        {
            body["excludedSecurityGroups"] = MapGroups(setting.ExcludedSecurityGroups);
        }

        // Three independent delegation scopes - a setting supports none, one, or several of them, and the
        // GET response simply omits the ones that don't apply. Mirror that on the way back in.
        if (setting.DelegateToWorkspace is not null)
        {
            body["delegateToWorkspace"] = setting.DelegateToWorkspace.Value;
        }

        if (setting.DelegateToCapacity is not null)
        {
            body["delegateToCapacity"] = setting.DelegateToCapacity.Value;
        }

        if (setting.DelegateToDomain is not null)
        {
            body["delegateToDomain"] = setting.DelegateToDomain.Value;
        }

        if (setting.Properties is not null)
        {
            body["properties"] = setting.Properties
                .Select(p => new { name = p.Name, value = p.Value, type = p.Type })
                .ToArray();
        }

        using var response = await http.PostAsJsonAsync($"{BaseUrl}/admin/tenantsettings/{setting.Name}/update", body, cancellationToken);

        if (!response.IsSuccessStatusCode)
        {
            // The bare status code alone makes these hard to diagnose - a 400 here is usually the API
            // objecting to a specific property for this particular setting, and it says which one.
            var detail = await response.Content.ReadAsStringAsync(cancellationToken);
            throw new InvalidOperationException(
                $"Updating tenant setting '{setting.Name}' failed with {(int)response.StatusCode} {response.ReasonPhrase}: {detail}");
        }
    }

    private static object[] MapGroups(TenantSettingSecurityGroup[] groups)
        => groups.Select(g => new { graphId = g.GraphId, name = g.Name }).ToArray<object>();
}
