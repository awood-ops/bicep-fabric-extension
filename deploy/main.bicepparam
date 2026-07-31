using 'main.bicep'

// Technical names, not portal display titles - the two don't match. Seed this array from the live
// tenant with scripts/get-tenant-settings.ps1 rather than transcribing by hand; the names below are
// the ones this lab actually depends on and are here as a worked example of the shape.
//
// enabledSecurityGroups / delegateToWorkspace are only included on settings that support them.
// AllowServicePrincipalsUseWriteAdminAPIs is the bootstrap one - it has to be granted once by a
// human/delegated token before the SP can manage any of this, including itself.
param tenantSettings = [
  {
    name: 'AllowServicePrincipalsUseWriteAdminAPIs'
    enabled: true
    enabledSecurityGroups: [
      {
        graphId: '<spCreatorsGroupId output from identity/main.bicep>'
        name: 'sg-fabric-sp-workspace-creators'
      }
    ]
  }
  {
    name: 'AllowServicePrincipalsUseReadAdminAPIs'
    enabled: true
    enabledSecurityGroups: [
      {
        graphId: '<spCreatorsGroupId output from identity/main.bicep>'
        name: 'sg-fabric-sp-workspace-creators'
      }
    ]
  }
  {
    name: 'ServicePrincipalAccessGlobalAPIs'
    enabled: true
  }
  {
    name: 'CreateWorkspaces'
    enabled: true
  }
]

param domains = [
  {
    name: 'dev_domain_fabric'
    description: 'Development domain.'
    adminGroupIds: [
      '<adminGroupId output from identity/main.bicep>'
    ]
    contributorGroupIds: [
      '<contributorGroupId output from identity/main.bicep>'
    ]
  }
  {
    name: 'prd_domain_fabric'
    description: 'Production domain.'
    adminGroupIds: [
      '<adminGroupId output from identity/main.bicep>'
    ]
  }
]

param childDomains = [
  {
    name: 'dev_domain_fabric_analytics'
    description: 'Nested analytics sub-domain under dev_domain_fabric, to demonstrate parentDomainId.'
    parentDomainName: 'dev_domain_fabric'
  }
]

param workspaces = [
  {
    name: 'ws-dev-analytics'
    domainName: 'dev_domain_fabric_analytics'
    adminObjectId: '<your-entra-object-id>'
  }
  {
    name: 'ws-dev-bronze'
    domainName: 'dev_domain_fabric'
    adminObjectId: '<your-entra-object-id>'
  }
  {
    name: 'ws-prd-reporting'
    domainName: 'prd_domain_fabric'
    adminObjectId: '<your-entra-object-id>'
  }
]
