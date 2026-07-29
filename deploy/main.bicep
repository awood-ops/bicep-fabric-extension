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
Object ID of the extension's own automation group. Workspace creation itself
(ServicePrincipalAccessGlobalAPIs) is already enabled tenant-wide with no group restriction, so
this isn't needed for that - it's used below to keep the tenant's admin-API access setting pointed
at a real group instead of a dead one.
''')
param spCreatorsGroupId string

@description('Display name of that same group, echoed back into the tenant setting payload.')
param spCreatorsGroupName string = 'sg-fabric-sp-workspace-creators'

@description('''
Technical name of the tenant setting this template manages declaratively, as returned by
GET /v1/admin/tenantsettings for this tenant. No default - look this up rather than guessing.
''')
param tenantSettingName string

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

// ARM's if() is not short-circuiting - both branches of a Bicep ternary are evaluated
// regardless of the condition, so an out-of-range index in the *unchosen* branch (indexOf
// returning -1 when a name isn't in that array) still fails template validation as
// "domain[-1] is not valid", even though that branch's value is never actually used. Clamping
// both indices to a valid (if wrong) value with max(idx, 0) keeps both branches structurally
// valid; only the chosen branch's value is ever read.
resource ws 'Workspace' = [for w in workspaces: {
  displayName: w.name
  description: 'Created by the bicep-ext-fabric local extension lab.'
  adminObjectId: w.adminObjectId
  domainId: empty(w.?domainName ?? '') ? null : (contains(domainNames, w.domainName)
    ? domain[max(indexOf(domainNames, w.domainName), 0)].id
    : childDomain[max(indexOf(childDomainNames, w.domainName), 0)].id)
}]

// Declarative version of the same tenant-setting call the lab's cleanup step already makes
// imperatively via a raw REST call - this closes that loop by driving it from the template instead.
// Bootstrapped manually once (this SP can't call the admin API to grant itself admin API access),
// then owned by this resource from here on.
resource adminApiAccessSetting 'TenantSetting' = {
  name: tenantSettingName
  enabled: true
  enabledSecurityGroups: [
    {
      graphId: spCreatorsGroupId
      name: spCreatorsGroupName
    }
  ]
}

output domainIds array = [for i in range(0, length(domains)): domain[i].id]
output childDomainIds array = [for i in range(0, length(childDomains)): childDomain[i].id]
output workspaceIds array = [for i in range(0, length(workspaces)): ws[i].id]
