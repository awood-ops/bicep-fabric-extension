using Microsoft.AspNetCore.Builder;
using Bicep.Local.Extension.Host.Extensions;
using Microsoft.Extensions.DependencyInjection;

var builder = WebApplication.CreateBuilder();

builder.AddBicepExtensionHost(args);
builder.Services
    .AddHttpClient()
    .AddBicepExtension(
        name: "Fabric",
        version: "0.1.0",
        isSingleton: true,
        typeAssembly: typeof(Program).Assembly)
    .WithResourceHandler<WorkspaceHandler>()
    .WithResourceHandler<DomainHandler>()
    .WithResourceHandler<TenantSettingHandler>();

var app = builder.Build();

app.MapBicepExtension();

await app.RunAsync();
