using 'main.bicep'

param spCreatorsGroupId = '<spCreatorsGroupId output from identity/main.bicep>'
param tenantSettingName = '<technical name from GET /v1/admin/tenantsettings for this tenant, e.g. AllowServicePrincipalsUseWriteAdminAPIs>'

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
