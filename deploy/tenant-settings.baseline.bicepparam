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
param tenantSettings = [
  // Microsoft Entra single sign-on for data gateway
  // DECIDE - no default recommended. Currently: true
  // {
  //   name: 'AADSSOForGateway'
  //   enabled: true
  // }
  // Microsoft Entra single sign-on for virtual network (VNet) data gateway
  // DECIDE - no default recommended. Currently: false
  // {
  //   name: 'AADSSOForVnetGateway'
  //   enabled: false
  // }
  // Enhance admin APIs responses with detailed metadata
  {
    name: 'AdminApisIncludeDetailedMetadata'
    enabled: false
  }
  // Enhance admin APIs responses with DAX and mashup expressions
  {
    name: 'AdminApisIncludeExpressions'
    enabled: false
  }
  // Show a custom message before publishing reports
  // DECIDE - no default recommended. Currently: false
  // {
  //   name: 'AdminCustomDisclaimer'
  //   enabled: false
  //   properties: [
  //     {
  //       name: 'AdminCustomDisclaimer'
  //       value: ''
  //       type: 'Freetext'
  //     }
  //   ]
  // }
  // Users with view permission can launch Explore
  // DECIDE - no default recommended. Currently: true
  // {
  //   name: 'AdminDataExploreViewPermission'
  //   enabled: true
  // }
  // Enable sending Operations Agents observability data to Agent 365 (preview)
  {
    name: 'AllowA365Observability'
    enabled: false
    delegateToCapacity: true
  }
  // Show user data in the Fabric Capacity Metrics app and reports
  // DECIDE - no default recommended. Currently: true
  // {
  //   name: 'AllowCapacityMetricsReportUserMask'
  //   enabled: true
  // }
  // AppSource Custom Visuals SSO
  {
    name: 'AllowCVAuthenticationTenant'
    enabled: false
  }
  // Allow access to the browser's local storage
  // DECIDE - no default recommended. Currently: true
  // {
  //   name: 'AllowCVLocalStorageV2Tenant'
  //   enabled: true
  // }
  // Allow downloads from custom visuals
  {
    name: 'AllowCVToExportDataToFileTenant'
    enabled: false
  }
  // Endorse master data
  {
    name: 'AllowEndorsementMasterDataSwitch'
    enabled: true
    enabledSecurityGroups: [
      {
        graphId: '<security-group-object-id>'
        name: '<security-group-name>'
      }
    ]
  }
  // Users can accept external data shares
  {
    name: 'AllowExternalDataSharingReceiverSwitch'
    enabled: false
  }
  // External data sharing
  {
    name: 'AllowExternalDataSharingSwitch'
    enabled: false
  }
  // Users can try Microsoft Fabric paid features
  // DECIDE - no default recommended. Currently: true
  // {
  //   name: 'AllowFreeTrial'
  //   enabled: true
  // }
  // Use short-lived user-delegated SAS tokens
  {
    name: 'AllowGetOneLakeUDK'
    enabled: false
  }
  // Users can see guest users in lists of suggested people
  {
    name: 'AllowGuestLookup'
    enabled: false
  }
  // Guest users can access Microsoft Fabric
  {
    name: 'AllowGuestUserToAccessSharedContent'
    enabled: false
  }
  // Allow non-Entra ID auth in Eventstream
  {
    name: 'AllowNonEntraADAuthInEventStream'
    enabled: false
  }
  // Users with read or write permission can download data from notebooks
  {
    name: 'AllowNotebookDataExport'
    enabled: false
  }
  // Authenticate with OneLake user-delegated SAS tokens
  {
    name: 'AllowOneLakeUDK'
    enabled: false
    delegateToWorkspace: true
  }
  // Insights for operations agents (preview)
  // DECIDE - no default recommended. Currently: true
  // {
  //   name: 'AllowOperatorInsightsTenantSwitch'
  //   enabled: true
  //   delegateToCapacity: true
  // }
  // Allow DirectQuery connections to Power BI semantic models
  // DECIDE - no default recommended. Currently: false
  // {
  //   name: 'AllowPowerBIASDQOnTenant'
  //   enabled: false
  // }
  // Data sent to Azure OpenAI can be processed outside your capacity's geographic region, compliance boundary, or national cloud instance
  {
    name: 'AllowSendAOAIDataToOtherRegions'
    enabled: false
    delegateToCapacity: false
  }
  // Allow service principals to create and use profiles
  {
    name: 'AllowServicePrincipalsCreateAndUseProfiles'
    enabled: false
  }
  // Service principals can access read-only admin APIs
  {
    name: 'AllowServicePrincipalsUseReadAdminAPIs'
    enabled: true
    enabledSecurityGroups: [
      {
        graphId: '<security-group-object-id>'
        name: '<security-group-name>'
      }
    ]
  }
  // Service principals can access admin APIs used for updates
  {
    name: 'AllowServicePrincipalsUseWriteAdminAPIs'
    enabled: true
    enabledSecurityGroups: [
      {
        graphId: '<security-group-object-id>'
        name: '<security-group-name>'
      }
    ]
  }
  // Data sent to Azure OpenAI can be stored outside your capacity's geographic region, compliance boundary, or national cloud instance
  {
    name: 'AllowStoreAOAIDataInOtherRegions'
    enabled: false
  }
  // Allow data processing outside geographic region for Azure AI services
  {
    name: 'AllowUserDataProcessedByAiServicesOutOfGeo'
    enabled: false
    delegateToCapacity: false
  }
  // Enable Fabric App Items (preview)
  {
    name: 'AppBackendTenant'
    enabled: false
    delegateToCapacity: true
  }
  // Push apps to end users
  // DECIDE - no default recommended. Currently: true
  // {
  //   name: 'AppPush'
  //   enabled: true
  // }
  // Users can create Azure Databricks Storage items (preview)
  {
    name: 'ArtifactDatabricksStoragePreview'
    enabled: false
    delegateToCapacity: true
  }
  // Users can create dbt job items (preview)
  {
    name: 'ArtifactDBTItemTenantSwitch'
    enabled: false
    delegateToCapacity: false
  }
  // Enable new mirrored catalog items (preview)
  {
    name: 'ArtifactMirroredCatalogPreview'
    enabled: false
    delegateToCapacity: true
  }
  // Use global search for Power BI
  // DECIDE - no default recommended. Currently: false
  // {
  //   name: 'ArtifactSearchTenant'
  //   enabled: false
  // }
  // Microsoft can store query text to aid in support investigations
  // DECIDE - no default recommended. Currently: false
  // {
  //   name: 'ASCollectQueryTextTelemetryTenantSwitch'
  //   enabled: false
  // }
  // Enable granular access control for all data connections
  {
    name: 'ASShareableCloudConnectionBindingSecurityModeTenant'
    enabled: true
  }
  // Semantic models can export data to OneLake
  // DECIDE - no default recommended. Currently: true
  // {
  //   name: 'ASWritethruContinuousExportTenantSwitch'
  //   enabled: true
  // }
  // Install Power BI app for Microsoft Teams automatically
  // DECIDE - no default recommended. Currently: true
  // {
  //   name: 'AutoInstallPowerBIAppInTeamsTenant'
  //   enabled: true
  // }
  // Show entry points for insights (preview)
  // DECIDE - no default recommended. Currently: false
  // {
  //   name: 'AutomatedInsightsEntryPoints'
  //   enabled: false
  // }
  // Receive notifications for top insights (preview)
  // DECIDE - no default recommended. Currently: false
  // {
  //   name: 'AutomatedInsightsTenant'
  //   enabled: false
  // }
  // Automatically convert and store reports using Power BI enhanced metadata format (PBIR) (preview)
  // DECIDE - no default recommended. Currently: false
  // {
  //   name: 'AutomaticallyUsePBIR'
  //   enabled: false
  // }
  // Users can use the Azure Maps visual
  // DECIDE - no default recommended. Currently: true
  // {
  //   name: 'AzureMaps'
  //   enabled: true
  // }
  // Data sent to Azure Maps can be processed outside your tenant's geographic region, compliance boundary, or national cloud instance
  {
    name: 'AzureMapsCrossRegionDataProcessing'
    enabled: false
  }
  // Users can use Azure Maps services
  // DECIDE - no default recommended. Currently: true
  // {
  //   name: 'AzureMapsInFabric'
  //   enabled: true
  // }
  // Data sent to Azure Maps can be processed outside your capacity's geographic region, compliance boundary or national cloud instance
  {
    name: 'AzureMapsInFabricCrossRegionDataProcessing'
    enabled: false
  }
  // Data sent to Azure Maps can be processed by Microsoft Online Services Subprocessors 
  {
    name: 'AzureMapsThirdPartyDataProcessing'
    enabled: false
  }
  // Users can use Azure Maps Weather Services (Preview)
  // DECIDE - no default recommended. Currently: true
  // {
  //   name: 'AzureMapsWeatherServices'
  //   enabled: true
  // }
  // Map and filled map visuals
  // DECIDE - no default recommended. Currently: false
  // {
  //   name: 'BingMap'
  //   enabled: false
  // }
  // Block republish and disable package refresh
  // DECIDE - no default recommended. Currently: false
  // {
  //   name: 'BlockAutoDiscoverAndPackageRefresh'
  //   enabled: false
  // }
  // Restrict content with protected labels from being shared via link with everyone in your organization
  {
    name: 'BlockProtectedLabelSharingToEntireOrg'
    enabled: true
  }
  // Block ResourceKey Authentication
  {
    name: 'BlockResourceKeyAuthentication'
    enabled: true
  }
  // Create and use Gen1 dataflows
  // DECIDE - no default recommended. Currently: true
  // {
  //   name: 'CDSAManagement'
  //   enabled: true
  // }
  // Add and use certified visuals only (block uncertified)
  {
    name: 'CertifiedCustomVisualsTenant'
    enabled: true
  }
  // Certification
  {
    name: 'CertifyDatasets'
    enabled: true
    enabledSecurityGroups: [
      {
        graphId: '<security-group-object-id>'
        name: '<security-group-name>'
      }
    ]
    delegateToDomain: false
    properties: [
      {
        name: 'CertificationDocumentationUrl'
        value: ''
        type: 'Url'
      }
    ]
  }
  // Fabric item recovery
  // DECIDE - no default recommended. Currently: false
  // {
  //   name: 'ConfigureArtifactRetentionPeriod'
  //   enabled: false
  //   properties: [
  //     {
  //       name: 'ArtifactRetentionPeriod'
  //       value: ''
  //       type: 'Integer'
  //     }
  //   ]
  // }
  // Define maximum number of Fabric identities in a tenant
  // DECIDE - no default recommended. Currently: false
  // {
  //   name: 'ConfigureFabricIdentityTenantLimit'
  //   enabled: false
  //   properties: [
  //     {
  //       name: 'FabricIdentityTenantLimit'
  //       value: ''
  //       type: 'Integer'
  //     }
  //   ]
  // }
  // Define workspace retention period
  {
    name: 'ConfigureFolderRetentionPeriod'
    enabled: true
    properties: [
      {
        name: 'FolderRetentionPeriod'
        value: '30'
        type: 'Integer'
      }
    ]
  }
  // Capacities can be designated as Fabric Copilot capacities
  // DECIDE - no default recommended. Currently: true
  // {
  //   name: 'CopilotCapacitySetupPermissionSwitch'
  //   enabled: true
  // }
  // Create workspaces
  {
    name: 'CreateAppWorkspaces'
    enabled: true
    enabledSecurityGroups: [
      {
        graphId: '<security-group-object-id>'
        name: '<security-group-name>'
      }
    ]
  }
  // Allow visuals created using the Power BI SDK
  {
    name: 'CustomVisualsTenant'
    enabled: true
    enabledSecurityGroups: [
      {
        graphId: '<security-group-object-id>'
        name: '<security-group-name>'
      }
    ]
  }
  // Create Datamarts (preview)
  // DECIDE - no default recommended. Currently: false
  // {
  //   name: 'DatamartTenant'
  //   enabled: false
  // }
  // Allow Microsoft Purview to secure AI interactions
  // DECIDE - no default recommended. Currently: false
  // {
  //   name: 'DataSecurityForAIInteractions'
  //   enabled: false
  // }
  // Semantic Model Execute Queries REST API
  {
    name: 'DatasetExecuteQueries'
    enabled: false
  }
  // Enable Denodo SSO
  {
    name: 'DenodoForPowerBISSO'
    enabled: false
  }
  // Publish template apps
  {
    name: 'DevelopServiceApps'
    enabled: false
  }
  // Users can create Digital Twin Builder (preview) items
  {
    name: 'DigitalOperationsPreview'
    enabled: false
    delegateToCapacity: true
  }
  // Discover content
  {
    name: 'DiscoverDatasetsConsumption'
    enabled: true
  }
  // Make certified content discoverable 
  {
    name: 'DiscoverDatasetsSettingsCertified'
    enabled: true
  }
  // Make promoted content discoverable
  {
    name: 'DiscoverDatasetsSettingsPromoted'
    enabled: true
  }
  // Dremio SSO
  {
    name: 'DremioSSO'
    enabled: false
  }
  // Apply sensitivity labels from data sources to their data in Power BI
  {
    name: 'EimInformationProtectionDataSourceInheritanceSetting'
    enabled: true
  }
  // Domain admins can set default sensitivity labels for their domains (preview)
  // DECIDE - no default recommended. Currently: false
  // {
  //   name: 'EimInformationProtectionDefaultLabelDomainSetting'
  //   enabled: false
  // }
  // Automatically apply sensitivity labels to downstream content
  {
    name: 'EimInformationProtectionDownstreamInheritanceSetting'
    enabled: true
  }
  // Allow users to apply sensitivity labels for content
  {
    name: 'EimInformationProtectionEdit'
    enabled: true
  }
  // Allow workspace admins to override automatically applied sensitivity labels
  {
    name: 'EimInformationProtectionWorkspaceAdminsOverrideAutomaticLabelsSetting'
    enabled: false
  }
  // Guest users can browse and access Fabric content
  {
    name: 'ElevatedGuestsTenant'
    enabled: false
  }
  // Receive email and Teams notifications for service outages or incidents
  // DECIDE - no default recommended. Currently: false
  // {
  //   name: 'EmailSecurityGroupsOnOutage'
  //   enabled: false
  //   properties: [
  //     {
  //       name: 'EmailList'
  //       value: ''
  //       type: 'MailEnabledSecurityGroup'
  //     }
  //   ]
  // }
  // B2B guest users can set up and be subscribed to email subscriptions
  {
    name: 'EmailSubscriptionsToB2BUsers'
    enabled: false
  }
  // Users can send email subscriptions to external users
  {
    name: 'EmailSubscriptionsToExternalUsers'
    enabled: false
  }
  // Users can set up email subscriptions
  // DECIDE - no default recommended. Currently: false
  // {
  //   name: 'EmailSubscriptionTenant'
  //   enabled: false
  // }
  // Embed content in apps
  {
    name: 'Embedding'
    enabled: false
  }
  // Enable anonymous data access for Fabric Apps (Preview)
  {
    name: 'EnableAnonymousDataAccessForFabricApps'
    enabled: false
  }
  // Users can use Copilot, AI Agents and other AI experiences powered by Azure OpenAI
  {
    name: 'EnableAOAI'
    enabled: true
    enabledSecurityGroups: [
      {
        graphId: '<security-group-object-id>'
        name: '<security-group-name>'
      }
    ]
    delegateToCapacity: true
  }
  // Allow specific users to turn on external data sharing
  {
    name: 'EnableDatasetInPlaceSharing'
    enabled: false
  }
  // ArcGIS GeoAnalytics for Fabric Runtime
  // DECIDE - no default recommended. Currently: true
  // {
  //   name: 'EnableEsriLibraries'
  //   enabled: true
  //   delegateToCapacity: true
  // }
  // Allow tenant and domain admins to override workspace assignments (preview)
  {
    name: 'EnableReassignDataDomainSwitch'
    enabled: true
  }
  // Use ArcGIS Maps for Power BI
  // DECIDE - no default recommended. Currently: true
  // {
  //   name: 'EsriVisual'
  //   enabled: true
  // }
  // Enable Event Schema Sets in Real-Time Hub (preview)
  {
    name: 'EventDefinitionTenantSwitch'
    enabled: false
    delegateToCapacity: false
  }
  // Help Power BI optimize your experience
  // DECIDE - no default recommended. Currently: false
  // {
  //   name: 'ExpFlightingTenant'
  //   enabled: false
  // }
  // Download reports
  {
    name: 'ExportReport'
    enabled: false
  }
  // Export to .csv
  {
    name: 'ExportToCsv'
    enabled: true
    enabledSecurityGroups: [
      {
        graphId: '<security-group-object-id>'
        name: '<security-group-name>'
      }
    ]
  }
  // Export to Excel
  {
    name: 'ExportToExcelSetting'
    enabled: true
    enabledSecurityGroups: [
      {
        graphId: '<security-group-object-id>'
        name: '<security-group-name>'
      }
    ]
  }
  // Export reports as image files
  // DECIDE - no default recommended. Currently: false
  // {
  //   name: 'ExportToImage'
  //   enabled: false
  //   delegateToWorkspace: false
  //   delegateToDomain: false
  // }
  // Export reports as MHTML documents
  // DECIDE - no default recommended. Currently: false
  // {
  //   name: 'ExportToMHTML'
  //   enabled: false
  //   delegateToWorkspace: false
  //   delegateToDomain: false
  // }
  // Export reports as PowerPoint presentations or PDF documents
  // DECIDE - no default recommended. Currently: false
  // {
  //   name: 'ExportToPowerPoint'
  //   enabled: false
  //   delegateToWorkspace: false
  //   delegateToDomain: false
  // }
  // Export reports as Word documents
  // DECIDE - no default recommended. Currently: false
  // {
  //   name: 'ExportToWord'
  //   enabled: false
  //   delegateToWorkspace: false
  //   delegateToDomain: false
  // }
  // Export reports as XML documents
  // DECIDE - no default recommended. Currently: false
  // {
  //   name: 'ExportToXML'
  //   enabled: false
  //   delegateToWorkspace: false
  //   delegateToDomain: false
  // }
  // Copy and paste visuals
  // DECIDE - no default recommended. Currently: true
  // {
  //   name: 'ExportVisualImageTenant'
  //   enabled: true
  //   enabledSecurityGroups: [
  //     {
  //       graphId: '<security-group-object-id>'
  //       name: '<security-group-name>'
  //     }
  //   ]
  // }
  // Guest users can work with shared semantic models in their own tenants
  {
    name: 'ExternalDatasetSharingTenant'
    enabled: false
  }
  // Users can invite guest users to collaborate through item sharing and permissions
  {
    name: 'ExternalSharingV2'
    enabled: false
  }
  // Capacity admins and contributors can add and remove additional workloads
  {
    name: 'FabricAddPartnerWorkload'
    enabled: false
    properties: [
      {
        name: 'OnlyCapacityAdmins'
        value: 'false'
        type: 'Boolean'
      }
    ]
  }
  // Workspace admins can add and remove additional workloads (preview)
  {
    name: 'FabricAddWorkloadToWorkspace'
    enabled: false
  }
  // Product Feedback
  // DECIDE - no default recommended. Currently: true
  // {
  //   name: 'FabricFeedbackTenantSwitch'
  //   enabled: true
  // }
  // Users can create Fabric items
  {
    name: 'FabricGAWorkloads'
    enabled: true
    enabledSecurityGroups: [
      {
        graphId: '<security-group-object-id>'
        name: '<security-group-name>'
      }
    ]
    delegateToCapacity: true
  }
  // Users can be informed of upcoming conferences featuring Microsoft Fabric when they are logged in to Fabric
  // DECIDE - no default recommended. Currently: true
  // {
  //   name: 'FabricPromotionTenantSwitch'
  //   enabled: true
  // }
  // Workspace admins can develop partner workloads 
  {
    name: 'FabricThirdPartyWorkloads'
    enabled: false
  }
  // Users can sync workspace items with GitHub repositories 
  // DECIDE - no default recommended. Currently: false
  // {
  //   name: 'GitHubTenantSettings'
  //   enabled: false
  //   delegateToWorkspace: false
  //   delegateToCapacity: false
  // }
  // Users can export items to Git repositories in other geographical locations
  {
    name: 'GitIntegrationCrossGeoTenantSwitch'
    enabled: false
    delegateToWorkspace: false
    delegateToCapacity: false
  }
  // Users can export workspace items with applied sensitivity labels to Git repositories
  {
    name: 'GitIntegrationSensitivityLabelsTenantSwitch'
    enabled: false
    delegateToWorkspace: false
    delegateToCapacity: false
  }
  // Users can synchronize workspace items with their Git repositories
  {
    name: 'GitIntegrationTenantSwitch'
    enabled: true
    enabledSecurityGroups: [
      {
        graphId: '<security-group-object-id>'
        name: '<security-group-name>'
      }
    ]
    delegateToWorkspace: false
    delegateToCapacity: false
  }
  // Google BigQuery SSO
  {
    name: 'GoogleBigQuerySSO'
    enabled: false
  }
  // Users can access a standalone, cross-item Power BI Copilot experience (preview)
  {
    name: 'ImmersiveTenantAdminSwitch'
    enabled: false
  }
  // Receive In-product notifications for service outages or incidents
  {
    name: 'InProductOutageNotification'
    enabled: true
    delegateToWorkspace: false
    delegateToCapacity: false
  }
  // Install template apps not listed in AppSource
  {
    name: 'InstallNonvalidatedTemplateApps'
    enabled: false
  }
  // Install template apps
  // DECIDE - no default recommended. Currently: true
  // {
  //   name: 'InstallServiceApps'
  //   enabled: true
  // }
  // Users can work with semantic models in Excel using a live connection
  {
    name: 'LiveConnection'
    enabled: true
    enabledSecurityGroups: [
      {
        graphId: '<security-group-object-id>'
        name: '<security-group-name>'
      }
    ]
  }
  // Azure Log Analytics connections for workspace administrators
  {
    name: 'LogAnalyticsAttachForWorkspaceAdmins'
    enabled: true
    enabledSecurityGroups: [
      {
        graphId: '<security-group-object-id>'
        name: '<security-group-name>'
      }
    ]
  }
  // Users can share Power BI visuals as Loop components (preview)
  // DECIDE - no default recommended. Currently: true
  // {
  //   name: 'LoopIntegration'
  //   enabled: true
  // }
  // Share Fabric data with your Microsoft 365 services
  // DECIDE - no default recommended. Currently: false
  // {
  //   name: 'M365DataSharing'
  //   enabled: false
  //   properties: [
  //     {
  //       name: 'M365DataSharingAcrossGeos'
  //       value: 'false'
  //       type: 'Boolean'
  //     }
  //   ]
  // }
  // Fabric data agents can send operational metadata for observability in Microsoft Foundry
  {
    name: 'MicrosoftFoundryTelemetry'
    enabled: false
  }
  // ML models can serve real-time predictions from API endpoints (preview)
  {
    name: 'MLModelEndpointsTenantSwitch'
    enabled: false
  }
  // Semantic model owners can choose to automatically update semantic models from files imported from OneDrive or SharePoint
  {
    name: 'ODSPRefreshEnforcementTenantAllowAutomaticUpdate'
    enabled: false
  }
  // Users can share links to Power BI files stored in OneDrive and SharePoint through Power BI Desktop (preview)
  // DECIDE - no default recommended. Currently: true
  // {
  //   name: 'OneDriveSharePointAllowSharingTenantSetting'
  //   enabled: true
  // }
  // Users can view Power BI files saved in OneDrive and SharePoint (preview)
  // DECIDE - no default recommended. Currently: true
  // {
  //   name: 'OneDriveSharePointViewerIntegrationTenantSettingV2'
  //   enabled: true
  // }
  // Users can find objects in search
  // DECIDE - no default recommended. Currently: true
  // {
  //   name: 'OneLakeCatalogSubItemDiscovery'
  //   enabled: true
  // }
  // Include end-user identifiers in OneLake diagnostic logs
  {
    name: 'OneLakeDiagnosticLogsEUII'
    enabled: true
  }
  // Users can sync data in OneLake with the OneLake File Explorer app
  {
    name: 'OneLakeFileExplorer'
    enabled: false
  }
  // Users can access data stored in OneLake with apps external to Fabric
  {
    name: 'OneLakeForThirdParty'
    enabled: false
  }
  // Allow XMLA endpoints and Analyze in Excel with on-premises semantic models
  {
    name: 'OnPremAnalyzeInExcel'
    enabled: false
  }
  // Users can create Ontology (preview) items
  {
    name: 'OntologyPreview'
    enabled: false
    delegateToCapacity: true
  }
  // Workspace admins can turn on monitoring for their workspaces (preview)
  {
    name: 'PlatformMonitoringTenantSetting'
    enabled: true
    delegateToCapacity: true
  }
  // Create and use Scorecards
  // DECIDE - no default recommended. Currently: true
  // {
  //   name: 'PowerBIGoalsTenant'
  //   enabled: true
  // }
  // Users can use the Power BI Model Context Protocol server endpoint (preview)
  {
    name: 'PowerBIMCP'
    enabled: false
  }
  // Only show approved items in the standalone Copilot in Power BI experience (preview)
  {
    name: 'PreppedForCopilotContentDiscovery'
    enabled: true
    delegateToWorkspace: true
    delegateToDomain: true
  }
  // Print dashboards and reports
  // DECIDE - no default recommended. Currently: false
  // {
  //   name: 'Printing'
  //   enabled: false
  // }
  // Featured content
  // DECIDE - no default recommended. Currently: true
  // {
  //   name: 'PromoteContent'
  //   enabled: true
  // }
  // Publish apps to the entire organization
  {
    name: 'PublishContentPack'
    enabled: true
    enabledSecurityGroups: [
      {
        graphId: '<security-group-object-id>'
        name: '<security-group-name>'
      }
    ]
  }
  // Publish to web
  {
    name: 'PublishToWeb'
    enabled: false
    properties: [
      {
        name: 'CreateP2w'
        value: 'false'
        type: 'Boolean'
      }
    ]
  }
  // Review questions
  // DECIDE - no default recommended. Currently: true
  // {
  //   name: 'QnaFeedbackLoop'
  //   enabled: true
  // }
  // Synonym sharing
  // DECIDE - no default recommended. Currently: true
  // {
  //   name: 'QnaLsdlSharing'
  //   enabled: true
  // }
  // Scale out queries for large semantic models
  {
    name: 'QueryScaleOutTenant'
    enabled: true
  }
  // Allow Real-Time Dashboards to include embedded app visuals
  {
    name: 'RealTimeDashboardEmbeddedApp'
    enabled: false
  }
  // Redshift SSO
  {
    name: 'RedshiftSSO'
    enabled: false
  }
  // Block users from reassigning personal workspaces (My Workspace)
  {
    name: 'RestrictMyFolderCapacity'
    enabled: true
  }
  // Interact with and share R and Python visuals
  {
    name: 'RScriptVisual'
    enabled: false
  }
  // Detect anomalies in Real-Time Intelligence (Preview)
  {
    name: 'RTHAnomalyDetectionTenantSwitch'
    enabled: false
    delegateToCapacity: false
  }
  // Service principals can create workspaces, connections, and deployment pipelines
  {
    name: 'ServicePrincipalAccessGlobalAPIs'
    enabled: true
    enabledSecurityGroups: [
      {
        graphId: '<security-group-object-id>'
        name: '<security-group-name>'
      }
    ]
  }
  // Service principals can call Fabric public APIs
  {
    name: 'ServicePrincipalAccessPermissionAPIs'
    enabled: true
    enabledSecurityGroups: [
      {
        graphId: '<security-group-object-id>'
        name: '<security-group-name>'
      }
    ]
  }
  // Allow shareable links to grant access to everyone in your organization
  {
    name: 'ShareLinkToEntireOrg'
    enabled: false
  }
  // Enable Microsoft Teams integration
  // DECIDE - no default recommended. Currently: true
  // {
  //   name: 'ShareToTeamsTenant'
  //   enabled: true
  // }
  // All Power BI users can see "Set alert" button to create Fabric Activator alerts
  // DECIDE - no default recommended. Currently: false
  // {
  //   name: 'ShowActivatorEntryPointsTenantSwitch'
  //   enabled: false
  // }
  // Snowflake SSO
  {
    name: 'SnowflakeSSO'
    enabled: false
  }
  // Enable Starburst SSO
  {
    name: 'StarburstAadSSO'
    enabled: false
  }
  // Enable Power BI add-in for PowerPoint
  // DECIDE - no default recommended. Currently: true
  // {
  //   name: 'StorytellingTenant'
  //   enabled: true
  // }
  // Create template organizational apps
  {
    name: 'TemplatePublish'
    enabled: false
  }
  // Publish "Get Help" information
  // DECIDE - no default recommended. Currently: false
  // {
  //   name: 'TenantSettingPublishGetHelpInfo'
  //   enabled: false
  //   properties: [
  //     {
  //       name: 'TrainingDocumentation'
  //       value: ''
  //       type: 'Url'
  //     }
  //     {
  //       name: 'DiscussionForum'
  //       value: ''
  //       type: 'Url'
  //     }
  //     {
  //       name: 'LicensingRequests'
  //       value: ''
  //       type: 'Url'
  //     }
  //     {
  //       name: 'HelpDesk'
  //       value: ''
  //       type: 'Url'
  //     }
  //   ]
  // }
  // Users can see and work with additional workloads not validated by Microsoft
  {
    name: 'ThirdPartyPrivateWorkloads'
    enabled: false
  }
  // Usage metrics for content creators
  {
    name: 'UsageMetrics'
    enabled: true
  }
  // Per-user data in usage metrics for content creators
  // DECIDE - no default recommended. Currently: true
  // {
  //   name: 'UsageMetricsTrackUserLevelInfo'
  //   enabled: true
  // }
  // Users can connect to data sources by using Apache Arrow database connectivity (ADBC)
  // DECIDE - no default recommended. Currently: false
  // {
  //   name: 'UseAdbcByDefault'
  //   enabled: false
  //   delegateToWorkspace: true
  // }
  // Use semantic models across workspaces
  {
    name: 'UseDatasetsAcrossWorkspaces'
    enabled: true
  }
  // Integration with SharePoint and Microsoft Lists
  // DECIDE - no default recommended. Currently: false
  // {
  //   name: 'VisualizeListInPowerBI'
  //   enabled: false
  // }
  // Web content on dashboard tiles
  {
    name: 'WebContentTilesTenant'
    enabled: false
  }
  // Users can edit semantic models in the Power BI service
  // DECIDE - no default recommended. Currently: true
  // {
  //   name: 'WebModelingTenantSwitch'
  //   enabled: true
  // }
  // Apply customer-managed keys
  {
    name: 'WorkspaceCmk'
    enabled: false
  }
]
