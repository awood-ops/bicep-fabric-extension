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

.PARAMETER Baseline
Path to a posture map (baseline.json). Emits recommended values from the map instead of the tenant's
current ones, turning the output from a snapshot into a starting baseline. Settings marked 'decide'
are emitted commented out, 'excluded' ones are omitted, and anything in the tenant with no posture
raises a warning rather than being guessed at.

.EXAMPLE
./get-tenant-settings.ps1 -Filter '*ServicePrincipal*'

.EXAMPLE
# Local working copy, real group IDs, gitignored
./get-tenant-settings.ps1 -AsBicepParam > ../deploy/main.local.bicepparam

.EXAMPLE
# Committable reference template, placeholders instead of group IDs
./get-tenant-settings.ps1 -AsBicepParam -Sanitise -Baseline ./baseline.json > ../deploy/tenant-settings.baseline.bicepparam
#>
[CmdletBinding()]
param(
    [switch]$AsBicepParam,
    [switch]$EnabledOnly,
    [string]$Filter,
    [switch]$Sanitise,
    [string]$Baseline
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

# --- Baseline mode -----------------------------------------------------------------------------
# Without -Baseline the emitted values are whatever the tenant currently has, so re-applying is a
# no-op. With it, values come from the posture map instead, turning the output from a snapshot into
# a recommendation. Postures are documented in baseline.json itself.
$postures = $null
if ($Baseline) {
    if (-not (Test-Path $Baseline)) { throw "Baseline map not found: $Baseline" }
    $postures = Get-Content $Baseline -Raw | ConvertFrom-Json

    $mapped = $postures.PSObject.Properties.Name | Where-Object { $_ -ne '$comment' }
    $unmapped = @($settings | Where-Object { $mapped -notcontains $_.settingName })
    if ($unmapped.Count -gt 0) {
        # A new setting appearing in the tenant with no posture is the drift case worth shouting
        # about - it's a switch nobody has made a decision on yet.
        Write-Warning "$($unmapped.Count) setting(s) have no posture in the baseline and will be emitted as 'decide':"
        $unmapped | ForEach-Object { Write-Warning "  $($_.settingName)  ($($_.title))" }
    }
}

function Get-Posture {
    param($Setting)
    if (-not $postures) { return 'live' }
    $p = $postures.($Setting.settingName)
    if (-not $p) { return 'decide' }

    # A setting carrying a typed property needs a value to be meaningful. Where the tenant hasn't
    # set one, asserting 'on' would push an empty value, so it drops to 'decide' instead.
    if ($p -eq 'on' -and $Setting.properties) {
        $blank = @($Setting.properties | Where-Object { [string]::IsNullOrWhiteSpace($_.value) })
        if ($blank.Count -gt 0) { return 'decide' }
    }
    return $p
}

$sb = [System.Text.StringBuilder]::new()
[void]$sb.AppendLine('param tenantSettings = [')

foreach ($s in $settings) {
    $posture = Get-Posture -Setting $s
    if ($posture -eq 'excluded') { continue }

    # 'decide' entries are emitted commented out: visible as an outstanding decision, but inert on
    # deploy. The current tenant value is shown so there's a starting point for the conversation.
    $c = if ($posture -eq 'decide') { '// ' } else { '' }

    [void]$sb.AppendLine("  // $($s.title)")
    if ($posture -eq 'decide') {
        [void]$sb.AppendLine("  // DECIDE - no default recommended. Currently: $($s.enabled.ToString().ToLowerInvariant())")
    }
    [void]$sb.AppendLine("  $c{")
    [void]$sb.AppendLine("  $c  name: '$($s.settingName)'")
    $enabledValue = switch ($posture) {
        'on'        { 'true' }
        'on-scoped' { 'true' }
        'off'       { 'false' }
        default     { $s.enabled.ToString().ToLowerInvariant() }
    }
    [void]$sb.AppendLine("  $c  enabled: $enabledValue")

    if ($s.canSpecifySecurityGroups) {
        # on-scoped is the whole point of the posture: assert the setting on, but force a group to be
        # named rather than letting it apply tenant-wide. A placeholder here is deliberate - it won't
        # deploy until someone fills it in, which beats silently enabling something for everyone.
        if ($posture -eq 'on-scoped') {
            [void]$sb.AppendLine("  $c  enabledSecurityGroups: [")
            [void]$sb.AppendLine("  $c    {")
            [void]$sb.AppendLine("  $c      graphId: '<security-group-object-id>'")
            [void]$sb.AppendLine("  $c      name: '<security-group-name>'")
            [void]$sb.AppendLine("  $c    }")
            [void]$sb.AppendLine("  $c  ]")
        }
        elseif ($posture -notin 'on', 'off') {
            $enabledGroups = Format-Groups -Groups $s.enabledSecurityGroups -Key 'enabledSecurityGroups' -Indent "  $c" -Redact:$Sanitise
            if ($enabledGroups) { [void]$sb.AppendLine($enabledGroups) }

            $excludedGroups = Format-Groups -Groups $s.excludedSecurityGroups -Key 'excludedSecurityGroups' -Indent "  $c" -Redact:$Sanitise
            if ($excludedGroups) { [void]$sb.AppendLine($excludedGroups) }
        }
    }

    # The delegation flags are absent from the GET payload entirely for settings that don't support
    # that scope, so a null check is the signal - not $false, which is a real, valid value. The three
    # scopes are independent; a setting can support any combination of them.
    foreach ($scope in 'delegateToWorkspace', 'delegateToCapacity', 'delegateToDomain') {
        if ($null -ne $s.$scope) {
            [void]$sb.AppendLine("  $c  ${scope}: $($s.$scope.ToString().ToLowerInvariant())")
        }
    }

    # A handful of settings carry typed values beyond the on/off flag.
    if ($s.properties -and @($s.properties).Count -gt 0) {
        [void]$sb.AppendLine("  $c  properties: [")
        foreach ($p in $s.properties) {
            [void]$sb.AppendLine("  $c    {")
            [void]$sb.AppendLine("  $c      name: '$($p.name)'")
            [void]$sb.AppendLine("  $c      value: '$($p.value)'")
            [void]$sb.AppendLine("  $c      type: '$($p.type)'")
            [void]$sb.AppendLine("  $c    }")
        }
        [void]$sb.AppendLine("  $c  ]")
    }

    [void]$sb.AppendLine("  $c}")
}

[void]$sb.AppendLine(']')
$sb.ToString()
