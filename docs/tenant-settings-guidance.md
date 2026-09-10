# Fabric tenant settings: rationale and preferred posture

A working reference for the 171 tenant settings exposed by `GET /v1/admin/tenantsettings`, with what
each one does, a preferred default, and the reasoning behind it.

## How to read this

**The preferred column is a starting baseline, not a verdict.** Microsoft's own guidance is explicit
that a security baseline is "a starting point for conversations about your environment, governance
policies, and risk tolerance" rather than a checklist. A setting marked `Off` here is one where the
default posture should be off and enabling it should be a deliberate, documented decision, not one
that's always wrong to enable.

The baseline assumes a **governed enterprise tenant handling non-public data**. A tenant that is
deliberately public-facing, or a sandbox with no real data, will justifiably diverge.

| Preferred | Meaning |
| --- | --- |
| `Off` | Disable by default. Enabling materially widens data egress or trust boundaries. |
| `Off unless needed` | Legitimate uses exist. Enable deliberately, scope to a security group, review periodically. |
| `On` | Enable. Improves posture, or is needed for normal operation with no meaningful downside. |
| `On (scoped)` | Enable, but restrict to a named security group rather than the whole tenant. |
| `Org choice` | No security-driven answer. Decide on function, cost, or preference. |

Where a setting supports security-group scoping, `On (scoped)` is almost always better than a blanket
`On`. It's the difference between a capability being available and being available *to everyone*.

Two structural points worth internalising before changing anything:

1. **Default settings favour usability over strict security.** That's Microsoft's own framing. An
   unreviewed tenant is not a secure tenant, it's a convenient one.
2. **Track settings via the admin API and compare against a baseline to detect drift.** This is an
   explicit Well-Architected recommendation, and it's the reason this repo exists: the settings are
   declared in Bicep so drift is a diff rather than a discovery.

## The risk concentration

Not all 171 matter equally. Roughly:

- **Export and sharing (33 settings)** is where data leaves the tenant. Highest concentration of
  genuine exfiltration risk, and the group most worth going through line by line.
- **Advanced networking (5)** and **Admin API / Developer (10)** are small but high-leverage, since they
  govern how the tenant is reached and who can automate against it.
- **Information protection (7)** is the classification layer everything else keys off. If these are
  all off, label-based controls elsewhere have nothing to enforce.
- **Integration (26)** is mostly per-connector SSO toggles, low individual risk, but each one sends
  user identity to a third party, so they should be on only where that connector is actually used.
- The long tail (**preview items, visuals, Q&A, insights, scorecards**) is mostly feature enablement
  where the honest answer is "org choice".

---

## Export and sharing settings

Where data leaves. Worth the most scrutiny of any group.

