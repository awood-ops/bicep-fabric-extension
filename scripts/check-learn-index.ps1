<#
.SYNOPSIS
Checks Microsoft's public tenant settings index for settings not yet seen in this tenant. Needs no
authentication.

.DESCRIPTION
A companion to check-tenant-settings-drift.ps1, not a replacement for it.

Microsoft's docs list every tenant setting by display title but never publish the technical name
(settingName) the API and baseline.json are keyed on. Verified: zero technical names appear anywhere
in the fabric-docs repo. So the docs can tell you a new setting exists, but not what to write in the
posture map. Resolving that still needs an authenticated call.

What this buys, given it needs no credentials:

  - Runs before any Azure federation is configured, and keeps running if that credential lapses.
  - Catches settings documented before they light up in a given tenant, which happens routinely with
    preview features and staged rollouts.

Diffs against scripts/known-titles.json, which regenerate-baseline.ps1 snapshots from the tenant.
Titles are matched loosely on whitespace only, so expect the occasional false positive when Microsoft
rewords a title. Those are cheap to dismiss and preferable to missing a real addition.

Writes learn-summary.md and exits 1 when the docs list something the tenant snapshot doesn't have.

.PARAMETER TitlesPath
Path to the title snapshot. Defaults to known-titles.json next to this script.

.PARAMETER SummaryPath
Where to write the markdown summary. Defaults to learn-summary.md in the current directory.

.EXAMPLE
./check-learn-index.ps1
#>
[CmdletBinding()]
param(
    [string]$TitlesPath  = (Join-Path $PSScriptRoot 'known-titles.json'),
    [string]$SummaryPath = 'learn-summary.md'
)

$ErrorActionPreference = 'Stop'

$indexUrl = 'https://raw.githubusercontent.com/MicrosoftDocs/fabric-docs/main/docs/admin/tenant-settings-index.md'
$md = (Invoke-WebRequest -Uri $indexUrl -UseBasicParsing).Content -split "`n"

# Rows are "| Setting name | Description |". Take column one and strip any markdown link wrapper.
$learn = foreach ($line in $md) {
    if ($line -match '^\|\s*(.+?)\s*\|\s*(.+?)\s*\|\s*$') {
        $t = $Matches[1]
        if ($t -in 'Setting name', '---') { continue }
        $t = $t -replace '\[([^\]]+)\]\([^)]*\)', '$1'
        $t = ($t -replace '\s+', ' ').Trim()
        if ($t -and $t -notmatch '^-+$') { $t }
    }
}
$learn = @($learn | Sort-Object -Unique)

if ($learn.Count -lt 50) {
    # The docs page changing shape would silently produce an empty list, which would read as
    # Microsoft having deleted every setting. Treat an implausible parse as a failure.
    throw "Parsed only $($learn.Count) title(s) from the docs index. The page layout has probably changed and this parser needs updating."
}

$known = (Get-Content $TitlesPath -Raw | ConvertFrom-Json).titles
$new = @($learn | Where-Object { $known -notcontains $_ } | Sort-Object)

$sb = [System.Text.StringBuilder]::new()

if ($new.Count -eq 0) {
    [void]$sb.AppendLine("No new tenant settings in the public docs. $($learn.Count) documented, all present in the tenant snapshot.")
    Set-Content -Path $SummaryPath -Value $sb.ToString() -Encoding utf8
    Write-Host "No new documented settings. $($learn.Count) in docs." -ForegroundColor Green
    exit 0
}

[void]$sb.AppendLine("## Documented settings not in the tenant snapshot ($($new.Count))")
[void]$sb.AppendLine()
[void]$sb.AppendLine("Found in [Microsoft's tenant settings index]($indexUrl) but absent from ``scripts/known-titles.json``.")
[void]$sb.AppendLine()
[void]$sb.AppendLine('Each is one of:')
[void]$sb.AppendLine()
[void]$sb.AppendLine('- **A genuinely new setting** Microsoft has shipped. It needs a technical name, a posture in')
[void]$sb.AppendLine('  `baseline.json`, and an entry in the guidance. The technical name only comes from an')
[void]$sb.AppendLine('  authenticated call, so run `check-tenant-settings-drift.ps1` once it reaches the tenant.')
[void]$sb.AppendLine('- **Documented but not enabled for this tenant**, which is normal for preview features and')
[void]$sb.AppendLine('  staged rollouts. Nothing to do until it appears.')
[void]$sb.AppendLine('- **A reworded title.** The match is exact bar whitespace, so a rewrite shows up as new.')
[void]$sb.AppendLine()
foreach ($t in $new) { [void]$sb.AppendLine("- $t") }

Set-Content -Path $SummaryPath -Value $sb.ToString() -Encoding utf8
Write-Host "$($new.Count) documented setting(s) not in the tenant snapshot. Summary written to $SummaryPath" -ForegroundColor Yellow
exit 1
