using System.Net.Http.Json;
using System.Text.Json.Serialization;
using Azure.Core;
using Azure.Identity;

internal static class FabricAuth
{
    private static readonly string[] FabricScope = ["https://api.fabric.microsoft.com/.default"];

    public static Task<string> GetAccessTokenAsync(HttpClient http, CancellationToken cancellationToken)
    {
        var clientId = Environment.GetEnvironmentVariable("FABRIC_CLIENT_ID");
        var clientSecret = Environment.GetEnvironmentVariable("FABRIC_CLIENT_SECRET");
        var tenantId = Environment.GetEnvironmentVariable("FABRIC_TENANT_ID");

        return !string.IsNullOrEmpty(clientId) && !string.IsNullOrEmpty(clientSecret) && !string.IsNullOrEmpty(tenantId)
            ? GetTokenViaClientCredentialsAsync(http, tenantId, clientId, clientSecret, cancellationToken)
            : GetTokenViaAzureCliAsync(cancellationToken);
    }

    // SP path: the extension's own least-privilege service principal, allow-listed against the
    // tenant settings this lab is actually about. Used whenever FABRIC_CLIENT_ID/SECRET/TENANT_ID
    // are set.
    private static async Task<string> GetTokenViaClientCredentialsAsync(
        HttpClient http, string tenantId, string clientId, string clientSecret, CancellationToken cancellationToken)
    {
        var tokenEndpoint = $"https://login.microsoftonline.com/{tenantId}/oauth2/v2.0/token";
        var form = new Dictionary<string, string>
        {
            ["grant_type"] = "client_credentials",
            ["client_id"] = clientId,
            ["client_secret"] = clientSecret,
            ["scope"] = FabricScope[0],
        };

        using var response = await http.PostAsync(tokenEndpoint, new FormUrlEncodedContent(form), cancellationToken);
        response.EnsureSuccessStatusCode();

        var payload = await response.Content.ReadFromJsonAsync<TokenResponse>(cancellationToken: cancellationToken)
            ?? throw new InvalidOperationException("Failed to deserialize token response.");

        return payload.AccessToken;
    }

    // Delegated path: reuses whatever's already logged in via `az login`, no SP or secret needed.
    // Convenient for local iteration, but it runs as your own (likely Fabric Administrator) identity
    // rather than the scoped-down SP this lab's identity model builds - fine for a dev loop, not a
    // substitute for testing the actual least-privilege story.
    private static async Task<string> GetTokenViaAzureCliAsync(CancellationToken cancellationToken)
    {
        var credential = new AzureCliCredential();
        var token = await credential.GetTokenAsync(new TokenRequestContext(FabricScope), cancellationToken);
        return token.Token;
    }

    private class TokenResponse
    {
        [JsonPropertyName("access_token")]
        public required string AccessToken { get; set; }
    }
}
