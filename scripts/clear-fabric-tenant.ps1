#requires -Version 7.0
<#
.SYNOPSIS
    Wipes a Microsoft Fabric DEV tenant back to empty: deletes every workspace and
    every domain via the Fabric REST API. Dry-run by default.

.DESCRIPTION
    Enumerates all workspaces (admin API) and all domains, then deletes them:
      1. workspaces first
      2. domains second, children before parents
    If the signed-in user is not an admin on a given workspace, the script adds
    them as Admin via the Power BI admin API and retries the delete.

    Capacities are NEVER touched - they are ARM / trial resources. Remove those
    from the Azure portal or with `az` separately.

    Auth reuses the current `az login` session. You must be a Fabric Administrator
    (and, for the self-grant fallback, hold Tenant.ReadWrite.All on the Power BI
    admin API). PowerShell 7+ and Azure CLI required.

.PARAMETER Execute
    Actually perform deletions. Without it the script only lists what it would do.

.PARAMETER Force
    Skip the interactive "type the tenant name to confirm" prompt. For automation.

.PARAMETER KeepWorkspace
    Workspace names or IDs to preserve (case-insensitive, exact match).

.PARAMETER KeepDomain
    Domain display names or IDs to preserve (case-insensitive, exact match).

.PARAMETER IncludeManagedApps
    Also delete Microsoft-managed template workspaces ("Microsoft Fabric Capacity
    Metrics", "Microsoft 365 Usage Analytics"). Kept by default - they auto-recreate
    and can error on delete.

.EXAMPLE
    ./scripts/clear-fabric-tenant.ps1
    Dry run. Lists every workspace and domain that would be deleted.

.EXAMPLE
    ./scripts/clear-fabric-tenant.ps1 -Execute -KeepWorkspace 'DemoWorkspace' -KeepDomain 'Finance'
    Deletes everything except the DemoWorkspace workspace, the Finance domain, and
    the managed apps.

.EXAMPLE
    ./scripts/clear-fabric-tenant.ps1 -Execute -Force -ReassignCapacityId <capacity-guid>
    Non-interactive wipe. Any workspace blocked by managed private endpoints on a
    capacity SKU that can't manage them is reassigned to the given capacity first,
    its endpoints cleared, then deleted.
#>
[CmdletBinding()]
param(
    [switch]$Execute,
    [switch]$Force,
    [string[]]$KeepWorkspace = @(),
    [string[]]$KeepDomain = @(),
    [switch]$IncludeManagedApps,
    # If a workspace can't be deleted because it holds managed private endpoints AND its
    # current capacity SKU can't manage them, reassign it to this capacity first (needs to
    # be an F64+/trial SKU that supports managed private endpoints), then clear + delete.
    [string]$ReassignCapacityId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$FabricRes  = 'https://api.fabric.microsoft.com'
$FabricBase = "$FabricRes/v1"
$PbiRes     = 'https://analysis.windows.net/powerbi/api'
$PbiBase    = 'https://api.powerbi.com/v1.0/myorg'
$ManagedAppNames = @('Microsoft Fabric Capacity Metrics', 'Microsoft 365 Usage Analytics')

# ---------------------------------------------------------------- auth ------
function Get-Token([string]$Resource) {
    $t = az account get-access-token --resource $Resource --query accessToken -o tsv 2>$null
    if (-not $t) { throw "Could not get an access token for $Resource. Run 'az login' first." }
    $t
}

$acctJson = az account show -o json 2>$null
if (-not $acctJson) { throw "Not logged in to Azure CLI. Run 'az login'." }
$acct = $acctJson | ConvertFrom-Json
$tenantName = if ($acct.PSObject.Properties.Name -contains 'tenantDisplayName' -and $acct.tenantDisplayName) {
    $acct.tenantDisplayName
} else { $acct.tenantId }

try   { $signedIn = az ad signed-in-user show -o json 2>$null | ConvertFrom-Json }
catch { $signedIn = $null }
$myUpn = if ($signedIn -and $signedIn.userPrincipalName) { $signedIn.userPrincipalName } else { $acct.user.name }

Write-Host ""
Write-Host "Tenant : $($acct.tenantId)  ($tenantName)" -ForegroundColor Yellow
Write-Host "Account: $myUpn" -ForegroundColor Yellow
Write-Host ""

$fabricHeaders = @{ Authorization = "Bearer $(Get-Token $FabricRes)" }
$script:pbiHeaders = $null   # acquired lazily only if a self-grant is needed

# ------------------------------------------------------------- helpers ------
function Invoke-Fabric {
    param(
        [Parameter(Mandatory)][string]$Method,
        [Parameter(Mandatory)][string]$Uri,
        $Body,
        [hashtable]$Headers
    )
    if (-not $Headers) { $Headers = $fabricHeaders }
    $attempt = 0
    while ($true) {
        $attempt++
        try {
            $p = @{ Method = $Method; Uri = $Uri; Headers = $Headers; ErrorAction = 'Stop' }
            if ($null -ne $Body) {
                $p.Body = ($Body | ConvertTo-Json -Depth 8)
                $p.ContentType = 'application/json'
            }
            return Invoke-RestMethod @p
        }
        catch {
            $code = 0
            if ($_.Exception.PSObject.Properties.Name -contains 'Response' -and $_.Exception.Response) {
                $code = [int]$_.Exception.Response.StatusCode
            }
            if ($code -eq 429 -and $attempt -le 6) {
                $wait = 10 * $attempt
                Write-Warning "429 throttled - waiting ${wait}s (attempt $attempt)"
                Start-Sleep -Seconds $wait
                continue
            }
            throw
        }
    }
}

function Get-FabricPaged([string]$Uri, [string]$Prop) {
    $all  = @()
    $next = $Uri
    while ($next) {
        $r = Invoke-Fabric -Method GET -Uri $next
        if ($r.PSObject.Properties.Name -contains $Prop) { $all += $r.$Prop }
        $next = $null
        if ($r.PSObject.Properties.Name -contains 'continuationUri' -and $r.continuationUri) {
            $next = $r.continuationUri
        }
    }
    $all
}

function Get-HttpStatus($err) {
    if ($err.Exception.PSObject.Properties.Name -contains 'Response' -and $err.Exception.Response) {
        return [int]$err.Exception.Response.StatusCode
    }
    0
}

function Get-ApiError($err) {
    # Surface the REST response body (Fabric puts errorCode/message there) when present.
    $detail = $null
    if ($err.PSObject.Properties.Name -contains 'ErrorDetails' -and $err.ErrorDetails -and $err.ErrorDetails.Message) {
        $detail = $err.ErrorDetails.Message
    }
    $status = Get-HttpStatus $err
    if ($detail) { "HTTP $status - $detail" } else { "HTTP $status - $($err.Exception.Message)" }
}

function Test-HasProp($obj, [string]$name) {
    $null -ne $obj -and ($obj.PSObject.Properties.Name -contains $name)
}

function Get-ErrBody($err) {
    if ((Test-HasProp $err 'ErrorDetails') -and $err.ErrorDetails -and $err.ErrorDetails.Message) {
        return [string]$err.ErrorDetails.Message
    }
    ''
}

function Clear-WorkspaceManagedEndpoints([string]$workspaceId) {
    try {
        $eps = @(Get-FabricPaged "$FabricBase/workspaces/$workspaceId/managedPrivateEndpoints" 'value')
    }
    catch {
        Write-Warning "      cannot list managed private endpoints: $(Get-ApiError $_)"
        return -1
    }
    $removed = 0
    foreach ($ep in $eps) {
        Write-Host ("      removing managed private endpoint '{0}' ({1})" -f $ep.name, $ep.id)
        try {
            Invoke-Fabric -Method DELETE -Uri "$FabricBase/workspaces/$workspaceId/managedPrivateEndpoints/$($ep.id)" | Out-Null
            $removed++
        }
        catch { Write-Warning "      endpoint '$($ep.name)' delete failed: $(Get-ApiError $_)" }
    }
    $removed
}

# Deletes one workspace, remediating the two blockers we see in practice:
#   401/403  -> self-grant Admin via the Power BI admin API, retry
#   WorkspaceContainsManagedEndpoints -> delete the managed private endpoints, retry
function Remove-FabricWorkspace($w) {
    $reassigned = $false
    for ($try = 1; $try -le 6; $try++) {
        try {
            Invoke-Fabric -Method DELETE -Uri "$FabricBase/workspaces/$($w.id)" | Out-Null
            return 'deleted'
        }
        catch {
            $httpStatus = Get-HttpStatus $_
            $body       = Get-ErrBody $_

            if ($httpStatus -in 401, 403) {
                if (-not $myUpn) { return "FAILED: $(Get-ApiError $_)" }
                Write-Warning "Not an admin on '$($w.name)' - self-granting Admin and retrying"
                if (-not $script:pbiHeaders) { $script:pbiHeaders = @{ Authorization = "Bearer $(Get-Token $PbiRes)" } }
                try {
                    Invoke-Fabric -Method POST -Uri "$PbiBase/admin/groups/$($w.id)/users" -Headers $script:pbiHeaders -Body @{
                        identifier = $myUpn; groupUserAccessRight = 'Admin'; principalType = 'User'
                    } | Out-Null
                }
                catch { return "FAILED: $(Get-ApiError $_)" }
                Start-Sleep -Seconds 3
                continue
            }

            if ($body -match 'WorkspaceContainsManagedEndpoints') {
                if ($ReassignCapacityId -and -not $reassigned) {
                    Write-Warning "'$($w.name)' blocked by managed endpoints - reassigning to capacity $ReassignCapacityId first"
                    try {
                        Invoke-Fabric -Method POST -Uri "$FabricBase/workspaces/$($w.id)/assignToCapacity" -Body @{ capacityId = $ReassignCapacityId } | Out-Null
                        $reassigned = $true
                        Start-Sleep -Seconds 10
                        continue
                    }
                    catch { Write-Warning "      capacity reassign failed: $(Get-ApiError $_)" }
                }
                Write-Warning "'$($w.name)' has managed private endpoints - removing them and retrying"
                $n = Clear-WorkspaceManagedEndpoints $w.id
                if ($n -lt 0) {
                    return "FAILED: holds managed private endpoints but the current capacity SKU can't list/delete them - re-run with -ReassignCapacityId <F64+/trial capacity guid>, or clear the endpoints in the Fabric portal"
                }
                Write-Host ("      {0} managed private endpoint(s) deleted; waiting for teardown" -f $n)
                Start-Sleep -Seconds (10 * $try)
                continue
            }

            return "FAILED: $(Get-ApiError $_)"
        }
    }
    return "FAILED: still blocked after 6 attempts (managed endpoints may still be tearing down - re-run)"
}

# ----------------------------------------------------------- enumerate ------
Write-Host "Enumerating workspaces..." -ForegroundColor Cyan
$workspaces = @(Get-FabricPaged "$FabricBase/admin/workspaces?type=Workspace" 'workspaces') |
    Where-Object { $_.state -ne 'Deleted' }

Write-Host "Enumerating domains..." -ForegroundColor Cyan
$domains = @(Get-FabricPaged "$FabricBase/admin/domains" 'domains')

# --------------------------------------------------------------- scope ------
$keepWs = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($k in $KeepWorkspace) { [void]$keepWs.Add($k) }
if (-not $IncludeManagedApps) { foreach ($m in $ManagedAppNames) { [void]$keepWs.Add($m) } }

$keepDom = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($k in $KeepDomain) { [void]$keepDom.Add($k) }

$wsToDelete  = @($workspaces | Where-Object { -not ($keepWs.Contains($_.name) -or $keepWs.Contains($_.id)) })
$domToDelete = @($domains    | Where-Object { -not ($keepDom.Contains($_.displayName) -or $keepDom.Contains($_.id)) })

Write-Host ""
Write-Host "Workspaces to delete: $($wsToDelete.Count) of $($workspaces.Count)" -ForegroundColor Magenta
$wsToDelete | Sort-Object name | Format-Table name, id, state, capacityId -AutoSize
Write-Host "Domains to delete: $($domToDelete.Count) of $($domains.Count)" -ForegroundColor Magenta
$domToDelete | Sort-Object displayName | Format-Table displayName, id, parentDomainId -AutoSize

$kept = @()
$kept += $workspaces | Where-Object { $keepWs.Contains($_.name) -or $keepWs.Contains($_.id) } | ForEach-Object { "workspace: $($_.name)" }
$kept += $domains    | Where-Object { $keepDom.Contains($_.displayName) -or $keepDom.Contains($_.id) } | ForEach-Object { "domain:    $($_.displayName)" }
if ($kept) {
    Write-Host "Preserved by -Keep* / managed-app rules:" -ForegroundColor Green
    $kept | ForEach-Object { Write-Host "  $_" -ForegroundColor Green }
}
Write-Host "Capacities are not touched by this script." -ForegroundColor DarkGray
Write-Host ""

if (-not $Execute) {
    Write-Host "DRY RUN - nothing deleted. Re-run with -Execute to proceed." -ForegroundColor Green
    return
}

if (-not $Force) {
    $typed = Read-Host "Type the tenant name '$tenantName' to PERMANENTLY delete everything listed above"
    if ($typed -ne $tenantName) {
        Write-Host "Input did not match - aborted. Nothing deleted." -ForegroundColor Red
        return
    }
}

# --------------------------------------------------------------- delete -----
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$log   = Join-Path (Get-Location) "fabric-wipe-$stamp.log"
$csv   = Join-Path (Get-Location) "fabric-wipe-$stamp.csv"
Start-Transcript -Path $log | Out-Null
$results = [System.Collections.Generic.List[object]]::new()

try {
    Write-Host "`n--- Deleting workspaces ---" -ForegroundColor Cyan
    foreach ($w in $wsToDelete) {
        $status = Remove-FabricWorkspace $w
        Write-Host ("  {0,-50} {1}" -f $w.name, $status)
        $results.Add([pscustomobject]@{ Kind = 'Workspace'; Name = $w.name; Id = $w.id; Result = $status })
    }

    Write-Host "`n--- Deleting domains (children first) ---" -ForegroundColor Cyan
    $pending = [System.Collections.Generic.List[object]]::new()
    $domToDelete | ForEach-Object { $pending.Add($_) }
    $pass = 0
    while ($pending.Count -gt 0 -and $pass -lt 12) {
        $pass++
        $leaves = @($pending | Where-Object {
            $thisId = $_.id
            $hasChild = $pending | Where-Object {
                (Test-HasProp $_ 'parentDomainId') -and $_.parentDomainId -eq $thisId
            }
            -not $hasChild
        })
        if ($leaves.Count -eq 0) { $leaves = @($pending) }   # defensive: break any cycle
        foreach ($d in $leaves) {
            $status = 'deleted'
            try {
                Invoke-Fabric -Method DELETE -Uri "$FabricBase/admin/domains/$($d.id)" | Out-Null
            }
            catch { $status = "FAILED: $(Get-ApiError $_)" }
            Write-Host ("  {0,-50} {1}" -f $d.displayName, $status)
            $results.Add([pscustomobject]@{ Kind = 'Domain'; Name = $d.displayName; Id = $d.id; Result = $status })
            [void]$pending.Remove($d)
        }
    }

    $failed = @($results | Where-Object { $_.Result -like 'FAILED*' })
    Write-Host ""
    Write-Host "Done. $($results.Count - $failed.Count) deleted, $($failed.Count) failed." -ForegroundColor $(if ($failed) { 'Yellow' } else { 'Green' })
    if ($failed) { $failed | Format-Table Kind, Name, Result -AutoSize -Wrap }
}
finally {
    $results | Export-Csv -Path $csv -NoTypeInformation
    Stop-Transcript | Out-Null
    Write-Host "Log: $log"
    Write-Host "CSV: $csv"
}