| Setting | What it does | Preferred | Why |
| --- | --- | --- | --- |
| `PublishToWeb` | Publishes reports to the public internet, no authentication | **Off** | Anonymous public exposure of report data. The single highest-risk setting in Fabric. If ever enabled, audit existing embed codes, because old codes stay live. |
| `AllowExternalDataSharingSwitch` | Share read-only OneLake links outside the org | **Off unless needed** | Recipients can view, build on, and reshare beyond their own tenant. Enable only with a named business case, scoped to a group. |
| `AllowExternalDataSharingReceiverSwitch` | Accept external data shares from other tenants | **Off unless needed** | Inbound counterpart. Brings third-party data (and its licensing/provenance questions) into your tenant. |
| `EnableDatasetInPlaceSharing` | Let users turn on external semantic model sharing | **Off unless needed** | Delegates the external-sharing decision to end users. |
| `ExternalDatasetSharingTenant` | Guests use shared semantic models in *their* tenants | **Off** | Data leaves your tenant's control plane entirely; your labels don't travel with it. |
| `ShareLinkToEntireOrg` | "Anyone in your organization with the link" sharing | **Off** | Explicitly called out in WAF hardening guidance. Defeats least-privilege at the item level. |
| `AllowGuestUserToAccessSharedContent` | Entra guest users can access Fabric | **Off unless needed** | Gate on whether B2B collaboration is genuinely required. |
| `ExternalSharingV2` | Users can invite guests via item sharing | **Off unless needed** | Lets end users expand the Entra directory. Prefer admin-controlled guest onboarding. |
| `ElevatedGuestsTenant` | Guests can browse and request access to content | **Off** | Broadens guest visibility from "what they were given" to "what exists". |
| `AllowGuestLookup` | Guests appear in people-pickers | **Off** | Reduces accidental external sharing. Users can still share by full email if intended. |
| `EmailSubscriptionsToB2BUsers` | Guests can use email subscriptions | **Off** | Recurring automated delivery to external identities. |
| `EmailSubscriptionsToExternalUsers` | Subscriptions to non-directory external addresses | **Off** | Delivery to addresses with no identity governance at all. |
| `EmailSubscriptionTenant` | Users can set up email subscriptions | **Org choice** | Internal-only subscriptions are low risk and useful. |
| `ExportToExcelSetting` | Export visual/report data to Excel | **On (scoped)** | Blanket export blocks tend to get worked around. Prefer sensitivity labels + DLP over a flat ban. |
| `ExportToCsv` | Export to .csv | **On (scoped)** | Note: labels are **not** enforced on .csv/.txt export paths, making this a genuine label-bypass route. |
| `ExportReport` | Download .pbix and paginated reports | **Off unless needed** | Downloads the model *and its data*, not just a rendering. Higher impact than a visual export. |
| `ExportToPowerPoint` / `ExportToWord` / `ExportToImage` / `ExportToMHTML` / `ExportToXML` | Paginated/report export to various formats | **Org choice** | Label encryption applies on supported export paths. Delegatable to workspace/domain. |
| `Printing` | Print dashboards and reports | **Org choice** | Low marginal risk; screenshotting is always available. |
| `ExportVisualImageTenant` | Copy/paste visuals as static images | **Org choice** | Static images only, no underlying data. |
| `AllowNotebookDataExport` | Download data from notebook outputs | **Off unless needed** | Notebook outputs frequently contain raw, unlabelled query results. |
| `LiveConnection` | Analyze in Excel / XMLA live connection | **On (scoped)** | Legitimate and widely used, but it's a full model connection. Scope it. |
| `AllowPowerBIASDQOnTenant` | DirectQuery connections to semantic models | **Org choice** | Enables model reuse; a modelling decision more than a security one. |
| `CertifyDatasets` | Who can certify content | **On (scoped)** | Certification is a trust signal, so restrict it to data stewards or it becomes noise. |
| `AllowEndorsementMasterDataSwitch` | Who can endorse as master data | **On (scoped)** | Same reasoning as certification. |
| `PromoteContent` | Featured content on Power BI Home | **Org choice** | Discovery convenience. |
| `ShareToTeamsTenant` | Teams integration | **Org choice** | Coordinate with the Teams admin. |
| `AutoInstallPowerBIAppInTeamsTenant` | Auto-install Power BI Teams app | **Org choice** | Adoption nudge, no data-boundary effect. |
| `StorytellingTenant` | Power BI add-in for PowerPoint | **Org choice** | Live-connected, permission-respecting. |
| `LoopIntegration` | Share Power BI visuals as Loop components (preview) | **Org choice** | Live-connected and permission-respecting, like the PowerPoint add-in, but the component travels wherever the Loop does (Teams chat, Outlook, Loop app). Scope by function, not security. Preview. |

---

## Advanced networking

Small group, disproportionate leverage. These are how the tenant is reached.

| Setting | What it does | Preferred | Why |
| --- | --- | --- | --- |
| `AllowAccessOverPrivateLinks` | Tenant-level Private Link | **On** *(only after reading the breakage list below)* | WAF: "Use private link instead of public endpoints when possible." But this is **not a transparent network change**. It disables real functionality. See below. |
| `BlockAccessFromPublicNetworks` | Block public internet access | **Off until Private Link is proven** | The end state for a locked-down tenant, but enabling it before Private Link works locks everyone out, including you. Takes ~15 minutes to apply. Sequencing matters. |
| `ConfigureWorkspaceLevelIPFirewallRules` | Workspace admins can set IP firewall rules | **On** | Lets workspace owners tighten beyond the tenant default. Additive control. |
| `WorkspaceBlockInboundAccess` | Workspace-level inbound rules | **On** | Enables per-workspace inbound restriction. Note it supersedes tenant-level private links for configured workspaces. |
| `WorkspaceBlockOutboundAccess` | Workspace outbound access protection | **On** | WAF calls this out directly: block outbound by default, then allow approved destinations. The main control against a notebook exfiltrating to an arbitrary endpoint. |

### What stops working under Private Link

Private Link is the most disruptive setting in this document. It is often presented as a
network-layer control, but in practice **it disables features across the whole platform**, and
several of those conflict directly with recommendations elsewhere in this doc. Microsoft's own
overview opens by telling you to read the entire article before enabling it. That advice is earned.

