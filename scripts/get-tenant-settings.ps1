<#
.SYNOPSIS
Dumps this tenant's Fabric tenant settings, optionally as a ready-to-paste bicepparam array.

.DESCRIPTION
The portal shows tenant settings by display title; the API addresses them by technical name, and the
two don't match. Rather than transcribing names by hand, this pulls the live list from
GET /v1/admin/tenantsettings so deploy/main.bicepparam can be seeded from what the tenant actually
has.

Only settings the caller is allowed to read are returned, so run this as a Fabric Administrator (or
an SP allow-listed against the read-only admin APIs) - a scoped-down identity will silently return a
shorter list rather than erroring.

Auth reuses whatever `az login` session is present, matching the extension's own AzureCliCredential
fallback path.

.PARAMETER AsBicepParam
Emit a bicepparam-shaped `param tenantSettings = [...]` block instead of the raw objects.

.PARAMETER EnabledOnly
Only include settings that are currently enabled. Useful for capturing the tenant's actual posture
without also pinning every default-off setting to false.

.PARAMETER Filter
Wildcard match against the setting's technical name or title, e.g. '*ServicePrincipal*'.

.PARAMETER Sanitise
Replace security group object IDs and display names with placeholders. Use this when the output is
going somewhere public - group object IDs and naming conventions are tenant-identifying, and only a
handful of settings carry them, so the rest of the output is unaffected.

.EXAMPLE
./get-tenant-settings.ps1 -Filter '*ServicePrincipal*'

.EXAMPLE
# Local working copy, real group IDs, gitignored
./get-tenant-settings.ps1 -AsBicepParam > ../deploy/main.local.bicepparam

.EXAMPLE
# Committable reference template, placeholders instead of group IDs
./get-tenant-settings.ps1 -AsBicepParam -Sanitise > ../deploy/tenant-settings.all.bicepparam
#>
[CmdletBinding()]
param(
    [switch]$AsBicepParam,
    [switch]$EnabledOnly,
    [string]$Filter,
    [switch]$Sanitise
)

$ErrorActionPreference = 'Stop'

$token = az account get-access-token --resource 'https://api.fabric.microsoft.com' --query accessToken -o tsv
if ($LASTEXITCODE -ne 0 -or -not $token) {
    throw "Could not get a Fabric access token. Run 'az login' first."
}

$response = Invoke-RestMethod -Uri 'https://api.fabric.microsoft.com/v1/admin/tenantsettings' `
    -Headers @{ Authorization = "Bearer $token" }

$settings = @($response.tenantSettings)
Write-Verbose "Returned $($settings.Count) setting(s)."

if ($EnabledOnly) { $settings = @($settings | Where-Object { $_.enabled }) }
if ($Filter) {
    $settings = @($settings | Where-Object { $_.settingName -like $Filter -or $_.title -like $Filter })
}
$settings = @($settings | Sort-Object settingName)

if (-not $AsBicepParam) {
    $settings | Select-Object settingName, title, enabled, canSpecifySecurityGroups,
        delegateToWorkspace, delegateToCapacity, delegateToDomain, tenantSettingGroup
    return
}

# Only emit the optional properties where the setting actually supports them. Sending
# enabledSecurityGroups/excludedSecurityGroups at a setting whose canSpecifySecurityGroups is false,
# or delegateToWorkspace at one that isn't delegatable, is rejected by the update endpoint - so the
# generated array has to omit those keys rather than write them out as empty/false.
function Format-Groups {
    param($Groups, [string]$Key, [string]$Indent, [switch]$Redact)
    if (-not $Groups -or @($Groups).Count -eq 0) { return $null }
    $i = 0
    $lines = @($Groups | ForEach-Object {
        $i++
        # Numbered placeholders rather than one repeated token, so a setting scoped to several groups
        # still shows how many are expected and which is which.
        $suffix = if (@($Groups).Count -gt 1) { "-$i" } else { '' }
        $graphId = if ($Redact) { "<security-group-object-id$suffix>" } else { $_.graphId }
        $name = if ($Redact) { "<security-group-name$suffix>" } else { $_.name }
        "$Indent    {`n$Indent      graphId: '$graphId'`n$Indent      name: '$name'`n$Indent    }"
    })
    return "$Indent  ${Key}: [`n$($lines -join "`n")`n$Indent  ]"
}

$sb = [System.Text.StringBuilder]::new()
[void]$sb.AppendLine('param tenantSettings = [')

foreach ($s in $settings) {
    [void]$sb.AppendLine("  // $($s.title)")
    [void]$sb.AppendLine('  {')
    [void]$sb.AppendLine("    name: '$($s.settingName)'")
    [void]$sb.AppendLine("    enabled: $($s.enabled.ToString().ToLowerInvariant())")

    if ($s.canSpecifySecurityGroups) {
        $enabledGroups = Format-Groups -Groups $s.enabledSecurityGroups -Key 'enabledSecurityGroups' -Indent '  ' -Redact:$Sanitise
        if ($enabledGroups) { [void]$sb.AppendLine($enabledGroups) }

        $excludedGroups = Format-Groups -Groups $s.excludedSecurityGroups -Key 'excludedSecurityGroups' -Indent '  ' -Redact:$Sanitise
        if ($excludedGroups) { [void]$sb.AppendLine($excludedGroups) }
    }

    # The delegation flags are absent from the GET payload entirely for settings that don't support
    # that scope, so a null check is the signal - not $false, which is a real, valid value. The three
    # scopes are independent; a setting can support any combination of them.
    foreach ($scope in 'delegateToWorkspace', 'delegateToCapacity', 'delegateToDomain') {
        if ($null -ne $s.$scope) {
            [void]$sb.AppendLine("    ${scope}: $($s.$scope.ToString().ToLowerInvariant())")
        }
    }

    # A handful of settings carry typed values beyond the on/off flag.
    if ($s.properties -and @($s.properties).Count -gt 0) {
        [void]$sb.AppendLine('    properties: [')
        foreach ($p in $s.properties) {
            [void]$sb.AppendLine('      {')
            [void]$sb.AppendLine("        name: '$($p.name)'")
            [void]$sb.AppendLine("        value: '$($p.value)'")
            [void]$sb.AppendLine("        type: '$($p.type)'")
            [void]$sb.AppendLine('      }')
        }
        [void]$sb.AppendLine('    ]')
    }

    [void]$sb.AppendLine('  }')
}

[void]$sb.AppendLine(']')
$sb.ToString()
