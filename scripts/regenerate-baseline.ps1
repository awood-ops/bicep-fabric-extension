<#
.SYNOPSIS
Regenerates deploy/tenant-settings.baseline.bicepparam from the live tenant and the posture map.

.DESCRIPTION
Wraps get-tenant-settings.ps1 with the flags and header the checked-in baseline needs, so
regenerating is one command rather than a remembered incantation. Always uses -Sanitise: the output
is committed to a public repo and must never carry real security group object IDs.

.PARAMETER BaselinePath
Path to the posture map. Defaults to baseline.json next to this script.

.PARAMETER ParamPath
Where to write the param file. Defaults to ../deploy/tenant-settings.baseline.bicepparam.

.EXAMPLE
./regenerate-baseline.ps1
#>
[CmdletBinding()]
param(
    [string]$BaselinePath = (Join-Path $PSScriptRoot 'baseline.json'),
    [string]$ParamPath    = (Join-Path $PSScriptRoot '../deploy/tenant-settings.baseline.bicepparam'),
    [string]$TitlesPath   = (Join-Path $PSScriptRoot 'known-titles.json')
)

$ErrorActionPreference = 'Stop'

$body = & (Join-Path $PSScriptRoot 'get-tenant-settings.ps1') `
    -AsBicepParam -Sanitise -Baseline $BaselinePath 3>$null

$header = @'
// Recommended starting baseline for Fabric tenant settings, aligned to
// docs/tenant-settings-guidance.md. Regenerate with scripts/regenerate-baseline.ps1.
//
// This asserts a posture rather than capturing one. Read before deploying:
//
//   - Entries marked DECIDE are commented out. They have no security-driven answer, so the baseline
//     takes no position and they do nothing on deploy. The current tenant value is shown as a
//     starting point. Uncomment the ones you want to own.
//   - Settings with enabledSecurityGroups carry <placeholder> values on purpose. Fill them in or
//     the deploy fails, which is preferable to silently enabling something tenant-wide.
//   - The five Advanced networking settings are deliberately absent. Private Link is the most
//     disruptive change in Fabric and needs its own sequenced rollout, not a line in a bulk apply.
//     See "What stops working under Private Link" in the guidance.
//   - Postures are a defensible default for a governed tenant holding non-public data, not a
//     verdict. Review against your own risk tolerance before applying.
using 'main.bicep'

'@

# Normalise to LF so a regeneration on Windows doesn't show up as a whole-file diff in CI.
$content = ($header + ($body -join "`n")) -replace "`r`n", "`n"
[System.IO.File]::WriteAllText((Resolve-Path -LiteralPath (Split-Path $ParamPath -Parent)).Path + [System.IO.Path]::DirectorySeparatorChar + (Split-Path $ParamPath -Leaf), $content, (New-Object System.Text.UTF8Encoding($false)))

Write-Host "Wrote $ParamPath" -ForegroundColor Green

# Also snapshot the display titles. Microsoft's public docs list settings by title only and never
# publish the technical name, so a title snapshot is the only thing the docs can be diffed against.
# That gives an auth-free early warning when a setting is documented before it reaches the tenant.
$token = az account get-access-token --resource 'https://api.fabric.microsoft.com' --query accessToken -o tsv
if ($LASTEXITCODE -ne 0 -or -not $token) { throw "Could not get a Fabric access token. Run 'az login' first." }
$live = @((Invoke-RestMethod -Uri 'https://api.fabric.microsoft.com/v1/admin/tenantsettings' `
    -Headers @{ Authorization = "Bearer $token" }).tenantSettings)

$titles = [ordered]@{
    '$comment' = @(
        'Display titles of the tenant settings this tenant exposes, snapshotted by regenerate-baseline.ps1.',
        'Exists only so check-learn-index.ps1 has something to diff the public docs against: Microsoft',
        'documents settings by title and never publishes the technical name, so titles are the only',
        'common key. Not used by the deployment itself.'
    )
    generated = (Get-Date -Format 'yyyy-MM-dd')
    count     = $live.Count
    titles    = @($live | ForEach-Object { ($_.title -replace '\s+', ' ').Trim() } | Sort-Object -Unique)
}
$json = ($titles | ConvertTo-Json -Depth 5) -replace "`r`n", "`n"
[System.IO.File]::WriteAllText((Resolve-Path -LiteralPath (Split-Path $TitlesPath -Parent)).Path + [System.IO.Path]::DirectorySeparatorChar + (Split-Path $TitlesPath -Leaf), $json + "`n", (New-Object System.Text.UTF8Encoding($false)))
Write-Host "Wrote $TitlesPath ($($live.Count) titles)" -ForegroundColor Green