Two different blast radii apply, and it's important not to conflate them:

- **`AllowAccessOverPrivateLinks` (Private Link on)** already breaks things, on its own.
- **`BlockAccessFromPublicNetworks` (public access blocked)** breaks considerably more, because
  anything that doesn't support private links is then blocked outright rather than quietly falling
  back to the public path.

#### Broken by enabling Private Link alone

| What breaks | Impact |
| --- | --- |
| **On-premises data gateways** | **Not supported. They fail to register.** Private Link must be disabled to run the gateway configurator. Usually the single biggest blocker in an enterprise tenant. VNet data gateways *do* work and are the migration path. |
| **Copilot and AI features** | Not supported under Private Link or closed networks at all. |
| **Purview Information Protection** | Not supported. In Desktop the **Sensitivity button greys out, label info doesn't appear, and .pbix decryption fails.** Mitigable with service tags for EOP/AIP, but it isn't automatic. |
| **Publish to web** | Not supported. No practical loss, since it should be off anyway. |
| **Export to PDF / PowerPoint** | Not supported. |
| **Usage metrics** | Partial data only: Report Open events, no page views or performance data. |
| **Spark starter pools** | Disabled. Jobs move to on-demand custom pools in the workspace's managed VNet, so expect **cold-start latency** on every job. |
| **Capacity Metrics app** | Not supported. |
| **OneLake Catalog Govern tab** | Unavailable. |
| **External images and themes** | Unavailable in reports. |
| **Cross-tenant shortcuts / OneLake data sharing** | Not supported, as Private Link is single-tenant by design. Use OneLake data sharing outside the private path. |
| **Trial capacities** | Don't work over Private Link traffic. |
| **Tenant migration** | Blocked entirely while Private Link is on. |
| **Data Warehouse in pipelines** | Copying data into or out of a Warehouse isn't possible. |
| **Eventstream custom endpoints** | Unsupported as either source or destination. Activator can't ingest from Eventstream. |
| **Data agents** | Kusto, semantic models, and mirrored sources unsupported. No cross-region private-link access for SQL. |
| **Eventhouse** | No OneLake ingestion, no shortcuts to it, no pipeline connection, no queued ingestion, no T-SQL querying. |

#### Additionally broken by blocking public access

| What breaks | Impact |
| --- | --- |
| **Email subscriptions** | Not supported. |
| **Usage metrics** | Goes from partial to **nothing**, because dataset refresh fails outright. |
| **Visual query in Warehouse** | Stops working. |
| **Semantic model / Datamart / Dataflow Gen1 chaining** | Connections fail where one uses another as a source. |
| **Mirrored databases** | Types outside the supported list (open mirroring, Cosmos DB, SQL MI, SAP, SharePoint List, SQL Server 2025) **enter a paused state and can't be started.** |
| **Azure event sources** | Blocked from delivering into Fabric. New configurations blocked; existing ones move to paused. |

#### Operational constraints

- **450 capacities** maximum in a Private Link tenant.
- **Up to 24 hours** before a newly created capacity works, pending private DNS zone propagation.
- **One tenant per private endpoint.** You can't reach multiple Fabric tenants from the same network
  location, only the last one to set up DNS records.
- A set of URLs must stay reachable from client browsers regardless (`login.microsoftonline.com`,
  `graph.microsoft.com`, and for Data Engineering/Data Science, `pypi.org`, `cdn.jsdelivr.net`, and
  others). A genuinely airgapped browser won't work.

#### How this changes the other recommendations

Read these together rather than in isolation:

- **Information protection.** The whole group is recommended `On` above, but Purview IP doesn't work
  under Private Link. Sort out service tags for EOP/AIP *before* enabling, or you'll turn on labels
  and find they've stopped working in Desktop.
- **Copilot.** `EnableAOAI` is moot under Private Link. Decide which capability you want.
- **Audit and usage.** `UsageMetrics` and the Capacity Metrics app degrade or break. Lean on audit
  logs and a SIEM instead, which is where MCSB LT-5 points anyway.
- **Export settings.** PDF/PowerPoint export and email subscriptions stop working. Some of the
  export debate resolves itself.
- **Gateways.** If you depend on on-premises data gateways, migrating to VNet data gateways is a
  prerequisite, not a follow-up.

