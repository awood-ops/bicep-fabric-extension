using System.Net.Http.Json;
using System.Text.Json.Serialization;

internal static class FabricAuth
{
    public static async Task<string> GetAccessTokenAsync(HttpClient http, CancellationToken cancellationToken)
    {
        var tenantId = RequireEnvironmentVariable("FABRIC_TENANT_ID");
        var clientId = RequireEnvironmentVariable("FABRIC_CLIENT_ID");
        var clientSecret = RequireEnvironmentVariable("FABRIC_CLIENT_SECRET");

        var tokenEndpoint = $"https://login.microsoftonline.com/{tenantId}/oauth2/v2.0/token";
        var form = new Dictionary<string, string>
        {
            ["grant_type"] = "client_credentials",
            ["client_id"] = clientId,
            ["client_secret"] = clientSecret,
            ["scope"] = "https://api.fabric.microsoft.com/.default",
        };

        using var response = await http.PostAsync(tokenEndpoint, new FormUrlEncodedContent(form), cancellationToken);
        response.EnsureSuccessStatusCode();

        var payload = await response.Content.ReadFromJsonAsync<TokenResponse>(cancellationToken: cancellationToken)
            ?? throw new InvalidOperationException("Failed to deserialize token response.");

        return payload.AccessToken;
    }

    private static string RequireEnvironmentVariable(string name)
        => Environment.GetEnvironmentVariable(name)
            ?? throw new InvalidOperationException($"Environment variable '{name}' is not set.");

    private class TokenResponse
    {
        [JsonPropertyName("access_token")]
        public required string AccessToken { get; set; }
    }
}
