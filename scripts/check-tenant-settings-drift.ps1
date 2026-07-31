<#
.SYNOPSIS
Checks the live tenant for tenant settings that have appeared, disappeared, or been renamed since the
baseline was last generated, and regenerates the baseline param file.

.DESCRIPTION
Microsoft adds tenant settings continuously. A setting that exists in the tenant but has no posture
in baseline.json is a switch nobody has made a decision about yet, which is the drift worth catching.

Deliberately does NOT invent a posture for new settings. Posture is a judgement call, so new settings
are reported for a human to classify and appear in the regenerated param file as commented-out
DECIDE entries, which are inert on deploy. The safe default is "no opinion", not a guess.

Writes drift-summary.md for use as a PR body or job summary, and exits 1 when something changed so a
CI step can branch on it. Exit 0 means the baseline still matches the tenant.

Auth reuses whatever `az login` session is present, so it works locally and under azure/login in CI.
The identity needs read-only Fabric admin API access: either a Fabric Administrator, or a service
principal in a group allow-listed against AllowServicePrincipalsUseReadAdminAPIs. A scoped-down
identity returns a shorter list rather than failing, which would look like settings disappearing.

.PARAMETER BaselinePath
Path to the posture map. Defaults to baseline.json next to this script.

.PARAMETER ParamPath
Path to the generated param file. Defaults to ../deploy/tenant-settings.baseline.bicepparam.

.PARAMETER SummaryPath
Path to write the markdown summary. Defaults to drift-summary.md in the current directory.

.EXAMPLE
./check-tenant-settings-drift.ps1
#>
[CmdletBinding()]
param(
    [string]$BaselinePath = (Join-Path $PSScriptRoot 'baseline.json'),
    [string]$ParamPath    = (Join-Path $PSScriptRoot '../deploy/tenant-settings.baseline.bicepparam'),
    [string]$SummaryPath  = 'drift-summary.md'
)

$ErrorActionPreference = 'Stop'

$token = az account get-access-token --resource 'https://api.fabric.microsoft.com' --query accessToken -o tsv
if ($LASTEXITCODE -ne 0 -or -not $token) {
    throw "Could not get a Fabric access token. Run 'az login' first."
}

$response = Invoke-RestMethod -Uri 'https://api.fabric.microsoft.com/v1/admin/tenantsettings' `
    -Headers @{ Authorization = "Bearer $token" }
$live = @($response.tenantSettings)

# A truncated list is the dangerous failure here: an under-permissioned identity returns fewer
# settings rather than erroring, which would read as Microsoft having removed dozens of them. Treat
# an implausibly short response as a failure rather than as drift.
if ($live.Count -lt 50) {
    throw "Only $($live.Count) setting(s) returned. That's almost certainly an under-permissioned identity rather than real drift. Check the caller has read-only admin API access."
}

$postures = Get-Content $BaselinePath -Raw | ConvertFrom-Json
$mapped = @($postures.PSObject.Properties.Name | Where-Object { $_ -ne '$comment' })

$added   = @($live | Where-Object { $mapped -notcontains $_.settingName } | Sort-Object settingName)
$removed = @($mapped | Where-Object { $live.settingName -notcontains $_ } | Sort-Object)

# Regenerate the param file regardless. Even with no membership change, values or titles may have
# moved, and the diff is the point.
$before = if (Test-Path $ParamPath) { Get-Content $ParamPath -Raw } else { '' }
& (Join-Path $PSScriptRoot 'regenerate-baseline.ps1') -BaselinePath $BaselinePath -ParamPath $ParamPath
$after = Get-Content $ParamPath -Raw
$paramChanged = $before -ne $after

$sb = [System.Text.StringBuilder]::new()

if ($added.Count -eq 0 -and $removed.Count -eq 0 -and -not $paramChanged) {
    [void]$sb.AppendLine("No tenant setting drift. $($live.Count) settings, all with a posture in ``baseline.json``.")
    Set-Content -Path $SummaryPath -Value $sb.ToString() -Encoding utf8
    Write-Host "No drift. $($live.Count) settings." -ForegroundColor Green
    exit 0
}

[void]$sb.AppendLine("Tenant now exposes **$($live.Count)** settings.")
[void]$sb.AppendLine()

if ($added.Count -gt 0) {
    [void]$sb.AppendLine("## New settings needing a posture ($($added.Count))")
    [void]$sb.AppendLine()
    [void]$sb.AppendLine("These exist in the tenant but have no entry in ``scripts/baseline.json``. They appear in the")
    [void]$sb.AppendLine("regenerated param file as commented-out ``DECIDE`` entries, so they do nothing on deploy until")
    [void]$sb.AppendLine("classified. Add each to ``baseline.json`` as ``off``, ``on``, ``on-scoped``, ``decide``, or ``excluded``,")
    [void]$sb.AppendLine("and document the reasoning in ``docs/tenant-settings-guidance.md``.")
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('| Setting | Title | Group | Currently | Group-scopable |')
    [void]$sb.AppendLine('| --- | --- | --- | --- | --- |')
    foreach ($s in $added) {
        $sg = if ($s.canSpecifySecurityGroups) { 'yes' } else { 'no' }
        $cur = if ($s.enabled) { '**on**' } else { 'off' }
        [void]$sb.AppendLine("| ``$($s.settingName)`` | $($s.title) | $($s.tenantSettingGroup) | $cur | $sg |")
    }
    [void]$sb.AppendLine()
}

if ($removed.Count -gt 0) {
    [void]$sb.AppendLine("## Settings no longer present ($($removed.Count))")
    [void]$sb.AppendLine()
    [void]$sb.AppendLine("In ``baseline.json`` but not returned by the tenant. Usually Microsoft retiring a setting, but")
    [void]$sb.AppendLine("check the caller's permissions before removing anything, since an under-permissioned identity")
    [void]$sb.AppendLine("returns a shorter list rather than an error.")
    [void]$sb.AppendLine()
    foreach ($r in $removed) { [void]$sb.AppendLine("- ``$r``") }
    [void]$sb.AppendLine()
}

if ($paramChanged -and $added.Count -eq 0 -and $removed.Count -eq 0) {
    [void]$sb.AppendLine('## Regenerated param file changed')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('No settings were added or removed, but the generated file differs. Most likely a title change')
    [void]$sb.AppendLine('or a shifted current value on a `DECIDE` entry. Review the diff.')
    [void]$sb.AppendLine()
}

[void]$sb.AppendLine('---')
[void]$sb.AppendLine()
[void]$sb.AppendLine('Counts in `README.md` and `docs/tenant-settings-guidance.md` reference the total number of')
[void]$sb.AppendLine('settings, so they need updating when this changes.')

Set-Content -Path $SummaryPath -Value $sb.ToString() -Encoding utf8

Write-Host "Drift detected. added=$($added.Count) removed=$($removed.Count) paramChanged=$paramChanged" -ForegroundColor Yellow
Write-Host "Summary written to $SummaryPath"
exit 1