The honest summary: **Private Link is the right end state for a genuinely sensitive tenant, and a bad
fit for a general-purpose analytics tenant that needs gateways, Copilot, labels in Desktop, and
subscriptions.** Consider [workspace-level private links](https://learn.microsoft.com/en-us/fabric/security/security-workspace-level-private-links-overview)
first, since they confine both the protection and the breakage to the workspaces that need it, rather than
imposing it tenant-wide.

---

## Admin API and Developer settings

Who can automate against the tenant, and how much they see.

| Setting | What it does | Preferred | Why |
| --- | --- | --- | --- |
| `AllowServicePrincipalsUseReadAdminAPIs` | SPs can call read-only admin APIs | **On (scoped)** | Required for automated governance/inventory. Grants read of *all* metadata including user names and emails, so scope tightly to one automation group. |
| `AllowServicePrincipalsUseWriteAdminAPIs` | SPs can call update admin APIs | **On (scoped)** | Needed for declarative tenant management (this repo). Full admin write, the most privileged setting here. One dedicated SP, one group, no humans. |
| `AdminApisIncludeDetailedMetadata` | Admin APIs return table/column names | **Off unless needed** | Widens what a compromised automation identity can harvest. Enable only if your catalogue needs it. |
| `AdminApisIncludeExpressions` | Admin APIs return DAX and M expressions | **Off unless needed** | Query logic often embeds connection details and business rules. |
| `ServicePrincipalAccessGlobalAPIs` | SPs can create workspaces, connections, pipelines | **On (scoped)** | Core CI/CD enabler. Scope to deployment identities. |
| `ServicePrincipalAccessPermissionAPIs` | SPs can call Fabric public APIs | **On (scoped)** | As above. |
| `AllowServicePrincipalsCreateAndUseProfiles` | SP profiles for multi-tenant apps | **Off unless needed** | Only relevant to embedded multi-tenancy scenarios. |
| `BlockResourceKeyAuthentication` | Block resource-key auth for streaming datasets | **On** | Kills a shared-secret auth path. Straightforward hardening, and it pushes you towards Entra identities. |
| `Embedding` | Embed content in apps ("for your customers") | **Off unless needed** | Embedded analytics is a deliberate architecture, not a default. |
| `ConfigureFabricIdentityTenantLimit` | Cap on Fabric identities in the tenant | **Org choice** | Defaults to 10,000. A guardrail against runaway workspace-identity creation. |

---

## Information protection

The classification layer. If these are off, label-driven controls elsewhere have nothing to act on.

| Setting | What it does | Preferred | Why |
| --- | --- | --- | --- |
| `EimInformationProtectionEdit` | Users can apply sensitivity labels | **On** | The foundation. WAF: "Enforce the use of sensitivity labels on all content." Requires Purview prerequisites first. |
| `EimInformationProtectionDataSourceInheritanceSetting` | Inherit labels from data sources | **On** | Classification should follow the data, not depend on a user remembering. |
| `EimInformationProtectionDownstreamInheritanceSetting` | Apply labels to downstream content | **On** | Prevents label laundering, where an unlabelled report is derived from labelled data. |
| `EimInformationProtectionWorkspaceAdminsOverrideAutomaticLabelsSetting` | Workspace admins can override auto-labels | **Off** | Override defeats automatic classification. Enable only with a genuine false-positive problem. |
| `BlockProtectedLabelSharingToEntireOrg` | Block org-wide links on protected content | **On** | Closes the gap between "this is confidential" and "here's a link for everyone". |
| `EimInformationProtectionDefaultLabelDomainSetting` | Domain admins set default domain labels | **Org choice** | Useful with mature domain governance; premature otherwise. |
| `DataSecurityForAIInteractions` | Purview secures AI prompts/responses | **On if using Copilot** | Brings AI interactions into DLP, audit, and eDiscovery. Note: paid Purview capability, not included in Copilot pricing. |

> **Important caveat.** Label-based access control is only enforced in the tenant where labels were
> applied, in .pbix files, and in Excel/PowerPoint/PDF via supported export paths. It is **not**
> enforced in cross-tenant scenarios such as external data sharing, or on .csv/.txt export. Labels
> are a strong control with specific, documented holes, so don't treat them as a perimeter.

---

## OneLake settings

| Setting | What it does | Preferred | Why |
| --- | --- | --- | --- |
| `OneLakeForThirdParty` | External apps (ADLS APIs, Databricks) reach OneLake | **Off unless needed** | Opens OneLake to non-Fabric tooling where Fabric-side controls don't apply. |
| `AllowGetOneLakeUDK` | Issue short-lived user-delegated SAS keys | **Off unless needed** | Max one-hour lifetime and tied to a user identity, so far better than static keys, but still a token-based path out of the platform. |
| `AllowOneLakeUDK` | Authenticate using OneLake SAS tokens | **Off unless needed** | Consumption side of the above. Both are needed for the flow to work. |
| `OneLakeFileExplorer` | OneLake File Explorer sync to Windows | **Off unless needed** | Syncs lake data onto endpoints, moving it into endpoint-DLP territory. |
| `OneLakeDiagnosticLogsEUII` | Include end-user identifiers in diagnostic logs | **On** | Investigations need to know *who*. Weigh against privacy/works-council obligations, because this is a real trade-off rather than a free win. |

---

## Integration settings

Mostly per-connector SSO. Each one forwards user identity (name, email) to a third party, so the rule
is simple: **on only for connectors actually in use**.

| Setting | What it does | Preferred | Why |
| --- | --- | --- | --- |
| `SnowflakeSSO`, `RedshiftSSO`, `DremioSSO`, `GoogleBigQuerySSO`, `DenodoForPowerBISSO`, `StarburstAadSSO` | Per-connector SSO | **Off unless that connector is used** | Each sends user token info externally. SSO itself is good practice (MCSB IM-5), and the risk is leaving unused ones on. |
| `AADSSOForGateway` | Entra SSO for on-premises gateway | **On if gateway used** | Delegated identity beats stored credentials. |
| `AADSSOForVnetGateway` | Entra SSO for VNet gateway | **On if VNet gateway used** | As above. |
| `ASShareableCloudConnectionBindingSecurityModeTenant` | Granular access control for all data connections | **On** | Disconnects shared items when edited by users lacking connection rights. Closes a real privilege-inheritance gap. |
| `AllowNonEntraADAuthInEventStream` | Permit non-Entra (key-based) auth in Eventstream | **Off** | Turning this **off** is what forces Entra-only auth on custom endpoints. The portal wording describes the benefit of disabling it, which reads backwards. Check the actual state, not the sentence. |
| `OnPremAnalyzeInExcel` | XMLA endpoints + Analyze in Excel on-prem models | **Off unless needed** | WAF: "keep XMLA endpoints limited." Full model access. |
| `DatasetExecuteQueries` | Execute Queries REST API (DAX over REST) | **Off unless needed** | Programmatic bulk data extraction path. |
| `PowerBIMCP` | Power BI MCP server endpoint (preview) | **Off unless needed** | New surface exposing artifacts to MCP clients. Preview, so evaluate deliberately. |
| `ODSPRefreshEnforcementTenantAllowAutomaticUpdate` | Auto-update models from OneDrive/SharePoint files | **Off** | File changes can introduce **new data connections** without review. Quiet supply-chain-ish path into a model. |
| `OneDriveSharePointViewerIntegrationTenantSettingV2` / `OneDriveSharePointAllowSharingTenantSetting` | View/share .pbix in OneDrive & SharePoint | **Org choice** | Permissions governed by OneDrive/SharePoint. |
| `VisualizeListInPowerBI` | SharePoint / Microsoft Lists integration | **Org choice** | Functional. |
| `UseAdbcByDefault` | Apache Arrow (ADBC) connectivity | **Org choice** | Performance/protocol choice. |
| `ArtifactSearchTenant` | Global search bar | **Org choice** | Usability. |
| `ASWritethruContinuousExportTenantSwitch` | Semantic models export to OneLake | **Org choice** | Keeps data inside the tenant boundary. |
| `EnableEsriLibraries`, `EsriVisual`, `AzureMaps`, `BingMap` | Mapping visuals/libraries | **Org choice** | Enable what's used. |
| `AzureMapsCrossRegionDataProcessing`, `AzureMapsThirdPartyDataProcessing` | Map data leaves region / goes to subprocessors | **Off if data residency matters** | These are residency decisions, not feature toggles. |

---

## Copilot, Azure OpenAI, and Azure AI

The controlling question is **data residency**, not whether AI is "safe".

| Setting | What it does | Preferred | Why |
| --- | --- | --- | --- |
| `EnableAOAI` | Copilot and Azure OpenAI features | **On (scoped)** | Start with a pilot group rather than tenant-wide. Adheres to EU Data Boundary commitments for EU customers. |
| `AllowSendAOAIDataToOtherRegions` | Process AI data outside your geo/compliance boundary | **Off where residency is a requirement** | Only relevant if your capacity sits outside the EU Data Boundary or US. A compliance decision. |
| `AllowStoreAOAIDataInOtherRegions` | *Store* AI data outside your boundary | **Off where residency is a requirement** | Storage is a higher bar than transient processing, so hold this one harder. |
| `AllowUserDataProcessedByAiServicesOutOfGeo` | Same, for Azure AI services | **Off where residency is a requirement** | Consistency with the above. |
| `CopilotCapacitySetupPermissionSwitch` | Designate Copilot capacities | **Org choice** | Billing consolidation. Note capacity admins then see item names tied to user Copilot activity. |
| `ImmersiveTenantAdminSwitch` | Standalone cross-item Copilot (preview) | **Off unless piloting** | Preview; broadens Copilot's reach across items. |
| `PreppedForCopilotContentDiscovery` | Only approved items in standalone Copilot | **On** | Constrains Copilot to curated, quality-checked items. Cheap guardrail. |
| `MicrosoftFoundryTelemetry` | Agent metadata to Microsoft Foundry | **Off unless needed** | Sends metadata to an App Insights resource possibly outside your region/boundary. |
| `AllowA365Observability` | Operations Agent data to Agent 365 (preview) | **Off unless needed** | Same class of cross-boundary processing. |

---

## Workspace settings

| Setting | What it does | Preferred | Why |
| --- | --- | --- | --- |
| `CreateAppWorkspaces` | Who can create workspaces | **On (scoped)** | WAF: "Restrict workspace creation to admins to prevent sprawl and misconfigurations." Ungoverned sprawl is the root of most Fabric governance debt. |
| `ConfigureFolderRetentionPeriod` | Deleted-workspace retention window | **On** | Minimum 7 days regardless; up to 90 configurable. Recovery capability at no security cost. |
| `ConfigureArtifactRetentionPeriod` | Fabric item recovery | **On** | **Off means item deletion is permanent and immediate.** Cheap insurance against accidental and malicious deletion alike. |
| `RestrictMyFolderCapacity` | Block reassigning My Workspace off Premium | **On** | Keeps personal workspaces on governed capacity. |
| `UseDatasetsAcrossWorkspaces` | Reuse semantic models across workspaces | **On** | Still requires Build permission. Supports a single-source-of-truth model. |
| `AutomaticallyUsePBIR` | Auto-convert reports to PBIR format | **Org choice** | Source-control-friendly format; helps Git workflows. Preview. |

---

## Git integration

| Setting | What it does | Preferred | Why |
| --- | --- | --- | --- |
| `GitIntegrationTenantSwitch` | Sync workspace items with Git | **On (scoped)** | WAF actively recommends Git-connected workspaces for change tracking and review. A security *positive*. |
| `GitHubTenantSettings` | Allow GitHub as the provider | **Org choice** | Depends on where your repos live. |
| `GitIntegrationSensitivityLabelsTenantSwitch` | Export labelled items to Git | **Off** | Labels don't travel into Git, so this exports classified content into a store with different controls. |
| `GitIntegrationCrossGeoTenantSwitch` | Export to repos in other geographies | **Off where residency matters** | Straightforward data-residency question. |

---

## Additional workloads and template apps

Third-party code and content. Note the standout caveat: **sensitivity labels and encryption are not
applied to items created with additional workloads**, and user data and access tokens are sent to
the workload publisher.

| Setting | What it does | Preferred | Why |
| --- | --- | --- | --- |
| `ThirdPartyPrivateWorkloads` | Workloads not validated by Microsoft | **Off** | Unvalidated third-party code with token access. Only for publishers you actively trust. |
| `FabricAddWorkloadToWorkspace` | Workspace admins add/remove workloads | **Off unless needed** | Pushes a trust decision down to every workspace admin. |
| `FabricAddPartnerWorkload` | Capacity admins add/remove workloads | **Off unless needed** | Same, at capacity scope. |
| `FabricThirdPartyWorkloads` | Workspace admins develop partner workloads | **Off** | Development capability; enable in dev tenants only. |
| `InstallServiceApps` | Install template apps from AppSource | **Org choice** | AppSource-listed apps have passed validation. |
| `InstallNonvalidatedTemplateApps` | Install apps *not* in AppSource | **Off** | Unvalidated packages that create workspaces on install. |
| `DevelopServiceApps` / `TemplatePublish` | Publish template apps externally | **Off unless needed** | Outbound distribution of org content. |

---

## Visuals

| Setting | What it does | Preferred | Why |
| --- | --- | --- | --- |
| `CertifiedCustomVisualsTenant` | Certified visuals only | **On** | Certified visuals can't access external services. The main control against a visual phoning home. |
| `CustomVisualsTenant` | Allow SDK visuals from AppSource/file | **On (scoped)** | Pair with the certified-only setting above. |
| `AllowCVToExportDataToFileTenant` | Custom visuals can download data | **Off** | Explicitly **bypasses your export restrictions**, and the docs say so outright. A hole straight through the export controls. |
| `AllowCVAuthenticationTenant` | AppSource visuals SSO | **Off** | Hands Entra tokens (with names and emails) to third-party visual code, possibly across regions. |
| `AllowCVLocalStorageV2Tenant` | Visuals use browser local storage | **Org choice** | Minor; data persists client-side. |
| `WebContentTilesTenant` | Web content tiles on dashboards | **Off** | Microsoft's own description warns it "may expose your org to security risks via malicious web content". |
| `RScriptVisual` | R and Python visuals | **Off unless needed** | Arbitrary script execution in a visual context. |

---

## Audit, usage, and monitoring

| Setting | What it does | Preferred | Why |
| --- | --- | --- | --- |
| `PlatformMonitoringTenantSetting` | Workspace admins enable monitoring | **On** | Supports MCSB LT-3. Creates a read-only Eventhouse per workspace. |
| `LogAnalyticsAttachForWorkspaceAdmins` | Log Analytics connections | **On (scoped)** | Route to a SIEM. MCSB LT-5 wants centralised log management. |
| `UsageMetrics` | Usage metrics for content creators | **On** | Adoption and stale-content insight. |
| `UsageMetricsTrackUserLevelInfo` | Per-user data in usage metrics | **Org choice** | Exposes names and emails to *content creators*, not just admins. Privacy/works-council question. |
| `AllowCapacityMetricsReportUserMask` | Show user data in Capacity Metrics | **Org choice** | Same trade-off in the capacity app. |
| `ASCollectQueryTextTelemetryTenantSwitch` | Microsoft stores query text for support | **Org choice** | Off is more private; Microsoft notes it "might negatively impact" their ability to support you. |

---

## Discovery, apps, and everything else

Largely functional. Defaults are reasonable; decide on use case.

| Setting | What it does | Preferred | Why |
| --- | --- | --- | --- |
| `DiscoverDatasetsConsumption` / `DiscoverDatasetsSettingsCertified` / `DiscoverDatasetsSettingsPromoted` | Discoverability of endorsed content | **On** | Metadata-only discovery with request-access. Drives reuse over duplication. |
| `OneLakeCatalogSubItemDiscovery` | Surface sub-items (tables, files) in OneLake catalog search | **Org choice** | Metadata and names only; opening anything still needs permission. Deeper search results at the cost of exposing more object names to users who can't open them. |
| `AppPush` | Push apps to end users without AppSource | **Org choice** | Convenience; still permission-bound. |
| `PublishContentPack` | Publish apps org-wide | **On (scoped)** | Restrict who can publish to the entire organisation. |
| `M365DataSharing` | Share Fabric data with M365 services | **Org choice** | Improves M365 search/recommendations; users only see what they can access. Auto-enabled only when both tenants share a region. |
| `WorkspaceCmk` | Customer-managed keys | **Off unless required** | MCSB DP-5: use CMK "if required for regulatory compliance". Real operational burden: lose the key, lose the data. Not free security. |
| `BlockAutoDiscoverAndPackageRefresh` | Block republish / disable package refresh | **Org choice** | Locks model updates to the owner. |
| `WebModelingTenantSwitch` | Edit semantic models in the service | **Org choice** | Governance preference, weighing browser editing against source-controlled Desktop. |
| `EnableReassignDataDomainSwitch` | Admins override workspace domain assignment | **On** | Administrative flexibility, admin-only. |
| `AllowFreeTrial` | Users can start Fabric trials | **Org choice** | Cost governance more than security, since trials create real capacity. |
| `EmailSecurityGroupsOnOutage` / `InProductOutageNotification` | Outage notifications | **On** | Free operational awareness. Point at a monitored mail-enabled group. |
| `FabricGAWorkloads` | Users can create Fabric items | **On (scoped)** | The master switch for Fabric item creation. |
| Preview item types (`OntologyPreview`, `DigitalOperationsPreview`, `ArtifactDBTItemTenantSwitch`, `AppBackendTenant`, `ArtifactMirroredCatalogPreview`, `EventDefinitionTenantSwitch`, `MLModelEndpointsTenantSwitch`, `RTHAnomalyDetectionTenantSwitch`, `ArtifactDatabricksStoragePreview`) | Enable preview workloads | **Off by default** | Enable individually as evaluated. Preview terms apply, and preview features change without the usual guarantees. |
| `EnableAnonymousDataAccessForFabricApps` | Anonymous data access for Fabric Apps | **Off** | Unauthenticated internet users querying your data. Treat with the same seriousness as Publish to web. |
| `FabricFeedbackTenantSwitch` / `FabricPromotionTenantSwitch` / `ExpFlightingTenant` | Surveys, conference promos, UX experiments | **Org choice** | Cosmetic. |
| `AzureMapsInFabric` / `AzureMapsWeatherServices` | Azure Maps services and weather data | **Org choice** | Feature enablement. Weather data is sourced from AccuWeather. |
| `AzureMapsInFabricCrossRegionDataProcessing` | Azure Maps data processed outside your boundary | **Off if data residency matters** | Residency decision, same as the Integration-group Azure Maps toggles. |
| `DatamartTenant` | Create Datamarts (preview) | **Org choice** | Preview feature; largely superseded by Fabric warehouses. |
| `AdminDataExploreViewPermission` | View-permission users can launch Explore | **Org choice** | Ad-hoc exploration bounded by existing model permissions. |
| `CDSAManagement` | Create and use Gen1 dataflows | **Org choice** | Legacy; prefer Dataflow Gen2 for new work. |
| `TenantSettingPublishGetHelpInfo` | Internal help and support links | **On** | Points users at your own support process. Free usability win. |
| `AdminCustomDisclaimer` | Custom message before publishing | **Org choice** | A useful nudge for handling-policy reminders at publish time. |
| `AutomatedInsightsTenant` / `AutomatedInsightsEntryPoints` | Automated insights notifications and entry points | **Org choice** | Preview convenience features. |
| `RealTimeDashboardEmbeddedApp` | Embedded app visuals in Real-Time Dashboards | **Off unless needed** | Embeds app content into dashboards, the same class of consideration as web content tiles. |
| `AllowOperatorInsightsTenantSwitch` | Insights for operations agents (preview) | **Org choice** | Explainability over agent activity. |
| `ShowActivatorEntryPointsTenantSwitch` | Show "Set alert" button to all Power BI users | **Org choice** | Cosmetic, since only users who can create Fabric items can actually set alerts. |
| `QnaFeedbackLoop` | Owners review questions asked of their data | **Org choice** | Model-improvement feedback. |
| `QnaLsdlSharing` | Share Q&A synonyms org-wide | **Org choice** | Improves natural-language quality. |
| `QueryScaleOutTenant` | Scale out queries for large semantic models | **On** | Performance; no security impact. |
| `PowerBIGoalsTenant` | Create and use Scorecards | **Org choice** | Feature enablement. |

---

## Applying this

Three practical notes.

**Sequence the networking changes.** `BlockAccessFromPublicNetworks` before a working Private Link
locks everyone out, including the admin making the change. Prove the private path first.

**Scope before you enable.** For the ~107 settings supporting security groups, `On (scoped)` is
nearly always better than `On`. The Bicep model in this repo expresses that directly through
`enabledSecurityGroups`.

**Treat this as drift detection, not a one-off.** New settings appear regularly. This capture found
171, and that number moves. The Well-Architected guidance is to compare live configuration against a
baseline and alert on deviation; `scripts/get-tenant-settings.ps1` plus the checked-in
`deploy/tenant-settings.baseline.bicepparam` is how that works here, with `scripts/baseline.json` holding the posture for each setting so this document's recommendations are machine-readable rather than prose only.

## Sources

- [Tenant settings index, Microsoft Fabric](https://learn.microsoft.com/en-us/fabric/admin/tenant-settings-index), the authoritative per-setting reference
- [Security considerations for Microsoft Fabric workloads, Azure Well-Architected Framework](https://learn.microsoft.com/en-us/azure/well-architected/microsoft-fabric/security)
- [Azure security baseline for Microsoft Fabric](https://learn.microsoft.com/en-us/security/benchmark/azure/baselines/fabric-security-baseline) (MCSB v1.0)
- [Microsoft Fabric security fundamentals](https://learn.microsoft.com/en-us/fabric/security/security-fundamentals)
- [Microsoft Fabric end-to-end security scenario](https://learn.microsoft.com/en-us/fabric/security/security-scenario)
