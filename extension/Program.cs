using System.Reflection;
using Microsoft.AspNetCore.Builder;
using Bicep.Local.Extension.Host.Extensions;
using Microsoft.Extensions.DependencyInjection;

// Read the version off the assembly so <Version> in the csproj stays the only place it's declared.
// InformationalVersion is the one that round-trips a three-part SemVer intact - AssemblyVersion
// normalises to four parts (0.2.0.0). It also carries any "+<sha>" build suffix, hence the trim.
var version = (Assembly.GetExecutingAssembly()
    .GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion ?? "0.0.0")
    .Split('+')[0];

var builder = WebApplication.CreateBuilder();

builder.AddBicepExtensionHost(args);
builder.Services
    .AddHttpClient()
    .AddBicepExtension(
        name: "Fabric",
        version: version,
        isSingleton: true,
        typeAssembly: typeof(Program).Assembly)
    .WithResourceHandler<WorkspaceHandler>()
    .WithResourceHandler<DomainHandler>()
    .WithResourceHandler<TenantSettingHandler>();

var app = builder.Build();

app.MapBicepExtension();

await app.RunAsync();
