targetScope = 'local'
extension fabric

@description('''
Top-level domains to create. Each entry: { name, description?, adminGroupIds?, contributorGroupIds? }.
''')
param domains array = []

@description('''
Nested domains to create under one of the top-level domains above. Each entry:
{ name, description?, parentDomainName, adminGroupIds?, contributorGroupIds? }.
parentDomainName must match the name of an entry in the domains array - Bicep won't let a resource
loop reference its own collection (even via a computed index, BCP079), so parent and child domains
are two separate loops rather than one self-referential array.
''')
param childDomains array = []

@description('''
Workspaces to create. Each entry: { name, adminObjectId, domainName? }.
domainName, if set, must match the name of an entry in either domains or childDomains.
''')
param workspaces array = []

@description('''
Tenant settings to manage declaratively. Each entry:
{ name, enabled, enabledSecurityGroups?, excludedSecurityGroups?, delegateToWorkspace? }.

name is the setting's technical name exactly as returned by GET /v1/admin/tenantsettings for this
tenant - look these up rather than guessing, the portal's display titles are not the API names.
scripts/get-tenant-settings.ps1 dumps the live list in this shape to seed this array.

The security-group arrays and delegateToWorkspace are only valid on settings that actually support
them (canSpecifySecurityGroups / delegatable in the GET response). Omit the key entirely rather than
passing an empty array or false where it doesn't apply - the extension leaves unset properties out of
the update payload, and the API rejects them on settings that don't accept them.
''')
param tenantSettings array = []

// Compile-time-only lookups (names, not runtime resource properties) - a var may not embed a
// resource's runtime output (e.g. domain[i].id) per BCP182, so the actual id resolution has to
// happen inline in each dependent resource's own for-body instead of through an intermediate var.
var domainNames = map(domains, d => d.name)
var childDomainNames = map(childDomains, cd => cd.name)

// .? (safe-dereference), not just ?? - domains is an untyped array param, and when a given
// object literally omits an optional key (rather than setting it to null), plain dot-access
// throws "the language expression property '...' doesn't exist" even with a ?? fallback. .?
// is what actually makes a missing key evaluate to null so ?? has something to catch.
resource domain 'Domain' = [for d in domains: {
  displayName: d.name
  description: d.?description
  adminGroupIds: d.?adminGroupIds ?? []
  contributorGroupIds: d.?contributorGroupIds ?? []
}]

resource childDomain 'Domain' = [for cd in childDomains: {
  displayName: cd.name
  description: cd.?description
  parentDomainId: domain[indexOf(domainNames, cd.parentDomainName)].id
  adminGroupIds: cd.?adminGroupIds ?? []
  contributorGroupIds: cd.?contributorGroupIds ?? []
}]

// A ternary here fails at deploy time with "domain[-1] is not valid" for a workspace whose
// domain is nested, even though ARM's docs say if() only evaluates the selected branch when
// the condition is decidable at deployment start (which this one is). Unconfirmed why; most
// likely something about how ARM validates resource-array-index references inside a copy loop
// happens structurally, separately from the short-circuited value evaluation the docs describe.
// Clamping both indices to a valid (if wrong) value with max(idx, 0) keeps both branches
// structurally in-bounds regardless; only the chosen branch's value is ever read.
resource ws 'Workspace' = [for w in workspaces: {
  displayName: w.name
  description: 'Created by the bicep-ext-fabric local extension lab.'
  adminObjectId: w.adminObjectId
  domainId: empty(w.?domainName ?? '') ? null : (contains(domainNames, w.domainName)
    ? domain[max(indexOf(domainNames, w.domainName), 0)].id
    : childDomain[max(indexOf(childDomainNames, w.domainName), 0)].id)
}]

// Declarative version of the same tenant-setting calls the lab's cleanup step already makes
// imperatively via raw REST - this closes that loop by driving them from the template instead.
// The admin-API access setting has to be bootstrapped manually once (this SP can't call the admin
// API to grant itself admin API access), then it's owned from here on along with everything else.
//
// .? throughout for the same reason as the domains loop above: tenantSettings is an untyped array
// param, so a genuinely absent key needs safe-dereference to evaluate to null. Here that null is
// load-bearing rather than cosmetic - the handler omits null properties from the update payload,
// which is what keeps a non-delegatable or non-group-scopable setting from being sent a property
// the API will reject.
resource tenantSetting 'TenantSetting' = [for ts in tenantSettings: {
  name: ts.name
  enabled: ts.enabled
  enabledSecurityGroups: ts.?enabledSecurityGroups
  excludedSecurityGroups: ts.?excludedSecurityGroups
  delegateToWorkspace: ts.?delegateToWorkspace
  delegateToCapacity: ts.?delegateToCapacity
  delegateToDomain: ts.?delegateToDomain
  properties: ts.?properties
}]

output domainIds array = [for i in range(0, length(domains)): domain[i].id]
output childDomainIds array = [for i in range(0, length(childDomains)): childDomain[i].id]
output workspaceIds array = [for i in range(0, length(workspaces)): ws[i].id]
