---
template_version: 0.2.0
last_updated: 2026-04-29
compatible_with: ACE Flow Builder v0.2.0+
status: beta
---
# ACE .msgflow XML Format Reference

Source: Extracted from IBM ACE v13 official pattern zips (September 2024).
All examples below are verified against `references/examples/` files.

---

## Correct XML Structure

```xml
<?xml version="1.0" encoding="UTF-8"?>
<ecore:EPackage xmi:version="2.0"
  xmlns:xmi="http://www.omg.org/XMI"
  xmlns:ComIbmWSInput.msgnode="ComIbmWSInput.msgnode"
  xmlns:ComIbmWSReply.msgnode="ComIbmWSReply.msgnode"
  xmlns:ComIbmCompute.msgnode="ComIbmCompute.msgnode"
  xmlns:ecore="http://www.eclipse.org/emf/2002/Ecore"
  xmlns:eflow="http://www.ibm.com/wbi/2005/eflow"
  xmlns:utility="http://www.ibm.com/wbi/2005/eflow_utility"
  nsURI="<schema-path>/FlowName.msgflow"
  nsPrefix="<schema-path>/FlowName.msgflow">
  <!-- nsURI/nsPrefix = this .msgflow's path relative to the project root: the BROKER
       SCHEMA with dots->slashes, then the filename. Bare "FlowName.msgflow" is correct
       ONLY for a default-schema (root) flow. See "nsURI / nsPrefix" below. -->

  <eClassifiers xmi:type="eflow:FCMComposite" name="FCMComposite_1" nodeLayoutStyle="RECTANGLE">
    <eSuperTypes href="http://www.ibm.com/wbi/2005/eflow#//FCMBlock"/>
    <translation xmi:type="utility:TranslatableString" key="FlowName" bundleName="FlowName" pluginId="FlowName"/>
    <colorGraphic16 xmi:type="utility:GIFFileGraphic" resourceName="platform:/plugin/FlowName/icons/full/obj16/FlowName.gif"/>
    <colorGraphic32 xmi:type="utility:GIFFileGraphic" resourceName="platform:/plugin/FlowName/icons/full/obj30/FlowName.gif"/>

    <composition>
      <!-- NODES go here -->
      <!-- CONNECTIONS go here -->
    </composition>

    <propertyOrganizer/>
    <stickyBoard/>
  </eClassifiers>
</ecore:EPackage>
```

---

## Node Type Reference

Only include the namespace declarations for node types actually used in the flow.

**Authoritative source-of-truth on disk.** When uncertain about a node's `xmi:type` (or when adding a node that isn't in the table below), check the local ACE schema file:

```
C:\Program Files\IBM\ACE\13.0.7.0\common\schemas\MessageFlow\MessageFlow.xsd
```

Every valid node type has an element entry there whose `name` attribute matches the suffix of the xmi:type. Read it before guessing, and definitely before copying an `xmi:type` value out of an unrelated example flow - older flows in the wild can carry IIB-era types (`.msgflow:` namespace, `ComIbmHTTPInput`, etc.) that no longer load in v13.

**Subflow Input/Output use a different namespace.** Inline subflows (sources and sinks declared inside the same `.msgflow`) use the `eflow:` namespace, not `ComIbm*.msgnode`:

| Node | xmi:type | Notes |
|---|---|---|
| Subflow Input | `eflow:FCMSource` | Marks the input boundary of an inline subflow |
| Subflow Output | `eflow:FCMSink` | Marks the output boundary of an inline subflow |

Standalone callable subflows (separate `.subflow` files invoked via a Callable Flow Invoke node) use yet another set: `ComIbmCallableFlowInput`, `ComIbmCallableFlowReply`, `ComIbmCallableFlowInvoke`, `ComIbmCallableFlowAsyncInvoke`, `ComIbmCallableFlowAsyncResponse`. Pick the right family for the subflow style in use.

| Node type | xmlns declaration | xmi:type in `<nodes>` | Key attributes |
|-----------|-------------------|-----------------------|----------------|
| HTTP Input | `xmlns:ComIbmWSInput.msgnode="ComIbmWSInput.msgnode"` | `ComIbmWSInput.msgnode:FCMComposite_1` | `URLSpecifier="/path"`, `messageDomainProperty="XMLNSC"` or `"JSON"` |
| HTTP Reply | `xmlns:ComIbmWSReply.msgnode="ComIbmWSReply.msgnode"` | `ComIbmWSReply.msgnode:FCMComposite_1` | - |
| HTTP Request (outbound) | `xmlns:ComIbmWSRequest.msgnode="ComIbmWSRequest.msgnode"` | `ComIbmWSRequest.msgnode:FCMComposite_1` | See **HTTPRequest (ComIbmWSRequest)** section below |
| Timeout Control | `xmlns:ComIbmTimeoutControl.msgnode="ComIbmTimeoutControl.msgnode"` | `ComIbmTimeoutControl.msgnode:FCMComposite_1` | See **Timer Nodes** section below |
| Timeout Notification | `xmlns:ComIbmTimeoutNotification.msgnode="ComIbmTimeoutNotification.msgnode"` | `ComIbmTimeoutNotification.msgnode:FCMComposite_1` | See **Timer Nodes** section below |
| Compute (ESQL) | `xmlns:ComIbmCompute.msgnode="ComIbmCompute.msgnode"` | `ComIbmCompute.msgnode:FCMComposite_1` | `computeExpression="esql://routine/<BrokerSchema>#ModuleName.Main"` (`<BrokerSchema>` = dotted package - see *computeExpression Format*) |
| Java Compute | `xmlns:ComIbmJavaCompute.msgnode="ComIbmJavaCompute.msgnode"` | `ComIbmJavaCompute.msgnode:FCMComposite_1` | `javaClass="com.example.ClassName"` |
| Mapping | `xmlns:ComIbmMSLMapping.msgnode="ComIbmMSLMapping.msgnode"` | `ComIbmMSLMapping.msgnode:FCMComposite_1` | `mappingExpression="msl://{default}#MappingName"` |
| MQ Input | `xmlns:ComIbmMQInput.msgnode="ComIbmMQInput.msgnode"` | `ComIbmMQInput.msgnode:FCMComposite_1` | `queueName="QUEUE.NAME"` |
| MQ Output | `xmlns:ComIbmMQOutput.msgnode="ComIbmMQOutput.msgnode"` | `ComIbmMQOutput.msgnode:FCMComposite_1` | `queueName="QUEUE.NAME"` |
| File Input | `xmlns:ComIbmFileInput.msgnode="ComIbmFileInput.msgnode"` | `ComIbmFileInput.msgnode:FCMComposite_1` | `inputDirectory="C:\path"` |
| File Output | `xmlns:ComIbmFileOutput.msgnode="ComIbmFileOutput.msgnode"` | `ComIbmFileOutput.msgnode:FCMComposite_1` | `outputDirectory="C:\path"`, `outputFilename="file.txt"` |
| Trace | `xmlns:ComIbmTrace.msgnode="ComIbmTrace.msgnode"` | `ComIbmTrace.msgnode:FCMComposite_1` | `destination="file"`, `filePath="C:\temp\trace.txt"`, `pattern="${Root}"` - see **Trace `pattern` syntax** below |

---

## Extended Node Type Reference

Nodes beyond the common ones above. The xmlns declaration follows the standard form (`xmlns:<suffix>="<suffix>"`); for compactness the table just lists the xmi:type suffix, which you append `:FCMComposite_1` to inside `<nodes xmi:type="…">`.

When uncertain about an attribute, check `MessageFlow.xsd` (see top of this file) and the user's own existing flows from Phase B0.5.

### Routing, flow control, error handling

| Node | xmi:type suffix |
|---|---|
| Throw | `ComIbmThrow.msgnode` |
| Validate | `ComIbmValidate.msgnode` |
| Log | `ComIbmLog.msgnode` |
| Filter | `ComIbmFilter.msgnode` |
| Route | `ComIbmRoute.msgnode` |
| Route To Label | `ComIbmRouteToLabel.msgnode` |
| Label | `ComIbmLabel.msgnode` |
| Pass through | `ComIbmPassthru.msgnode` |
| Flow Order | `ComIbmFlowOrder.msgnode` |
| Resequence | `ComIbmReSequence.msgnode` |
| Sequence | `ComIbmSequence.msgnode` |
| Security PEP | `ComIbmSecurityPEP.msgnode` |

### Aggregation / Scatter-Gather

| Node | xmi:type suffix |
|---|---|
| Aggregate Control | `ComIbmAggregateControl.msgnode` |
| Aggregate Request | `ComIbmAggregateRequest.msgnode` |
| Aggregate Reply | `ComIbmAggregateReply.msgnode` |
| Collector | `ComIbmCollector.msgnode` |
| Group Scatter | `ComIbmGroupScatter.msgnode` |
| Group Gather | `ComIbmGroupGather.msgnode` |
| Group Complete | `ComIbmGroupComplete.msgnode` |

### Callable subflows (separate `.subflow` files)

For inline subflow boundaries (`eflow:FCMSource` / `eflow:FCMSink`) see the top of this file.

| Node | xmi:type suffix |
|---|---|
| Callable Flow Input | `ComIbmCallableFlowInput.msgnode` |
| Callable Flow Reply | `ComIbmCallableFlowReply.msgnode` |
| Callable Flow Invoke | `ComIbmCallableFlowInvoke.msgnode` |
| Callable Flow Async Invoke | `ComIbmCallableFlowAsyncInvoke.msgnode` |
| Callable Flow Async Response | `ComIbmCallableFlowAsyncResponse.msgnode` |

### Mapping & transformation

| Node | xmi:type suffix |
|---|---|
| JSONata Mapping | `ComIbmJSONataMapping.msgnode` |
| Mapping (MSL) | `ComIbmMSLMapping.msgnode` |
| XSL Transform | `ComIbmXslMqsi.msgnode` |
| Reset Content Descriptor | `ComIbmResetContentDescriptor.msgnode` |
| .NET Compute | `ComIbmDotNetCompute.msgnode` |

### File operations (extended)

| Node | xmi:type suffix |
|---|---|
| File Read | `ComIbmFileRead.msgnode` |
| File Exists | `ComIbmFileExists.msgnode` |
| File Iterator | `ComIbmFileIterator.msgnode` |
| FTE Input | `ComIbmFTEInput.msgnode` |
| FTE Output | `ComIbmFTEOutput.msgnode` |
| CD Input | `ComIbmCDInput.msgnode` |
| CD Output | `ComIbmCDOutput.msgnode` |

### MQ (extended)

| Node | xmi:type suffix |
|---|---|
| MQ Get | `ComIbmMQGet.msgnode` |
| MQ Reply | `ComIbmMQReply.msgnode` |
| MQ Header | `ComIbmMQHeader.msgnode` |
| Publication | `ComIbmPublication.msgnode` |

### HTTP / REST / SOAP

| Node | xmi:type suffix |
|---|---|
| HTTP Header | `ComIbmHTTPHeader.msgnode` |
| HTTP Async Request | `ComIbmHTTPAsyncRequest.msgnode` |
| HTTP Async Response | `ComIbmHTTPAsyncResponse.msgnode` |
| REST Request | `ComIbmRESTRequest.msgnode` |
| REST Async Request | `ComIbmRESTAsyncRequest.msgnode` |
| REST Async Response | `ComIbmRESTAsyncResponse.msgnode` |
| App Connect REST Request | `ComIbmAppConnectRESTRequest.msgnode` |
| SOAP Input | `ComIbmSOAPInput.msgnode` |
| SOAP Reply | `ComIbmSOAPReply.msgnode` |
| SOAP Request | `ComIbmSOAPRequest.msgnode` |
| SOAP Async Request | `ComIbmSOAPAsyncRequest.msgnode` |
| SOAP Async Response | `ComIbmSOAPAsyncResponse.msgnode` |
| SOAP Envelope | `ComIbmSOAPEnvelope.msgnode` |
| SOAP Extract | `ComIbmSOAPExtract.msgnode` |

### Database

| Node | xmi:type suffix |
|---|---|
| Database | `ComIbmDatabase.msgnode` |
| Database Input | `ComIbmDatabaseInput.msgnode` |
| Database Retrieve | `ComIbmDatabaseRetrieve.msgnode` |
| Database Route | `ComIbmDatabaseRoute.msgnode` |
| Change Data Capture | `ComIbmChangeDataCapture.msgnode` |
| ODM Rules | `ComIbmODMRules.msgnode` |

### Messaging (JMS / Kafka)

| Node | xmi:type suffix |
|---|---|
| JMS Input | `ComIbmJMSClientInput.msgnode` |
| JMS Output | `ComIbmJMSClientOutput.msgnode` |
| JMS Reply | `ComIbmJMSClientReply.msgnode` |
| JMS Receive | `ComIbmJMSClientReceive.msgnode` |
| JMS Header | `ComIbmJMSHeader.msgnode` |
| Kafka Consumer | `ComIbmKafkaMsgConsumer.msgnode` |
| Kafka Producer | `ComIbmKafkaMsgProducer.msgnode` |
| Kafka Read | `ComIbmKafkaMsgRead.msgnode` |

### Email & TCP/IP

| Node | xmi:type suffix |
|---|---|
| Email Input | `ComIbmEmailInput.msgnode` |
| Email Output | `ComIbmEmailOutput.msgnode` |
| TCPIP Client Input | `ComIbmTCPIPClientInput.msgnode` |
| TCPIP Client Output | `ComIbmTCPIPClientOutput.msgnode` |
| TCPIP Client Receive | `ComIbmTCPIPClientReceive.msgnode` |
| TCPIP Server Input | `ComIbmTCPIPServerInput.msgnode` |
| TCPIP Server Output | `ComIbmTCPIPServerOutput.msgnode` |
| TCPIP Server Receive | `ComIbmTCPIPServerReceive.msgnode` |

### Scheduling

| Node | xmi:type suffix |
|---|---|
| Scheduler | `ComIbmScheduler.msgnode` |

### Enterprise systems (built-in nodes - distinct from the App Connector family below)

| Node | xmi:type suffix |
|---|---|
| SAP Input | `ComIbmSAPInput.msgnode` |
| SAP Request | `ComIbmSAPRequest.msgnode` |
| SAP Reply | `ComIbmSAPReply.msgnode` |
| JDEdwards Input | `ComIbmJDEdwardsInput.msgnode` |
| JDEdwards Request | `ComIbmJDEdwardsRequest.msgnode` |
| PeopleSoft Input | `ComIbmPeopleSoftInput.msgnode` |
| PeopleSoft Request | `ComIbmPeopleSoftRequest.msgnode` |
| Siebel Input | `ComIbmSiebelInput.msgnode` |
| Siebel Request | `ComIbmSiebelRequest.msgnode` |
| .NET Input | `ComIbmDotNetInput.msgnode` |

### Mainframe / legacy

| Node | xmi:type suffix |
|---|---|
| CICS Request | `ComIbmCICSIPICRequest.msgnode` |
| IMS Request | `ComIbmIMSRequest.msgnode` |
| CORBA Request | `ComIbmCORBARequest.msgnode` |

---

## Application Connector nodes (App Connect Designer-style)

ACE v13 ships **~132 pre-built "Application Connector" nodes** that target named SaaS systems (Salesforce, ServiceNow, Jira, Slack, BambooHR, Workday, etc.). These follow a uniform pattern distinct from the standard `ComIbm*.msgnode` types - they share a single namespace family and a runtime-resolved connector code.

### Pattern

Each connector has two node variants:

| Variant | xmi:type form | Required attribute |
|---|---|---|
| **Input** (event-driven, polls or subscribes for new events) | `ComIbmApplicationConnectorInput_<code>.msgnode:FCMComposite_1` | `applicationConnectorType="<code>"` |
| **Request** (synchronous call-out - create, retrieve, update, delete) | `ComIbmApplicationConnectorRequest_<code>.msgnode:FCMComposite_1` | `applicationConnectorType="<code>"` |

Where `<code>` is the lowercase connector code from the table at the end of this section (e.g. `salesforce`, `servicenow`, `jira`).

### Mandatory companion artifacts for Request nodes

Unlike standard ACE nodes, an Application Connector Request node has more setup. Without these, the Toolkit refuses to validate the project:

1. **`schemaPrefix` attribute** on the node, of the form:
   ```
   schemaPrefix="gen/<FlowName>.<NodeName>_<ConnectorDisplay>"
   ```
   Example: `schemaPrefix="gen/OrderSync.Salesforce_Request"` on a flow named `OrderSync` with a Salesforce Request node.

2. **Two placeholder JSON-schema files** in the project's `gen/` subdirectory - they can start empty; the Toolkit auto-populates them once the connector's operation is configured:
   ```
   <project>/gen/<FlowName>.<NodeName>.request.schema.json
   <project>/gen/<FlowName>.<NodeName>.response.schema.json
   ```

3. **`policyUrl` attribute** referencing a `.policyxml` file in a separate PolicyProject in the workspace:
   ```
   policyUrl="{DiscoveryConnectorPolicyProject}:<Connector>1"
   ```
   Example: `policyUrl="{DiscoveryConnectorPolicyProject}:Salesforce1"`. The `<Connector>1` part is the name of the `.policyxml` file (without extension) inside the PolicyProject.

### Per-connector operations are NOT in this reference

Each connector restricts the valid `displayName` + `action` + `businessObject` triplets the Toolkit accepts (Salesforce: `CREATE Account`, `BULKUPDATE Lead`, etc.). The legal combinations are defined by the connector definition in ACE Toolkit and **cannot be guessed**.

When you need them:
1. Search the user's filesystem for an existing `.msgflow` using the same connector (Phase B0.5 lookup) - copy the attribute combination from a working flow.
2. If no example exists in the user's repos, ask the user to configure the node once in ACE Toolkit and share the resulting XML so the skill can adopt the pattern.

### 132-connector code lookup table

Use the **code** value as the substitution in `ComIbmApplicationConnector{Input,Request}_<code>.msgnode` and `applicationConnectorType="<code>"`. The display name is for prose, translation labels, and policy-name resolution.

Verified against the IBM `ot4i/ace-bob` skill SKILL.md (132 unique connector codes as of 2026-05).

| Display name | code |
|---|---|
| Amazon CloudWatch | `amazoncloudwatch` |
| Amazon DynamoDB | `amazondynamodb` |
| Amazon EC2 | `amazonec2` |
| Amazon EventBridge | `amazoneventbridge` |
| Amazon Kinesis | `amazonkinesis` |
| Amazon RDS | `amazonrds` |
| Amazon S3 | `amazons3` |
| Amazon SES | `amazonses` |
| Amazon SNS | `amazonsns` |
| Amazon SQS | `amazonsqs` |
| Anaplan | `anaplan` |
| Apache Pulsar | `apachepulsar` |
| Asana | `asana` |
| Astra DB | `astradb` |
| AWS Lambda | `amazonlambda` |
| BambooHR | `bamboohr` |
| Box | `box` |
| Businessmap | `businessmap` |
| Calendly | `calendly` |
| ClickSend | `clicksend` |
| CMIS | `cmis` |
| Confluence | `confluence` |
| Couchbase | `couchbase` |
| Coupa | `coupa` |
| Crystal Ball | `crystalball` |
| Databricks | `databricks` |
| DocuSign | `docusign` |
| Dropbox | `dropbox` |
| Eventbrite | `eventbrite` |
| Expensify | `expensify` |
| Factorial HR | `factorialhr` |
| Freshservice | `freshservice` |
| Front | `front` |
| GitHub | `github` |
| GitLab | `gitlab` |
| Gmail | `gmail` |
| Google Analytics | `googleanalytics4` |
| Google Calendar | `googlecalendar` |
| Google Chat | `googlechat` |
| Google Cloud BigQuery | `googlebigquery` |
| Google Cloud PubSub | `googlepubsub` |
| Google Cloud Storage | `googlecloudstorage` |
| Google Contacts | `googlecontacts` |
| Google Drive | `googledrive` |
| Google Gemini | `googlegemini` |
| Google Groups | `googlegroups` |
| Google Sheets | `googlesheet` |
| Google Tasks | `googletasks` |
| Google Translate | `googletranslate` |
| Google Universal Analytics | `googleanalytics` |
| Greenhouse | `greenhouse` |
| HubSpot CRM | `hubspotcrm` |
| HubSpot Marketing | `hubspotmarketing` |
| Hunter | `hunter` |
| IBM Aspera | `ibmaspera` |
| IBM Cloud Object Storage S3 | `ibmcoss3` |
| IBM Cloudant | `cloudantdb` |
| IBM Engineering Workflow Management | `ibmewm` |
| IBM FileNet Content Manager | `filenet` |
| IBM Food Trust | `ift` |
| IBM Maximo | `maximo` |
| IBM OpenPages with Watson | `ibmopenpages` |
| IBM Planning Analytics | `planninganalytics` |
| IBM Sterling Intelligent Promising | `ibmsterlingiv` |
| IBM Targetprocess | `apptiotargetprocess` |
| IBM Watson Discovery | `watsondiscovery` |
| IBM watsonx.ai | `ibmwatsonxai` |
| IBM zOS Connect | `zosconnect` |
| Infobip | `infobip` |
| Insightly | `insightly` |
| Jenkins | `jenkins` |
| Jira | `jira` |
| LDAP | `ldap` |
| Magento | `magento` |
| Mailchimp | `mailchimp` |
| Marketo | `marketo` |
| Microsoft Active Directory | `msad` |
| Microsoft Azure Blob storage | `azureblobstorage` |
| Microsoft Azure Cosmos DB | `azurecosmosdb` |
| Microsoft Azure DevOps | `azuredevops` |
| Microsoft Azure Event Hubs | `azureeventhub` |
| Microsoft Azure OpenAI | `azureopenai` |
| Microsoft Azure Service Bus | `azureservicebus` |
| Microsoft Dynamics 365 for Finance and Operations | `msdynamicsfando` |
| Microsoft Dynamics 365 for Sales | `msdynamicscrmrest` |
| Microsoft Entra ID | `azuread` |
| Microsoft Excel Online | `msexcel` |
| Microsoft Exchange | `msexchange` |
| Microsoft OneDrive for Business | `msonedrive` |
| Microsoft OneNote | `msonenote` |
| Microsoft Power BI | `mspowerbi` |
| Microsoft SharePoint | `mssharepoint` |
| Microsoft Teams | `msteams` |
| Microsoft To Do | `mstodo` |
| Microsoft Viva Engage | `yammer` |
| Milvus | `milvus` |
| monday.com | `mondaydotcom` |
| Oracle E-Business Suite | `oracleebs` |
| Oracle Human Capital Management | `oraclehcm` |
| Pinecone Vector Database | `pineconedb` |
| Redis | `rediscache` |
| Salesforce | `salesforce` |
| Salesforce Account Engagement | `salesforceae` |
| Salesforce Commerce Cloud Digital Data | `sfcommerceclouddata` |
| Salesforce Marketing Cloud | `salesforcemc` |
| SAP Ariba | `sapariba` |
| SAP OData | `sapodata` |
| SAP S4 HANA | `saps4hana` |
| SAP SuccessFactors | `sapsuccessfactors` |
| ServiceNow | `servicenow` |
| Shopify | `shopify` |
| Slack | `slack` |
| Snowflake | `snowflake` |
| Splunk | `splunk` |
| Square | `square` |
| SurveyMonkey | `surveymonkey` |
| The Weather Company | `ibmtwc` |
| Toggl Track | `toggltrack` |
| Trello | `trello` |
| Twilio | `twilio` |
| UKG | `kronos` |
| Vespa | `vespa` |
| WordPress | `wordpress` |
| Workday | `workday` |
| Wrike | `wrike` |
| Wufoo | `wufoo` |
| Yapily | `yapily` |
| Zendesk Service | `zendeskservice` |
| Zoho Books | `zohobooks` |
| Zoho CRM | `zohocrm` |
| Zoho Inventory | `zohoinventory` |
| Zoho Recruit | `zohorecruit` |

Notes on codes that aren't intuitive:
- **`apptiotargetprocess`** is the code for IBM Targetprocess (originally an Apptio acquisition)
- **`azuread`** is now branded **Microsoft Entra ID** (rename, same code)
- **`cloudantdb`** is the IBM Cloudant code (the older `ibmcloudant` form is not used)
- **`kronos`** is the code for UKG (Kronos is the legacy name)
- **`maximo`** vs `ibmmaximo` - only `maximo` exists in v13
- **`ibmtwc`** is The Weather Company
- **`yammer`** is now branded Microsoft Viva Engage
- **`googlebigquery`** is Google Cloud BigQuery; **`googleanalytics`** is the legacy Universal Analytics, **`googleanalytics4`** is current Google Analytics
- **`googlesheet`** is singular, not plural (`googlesheets` does NOT exist in v13)
- **`rediscache`** is the Redis code, not `redis`

When in doubt about a code, search the user's filesystem for an existing flow using the connector (Phase B0.5), or check the local Toolkit palette.

---

## Node ID Convention

Node IDs are sequential: `FCMComposite_1_1`, `FCMComposite_1_2`, `FCMComposite_1_3`, ...

```xml
<nodes xmi:type="ComIbmWSInput.msgnode:FCMComposite_1"
  xmi:id="FCMComposite_1_1"
  location="72,61"
  URLSpecifier="/orders">
  <translation xmi:type="utility:ConstantString" string="HTTP Input"/>
</nodes>
```

The `location` attribute is the visual x,y position in ACE Toolkit. Any valid coordinates work - the tool will reposition nodes when opened.

---

## Connection Wiring

Connections use `sourceTerminalName` and `targetTerminalName`. Common terminal names:

| Terminal | Direction | Meaning |
|----------|-----------|---------|
| `OutTerminal.out` | Source | Normal (success) output |
| `OutTerminal.out1`, `OutTerminal.out2`, ... | Source | Additional Compute outputs (see **Multi-terminal Compute nodes** below) |
| `OutTerminal.catch` | Source | Exception caught by this node |
| `OutTerminal.failure` | Source | Propagation failure / connection-level failure |
| `OutTerminal.error` | Source | Protocol-level error (HTTPRequest only - see below) |
| `InTerminal.in` | Target | Normal input |

```xml
<connections xmi:type="eflow:FCMConnection"
  xmi:id="FCMConnection_1"
  targetNode="FCMComposite_1_2"
  sourceNode="FCMComposite_1_1"
  sourceTerminalName="OutTerminal.out"
  targetTerminalName="InTerminal.in"/>
```

---

## Standard Error Handling Pattern

All IBM ACE v13 patterns include error handling on the catch terminal. Always add this:

1. Connect `OutTerminal.catch` (and optionally `OutTerminal.failure`) of the input node → `HandleException` Compute node
2. Connect `HandleException` Compute → terminal output (HTTP Reply, Trace node, or dead-letter queue)

```xml
<!-- Error path: catch terminal → HandleException → Reply -->
<connections xmi:type="eflow:FCMConnection" xmi:id="FCMConnection_err1"
  targetNode="FCMComposite_1_N"   <!-- HandleException node ID -->
  sourceNode="FCMComposite_1_1"   <!-- input node ID -->
  sourceTerminalName="OutTerminal.catch"
  targetTerminalName="InTerminal.in"/>
<connections xmi:type="eflow:FCMConnection" xmi:id="FCMConnection_err2"
  targetNode="FCMComposite_1_3"   <!-- reply/output node ID -->
  sourceNode="FCMComposite_1_N"   <!-- HandleException node ID -->
  sourceTerminalName="OutTerminal.out"
  targetTerminalName="InTerminal.in"/>
```

The `HandleException` ESQL module is always the same (see `XMLtoJSON_HandleException.esql` in `references/examples/XMLtoJSON/`).

---

## computeExpression Format

```
esql://routine/<SCHEMA>#<ModuleName>.Main
```

`<ModuleName>` matches `CREATE COMPUTE MODULE <ModuleName>` in the `.esql` file, and
**`<SCHEMA>` - the part between `/` and `#` - MUST equal that file's `BROKER SCHEMA` line.**
The `BROKER SCHEMA`, the file's directory, and this URI move together as one triple; if
they disagree the Toolkit throws `Incorrect schema name` *and* `Unable to locate URN`.

| `.esql` declares | file must live at | computeExpression |
|---|---|---|
| `BROKER SCHEMA OrderProcessor` | `<project>/OrderProcessor/OrderProcessor_Compute.esql` | `esql://routine/OrderProcessor#OrderProcessor_Compute.Main` |
| `BROKER SCHEMA com.acme.orders` | `<project>/com/acme/orders/OrderProcessor_Compute.esql` | `esql://routine/com.acme.orders#OrderProcessor_Compute.Main` |
| *(no `BROKER SCHEMA` - default schema)* | `<project>/OrderProcessor_Compute.esql` (root) | `esql://routine/#OrderProcessor_Compute.Main` |

**Generated flows use a dotted-package schema** (assumed from the flow's function) - e.g.
`BROKER SCHEMA com.acme.orders`, with the `.msgflow` / `.esql` / `.subflow` under
`<project>/com/acme/orders/` and URI `esql://routine/com.acme.orders#<Module>.Main`. ⚠️ The bundled
`references/examples/` use the **default-schema** form (`esql://routine/#<Module>.Main`,
ESQL at the project root). That is correct *for those examples*, but **do NOT copy the
bare `#…` form** into a generated flow that declares a `BROKER SCHEMA` - that exact mix
is the most common build failure.

---

## nsURI / nsPrefix and node-label uniqueness (Toolkit-only checks)

Neither of these fails an `ibmint` build or a runtime deploy - the engine resolves nodes
by internal id and modules by name+schema, so a flow can run perfectly while still being
wrong by these rules. They surface only when the flow is **imported into the Toolkit**,
which validates them and shows red Xs in the Problems view. Get them right so a generated
flow imports clean (don't make the user discover it).

**`nsURI` / `nsPrefix` = the `.msgflow`'s path relative to the project root.** The Toolkit
ties a flow's namespace URI to where the file physically lives - the SAME `<X>` as the
schema triple, dots→slashes, plus the filename:

| flow file at | nsURI / nsPrefix |
|---|---|
| `<project>/com/acme/orders/OrderProcessor.msgflow` | `com/acme/orders/OrderProcessor.msgflow` |
| `<project>/OrderProcessor.msgflow` (default schema, root) | `OrderProcessor.msgflow` |

A bare `nsURI="OrderProcessor.msgflow"` on a flow that lives under `com/acme/orders/`
makes the Toolkit report *"Namespace URI in flow does not match its location in the file
system. Resave the file to correct the error."* (Same trap as the bare `#…`
computeExpression: the `references/examples/` use the bare form because their flow really
is at the project root - do not copy that onto a schema-qualified flow.)

**Every node's `<translation ... string="...">` label must be unique within the flow.**
The Toolkit treats that label as the node name and rejects duplicates with *"Node name
'<x>' is not unique within the flow."* This bites on larger flows with repeated shapes -
two Compute nodes both labelled `build request`, two RCDs both `validate`. Give each a
distinguishing suffix (`build request (retry)`, `validate (inbound)`) so the label says
both what the node does AND which one it is.

---

## Complete Minimal Example: HTTP Request-Reply

(ESQL for this flow lives under `OrderProcessor/` with `BROKER SCHEMA OrderProcessor`, so
the `computeExpression` URIs are schema-qualified - see *computeExpression Format* above.)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<ecore:EPackage xmi:version="2.0"
  xmlns:xmi="http://www.omg.org/XMI"
  xmlns:ComIbmWSInput.msgnode="ComIbmWSInput.msgnode"
  xmlns:ComIbmWSReply.msgnode="ComIbmWSReply.msgnode"
  xmlns:ComIbmCompute.msgnode="ComIbmCompute.msgnode"
  xmlns:ecore="http://www.eclipse.org/emf/2002/Ecore"
  xmlns:eflow="http://www.ibm.com/wbi/2005/eflow"
  xmlns:utility="http://www.ibm.com/wbi/2005/eflow_utility"
  nsURI="OrderProcessor/OrderProcessor.msgflow"
  nsPrefix="OrderProcessor/OrderProcessor.msgflow">

  <eClassifiers xmi:type="eflow:FCMComposite" name="FCMComposite_1" nodeLayoutStyle="RECTANGLE">
    <eSuperTypes href="http://www.ibm.com/wbi/2005/eflow#//FCMBlock"/>
    <translation xmi:type="utility:TranslatableString" key="OrderProcessor" bundleName="OrderProcessor" pluginId="OrderProcessor"/>
    <colorGraphic16 xmi:type="utility:GIFFileGraphic" resourceName="platform:/plugin/OrderProcessor/icons/full/obj16/OrderProcessor.gif"/>
    <colorGraphic32 xmi:type="utility:GIFFileGraphic" resourceName="platform:/plugin/OrderProcessor/icons/full/obj30/OrderProcessor.gif"/>

    <composition>
      <nodes xmi:type="ComIbmWSInput.msgnode:FCMComposite_1" xmi:id="FCMComposite_1_1"
        location="72,61" URLSpecifier="/orders" messageDomainProperty="XMLNSC">
        <translation xmi:type="utility:ConstantString" string="HTTP Input"/>
      </nodes>
      <nodes xmi:type="ComIbmCompute.msgnode:FCMComposite_1" xmi:id="FCMComposite_1_2"
        location="258,61" computeExpression="esql://routine/OrderProcessor#OrderProcessor_Compute.Main">
        <translation xmi:type="utility:ConstantString" string="Compute"/>
      </nodes>
      <nodes xmi:type="ComIbmWSReply.msgnode:FCMComposite_1" xmi:id="FCMComposite_1_3"
        location="510,61">
        <translation xmi:type="utility:ConstantString" string="HTTP Reply"/>
      </nodes>
      <nodes xmi:type="ComIbmCompute.msgnode:FCMComposite_1" xmi:id="FCMComposite_1_4"
        location="258,130" computeExpression="esql://routine/OrderProcessor#OrderProcessor_HandleException.Main">
        <translation xmi:type="utility:ConstantString" string="HandleException"/>
      </nodes>

      <!-- Happy path: Input → Compute → Reply -->
      <connections xmi:type="eflow:FCMConnection" xmi:id="FCMConnection_1"
        targetNode="FCMComposite_1_2" sourceNode="FCMComposite_1_1"
        sourceTerminalName="OutTerminal.out" targetTerminalName="InTerminal.in"/>
      <connections xmi:type="eflow:FCMConnection" xmi:id="FCMConnection_2"
        targetNode="FCMComposite_1_3" sourceNode="FCMComposite_1_2"
        sourceTerminalName="OutTerminal.out" targetTerminalName="InTerminal.in"/>

      <!-- Error path: catch → HandleException → Reply -->
      <connections xmi:type="eflow:FCMConnection" xmi:id="FCMConnection_3"
        targetNode="FCMComposite_1_4" sourceNode="FCMComposite_1_1"
        sourceTerminalName="OutTerminal.catch" targetTerminalName="InTerminal.in"/>
      <connections xmi:type="eflow:FCMConnection" xmi:id="FCMConnection_4"
        targetNode="FCMComposite_1_3" sourceNode="FCMComposite_1_4"
        sourceTerminalName="OutTerminal.out" targetTerminalName="InTerminal.in"/>
    </composition>

    <propertyOrganizer/>
    <stickyBoard/>
  </eClassifiers>
</ecore:EPackage>
```

---

## Key Differences from Incorrect Format

The original template in this skill used wrong namespaces. Do NOT use:
- `ComIbmWSInput.msgflow:WSInputNode` ❌
- `ecore:EClass` ❌
- `<details key="nodes">` ❌

Always use:
- `ComIbmWSInput.msgnode:FCMComposite_1` ✅
- `eflow:FCMComposite` ✅
- `<nodes xmi:type="...">` directly inside `<composition>` ✅

---

## Examples Available

All files in `references/examples/` are real IBM ACE v13 templates extracted from official pattern zips (September 2024).

| Directory | Pattern | Files |
|-----------|---------|-------|
| `examples/XMLtoJSON/` | XML to JSON (Format Transformation) | `.msgflow`, `_Compute.esql`, `_HandleException.esql` |
| `examples/JSONtoXML/` | JSON to XML (Format Transformation) | `.msgflow`, `_Compute.esql`, `_HandleException.esql` |
| `examples/HTTPtoIBMMQ/` | HTTP to IBM MQ (Protocol Transformation) | `.msgflow`, `_HandleException.esql` |
| `examples/IBMMQtoHTTP/` | IBM MQ to HTTP (Protocol Transformation) | `.msgflow`, `_HandleException.esql` |
| `examples/FiletoIBMMQ/` | File to IBM MQ (Protocol Transformation) | `.msgflow`, `_HandleException.esql` |
| `examples/IBMMQtoFile/` | IBM MQ to File (Protocol Transformation) | `.msgflow`, `_HandleException.esql` |

---

## HTTPRequest (ComIbmWSRequest)

### Verified attributes

Only the attributes below are valid on `ComIbmWSRequest`. Do **not** invent attribute names - every attribute on a generated node must appear here or in `references/examples/`.

| Attribute | Required | Notes |
|---|---|---|
| `URLSpecifier` | yes | Full URL: `http://host/path` or `https://host/path` |
| `httpMethod` | recommended | `"GET"`, `"POST"`, `"PUT"`, `"DELETE"` |
| `httpVersion` | recommended | `"1.1"` |
| `protocol` | optional | `"TLS"`, `"TLSv1.2"`, `"TLSv1.3"` - observed even on plain `http://` URLs |
| `messageDomainProperty` | optional | `"BLOB"`, `"JSON"`, `"XMLNSC"`, etc. |
| `httpProxyLocation` | optional | Proxy URL |

### Three output terminals - distinct semantics

`ComIbmWSRequest` has **three** output terminals, each with a different meaning. Wiring response classification on `out` alone is wrong - HTTP error responses (4xx/5xx) never reach `out`.

| Terminal | When | Body available? |
|---|---|---|
| `OutTerminal.out` | 2xx success | Full response message |
| `OutTerminal.error` | HTTP error response (4xx/5xx) returned by the server | Response body present; status code in `HTTPResponseHeader.X-Original-HTTP-Status-Code` and `LocalEnvironment.Destination.HTTP.ReplyStatusCode` |
| `OutTerminal.failure` | Connection-level failure (refused, DNS, timeout) | No response - exception details in `InputExceptionList` |

**Correct wiring for retry-on-failure patterns:**
- `out` → success path (no classifier needed; already 2xx)
- `error` → classify-by-status (decide retry vs fatal)
- `failure` → retry directly (always retry connection-level errors; there is no status to classify)

For unified handling - wire both `error` and `failure` into one Compute, then dispatch inside ESQL on `CARDINALITY(InputExceptionList.*[]) > 0`. See `validated_rules.md` "HTTPRequest terminal semantics" and "Unify error/failure classification".

```xml
<nodes xmi:type="ComIbmWSRequest.msgnode:FCMComposite_1" xmi:id="FCMComposite_1_3"
  location="320,80"
  URLSpecifier="https://api.example.com/orders"
  httpMethod="POST"
  httpVersion="1.1"
  protocol="TLSv1.2"
  messageDomainProperty="JSON">
  <translation xmi:type="utility:ConstantString" string="POST to orders endpoint"/>
</nodes>
```

---

## Timer Nodes

`ComIbmTimeoutControl` and `ComIbmTimeoutNotification` are the timer-pair nodes used for delayed retry, scheduled redelivery, and circuit-breaker patterns.

### TimeoutControl - schedule a future event

```xml
<nodes xmi:type="ComIbmTimeoutControl.msgnode:FCMComposite_1" xmi:id="FCMComposite_1_5"
  location="240,180"
  uniqueIdentifier="RETRY01"
  requestLocation="InputLocalEnvironment.TimeoutRequest">
  <translation xmi:type="utility:ConstantString" string="Schedule retry"/>
</nodes>
```

**Attributes:**

| Attribute | Required | Notes |
|---|---|---|
| `uniqueIdentifier` | yes | 1-12 chars, alphanumeric/hex. MUST match the paired `ComIbmTimeoutNotification`'s `uniqueIdentifier` (or the wildcard `*`). |
| `requestLocation` | yes | Path to the timeout request data on the input message tree. Standard value: `InputLocalEnvironment.TimeoutRequest`. |

The upstream Compute node populates `OutputLocalEnvironment.TimeoutRequest.*` - see `workflow.md` ESQL patterns "Timeout request schema".

### TimeoutNotification - fire the scheduled event

Two operating modes:

**Automatic mode** - fires on a fixed interval. Use for periodic timers (heartbeats, polling).

```xml
<nodes xmi:type="ComIbmTimeoutNotification.msgnode:FCMComposite_1" xmi:id="FCMComposite_1_6"
  location="240,260"
  uniqueIdentifier="HEARTBEAT01"
  timeoutInterval="2">
  <translation xmi:type="utility:ConstantString" string="Fire every 2 seconds"/>
</nodes>
```

**Controlled mode** - fires when the paired `ComIbmTimeoutControl` schedules it. Use for delayed retry / scheduled redelivery.

```xml
<nodes xmi:type="ComIbmTimeoutNotification.msgnode:FCMComposite_1" xmi:id="FCMComposite_1_6"
  location="240,260"
  uniqueIdentifier="RETRY01"
  operationMode="controlled"
  transactionMode="no">
  <translation xmi:type="utility:ConstantString" string="Fire scheduled retry"/>
</nodes>
```

**Attributes:**

| Attribute | Required | Notes |
|---|---|---|
| `uniqueIdentifier` | yes | 1-12 chars. In a paired setup MUST exactly match the `ComIbmTimeoutControl`'s `uniqueIdentifier`. Wildcard `*` allowed only when intent is "fire any scheduled timer regardless of identifier". |
| `operationMode` | controlled-mode only | `"controlled"` for paired/scheduled mode; omit for Automatic mode. |
| `timeoutInterval` | Automatic mode only | Integer seconds between fires. |
| `transactionMode` | optional | `"yes"`, `"no"`, `"automatic"`. |

### Pair rule

When `ComIbmTimeoutControl` and `ComIbmTimeoutNotification` are paired:

1. Both nodes MUST declare the same literal `uniqueIdentifier` (1-12 chars, alphanumeric/hex).
2. With a shared static identifier, the upstream Compute MUST set `OutputLocalEnvironment.TimeoutRequest.AllowOverwrite = TRUE` - otherwise re-scheduling fails when a previous SET is still pending.
3. Wildcard `*` on the Notification node is technically allowed but should not be the default. Ask the user whether to use a fixed identifier (single-flight retry) or a per-message identifier with `*` wildcard (concurrent retries).

See also `validated_rules.md` "Timeout-pair identifier rule".

---

## Multi-terminal Compute nodes

`ComIbmCompute` ships with multiple output terminals built in: `OutTerminal.out`, `OutTerminal.out1`, `OutTerminal.out2`, ... You do **not** declare these in `<terminals>` - they are present by default.

**Wiring:** use `sourceTerminalName="OutTerminal.out1"` (and `.out2`, etc.) on the `<connections>` element to pick the branch.

**ESQL:** route inside `Main()` with `PROPAGATE TO TERMINAL`:

```esql
CREATE FUNCTION Main() RETURNS BOOLEAN
BEGIN
    IF /* success condition */ THEN
        PROPAGATE TO TERMINAL 'out';
    ELSEIF /* retry condition */ THEN
        PROPAGATE TO TERMINAL 'out1';
    ELSE
        PROPAGATE TO TERMINAL 'out2';   -- fatal
    END IF;
    RETURN FALSE;   -- prevent default propagation to 'out'
END;
```

Notes:
- `RETURN TRUE` propagates to `OutTerminal.out` automatically - when using explicit `PROPAGATE`, return `FALSE` to suppress the default.
- The terminal name in ESQL is bare (`'out1'`), but the wire attribute is fully qualified (`"OutTerminal.out1"`).

---

## Validate node (ComIbmValidate) - schema validation + routing

Use `ComIbmValidate` when the requirement is *"validate the incoming message against a schema / message model"* - e.g. "receives JSON, validates it, replies ok/nok". The node checks the message and routes it on two terminals, so it **is** the conditional-routing mechanism for valid/invalid - you do not need a separate Filter or a hand-written ESQL field-check Compute.

**When to use which:**
- **`ComIbmValidate`** - the decision is "does this message conform to a schema/model?" (JSON Schema, DFDL, XMLNSC, MRM, SOAP). Don't reinvent schema validation as ESQL `IS NULL` / `EXISTS` checks - the parser does standards-compliant validation for free.
- **`ComIbmFilter`** - a boolean business decision expressed in ESQL (e.g. `amount > 1000`), two paths.
- **Multi-terminal `ComIbmCompute`** - routing needs computation/enrichment alongside the decision, or 3+ paths.

### Verified attributes (from a working v13 flow)

```xml
<nodes xmi:type="ComIbmValidate.msgnode:FCMComposite_1" xmi:id="FCMComposite_1_3"
  location="312,35"
  domain="JSON" checkDomain="true"
  set="schema.json" checkSet="true"
  validateMaster="contentAndValue"
  validateFailureAction="exceptionList">
  <translation xmi:type="utility:ConstantString" string="Validate"/>
</nodes>
```

| Attribute | Example | Meaning (Toolkit label) |
|---|---|---|
| `domain` | `"JSON"` | Message domain to check (`JSON`, `XMLNSC`, `DFDL`, `MRM`, `SOAP`, …) - *Domain* |
| `checkDomain` | `"true"` | Enable the domain check - *Check domain* |
| `set` | `"schema.json"` | The schema / message model - *Message model*. For JSON this is the schema **file name** |
| `checkSet` | `"true"` | Enable the model check - *Check message model* |
| `validateMaster` | `"contentAndValue"` | *Validate* property: `none` / `content` / `contentAndValue` / `inherit`. Use `contentAndValue` for schema validation (JSON/XMLNSC/DFDL/SOAP always validate content **and** value even when set to `content`) |
| `validateFailureAction` | `"exceptionList"` | *Failure Action*: `exception` / `exceptionList` / `userTrace` / `localErrorLog`. **Must be `exception` or `exceptionList`** for failures to reach the `failure` terminal - otherwise they are only logged |

On the upstream input node, bind the same schema so the body parses against it: add `messageSetProperty="schema.json"` to the `ComIbmWSInput` (alongside `messageDomainProperty="JSON"`).

### Terminals

| Terminal | Fires when |
|---|---|
| `InTerminal.in` | message arrives |
| `OutTerminal.match` | all selected checks pass (valid) → wire to the success/ok path |
| `OutTerminal.failure` | any check fails (invalid) → wire to the error/nok path. If left unwired, an exception is thrown instead |

```xml
<!-- Input -> Validate -->
<connections xmi:type="eflow:FCMConnection" xmi:id="FCMConnection_1"
  sourceNode="FCMComposite_1_1" targetNode="FCMComposite_1_3"
  sourceTerminalName="OutTerminal.out" targetTerminalName="InTerminal.in"/>
<!-- valid -> ok compute -->
<connections xmi:type="eflow:FCMConnection" xmi:id="FCMConnection_8"
  sourceNode="FCMComposite_1_3" targetNode="FCMComposite_1_4"
  sourceTerminalName="OutTerminal.match" targetTerminalName="InTerminal.in"/>
<!-- invalid -> nok compute -->
<connections xmi:type="eflow:FCMConnection" xmi:id="FCMConnection_6"
  sourceNode="FCMComposite_1_3" targetNode="FCMComposite_1_5"
  sourceTerminalName="OutTerminal.failure" targetTerminalName="InTerminal.in"/>
```

With the Validate node owning the valid/invalid decision, a parse-failure `catch`/`HandleException` path on the input node is optional - the `failure` terminal already carries the validation outcome (and, with `exceptionList`, the detail).

### Reading validation errors on the nok path

With `validateFailureAction="exceptionList"`, the nok Compute can walk `InputExceptionList` to surface *why* validation failed. JSON validation populates this chain: `BIP2230 → BIP5902 → BIP5705 → BIP5393 → BIP5751+` (one `BIP5751` per failure; `+` = one or more sibling exceptions). Each `BIP5751` insert carries the error text, the JSON-pointer location in the message, and the matching location in the schema.

```esql
-- nok handler: pull every ParserException insert into the JSON reply.
-- NOTE: every REFERENCE is `ref`-prefixed (esql_style.md Rule 13), which also
-- keeps cursor names clear of ESQL reserved words - never name the insert
-- cursor `insert` (INSERT is reserved; the Toolkit ESQL parser rejects it as
-- an identifier, and `ibmint package` is lax and won't catch it).
CREATE PROCEDURE collectValidationErrors(IN refExceptionList REFERENCE, OUT refErrors REFERENCE)
BEGIN
    DECLARE errorIndex INTEGER 0;
    DECLARE refException REFERENCE TO refExceptionList.*[1];
    WHILE lastmove(refException) DO
        DECLARE refParserError REFERENCE TO refException.ParserException[1];
        WHILE lastmove(refParserError) DO
            DECLARE refInsert REFERENCE TO refParserError.Insert[1];
            WHILE lastmove(refInsert) DO
                SET errorIndex = errorIndex + 1;
                SET refErrors.Item[errorIndex] = refInsert.Text;
                MOVE refInsert NEXTSIBLING;
            END WHILE;
            MOVE refParserError NEXTSIBLING;
        END WHILE;
        MOVE refException LASTCHILD;
    END WHILE;
END;
```

### JSON schema file requirements (when `domain="JSON"`)

- The schema file must have a `.json` extension **and** either contain `schema` in the file name (e.g. `order.schema.json`) or declare `"$schema": "http://json-schema.org/draft-04/schema#"` on the first line.
- Supported: JSON Schema **draft-04 / draft-05**, **Swagger 2.0**, **OpenAPI 3.0.x** (the `default`, `format`, and `discriminator` keywords are ignored). Other drafts raise `BIP5754` on first use.
- Add `"additionalProperties": false` in the schema to make stray/misspelled fields fail validation.
- The schema must be deployed **inside the application** (or a referenced library) - package the `.json` alongside the flow.

---

## Trace (ComIbmTrace)

Diagnostic node that writes a templated line to one of three sinks. Common uses: ad-hoc debug logging during build/validate, central fan-in target via `PROPAGATE TO LABEL` (see `workflow.md` ESQL patterns).

### Verified attributes

| Attribute | Required | Notes |
|---|---|---|
| `destination` | yes | Enum (lowercase). `"file"` → write to `filePath`. `"localError"` → write to the integration server's system log (default for ad-hoc debug). `"userTrace"` → only emitted when user trace is enabled (`mqsichangetrace -u`). |
| `filePath` | conditional | Required when `destination="file"`. Absolute path (escape backslashes in XML: `C:\\temp\\trace.txt`). |
| `pattern` | recommended | Template string with `${X}` substitution. See "pattern syntax" below - only top-level correlation names work; deep paths fail with `BIP2432E`. |
| `traceText` | optional | Free-text prefix written before the `pattern` expansion. Used for tagging log lines (`traceText="[retry] "`). |

`destination` values are case-sensitive - `"file"`, `"localError"`, `"userTrace"`. Capitalised variants (`"File"`, `"LocalError"`) are accepted by the runtime in some versions but XSD-strict tooling will reject them.

```xml
<!-- Debug to BIP log (no filePath needed) -->
<nodes xmi:type="ComIbmTrace.msgnode:FCMComposite_1" xmi:id="FCMComposite_1_7"
  location="260,340"
  destination="localError"
  pattern="${Environment}">
  <translation xmi:type="utility:ConstantString" string="Log Trace"/>
</nodes>

<!-- File destination -->
<nodes xmi:type="ComIbmTrace.msgnode:FCMComposite_1" xmi:id="FCMComposite_1_8"
  location="200,300"
  destination="file"
  filePath="C:\\temp\\retry.log"
  pattern="${Environment}">
  <translation xmi:type="utility:ConstantString" string="Trace retry context"/>
</nodes>
```

### `pattern` syntax

The `pattern` attribute supports `${X}` substitution **only for top-level correlation names**:

`Root`, `Body`, `Properties`, `Environment`, `LocalEnvironment`, `ExceptionList`, `DestinationList`, `Context`, `CONTEXTREFERENCE`, `CONTEXTINVOCATIONNODE`.

Deep field references like `${Environment/Variables/Foo}` or `${Root.JSON.Data.X}` are **not** parsed as paths - each `/`- or `.`-separated segment is treated as a fresh correlation lookup, so the second segment fails validation:

```
BIP2432E: The correlation name 'Variables' is not valid.
```

**To trace a specific subfield:**
1. **Dump the parent** - e.g. `pattern="${Environment}"` serialises the whole Environment tree, including any `Variables.Retry.*` set upstream.
2. **Pre-stringify in a Compute** upstream of the Trace - write a single line into e.g. `Environment.Variables.TraceLine` or `Body`, then trace `${Environment}` (or `${Body}`).

```xml
<!-- Wrong - second segment fails BIP2432E -->
<!-- pattern="attempt=${Environment/Variables/Retry/Attempt}" -->
```

---

## Promoted properties - two flavours

ACE has two semantically different things both called "promoted property" that look almost identical in the `.msgflow` / `.subflow` XML. Picking the wrong flavour silently produces a property that can't be overridden at deploy.

### Flavour A - node-attribute promotion (override-able at deploy)

The promoted name is wired to a real attribute on an underlying node (e.g. `ComIbmMQOutput.queueName`, `ComIbmFileOutput.outputDirectory`). At deploy time the BAR overrides file can target the promoted name and the value propagates down to the node attribute.

```xml
<eStructuralFeatures xmi:type="ecore:EAttribute" xmi:id="Property.queueName"
    name="queueName" defaultValueLiteral="DEAD.Q">
  <eType xmi:type="ecore:EDataType" href="http://www.eclipse.org/emf/2002/Ecore#//EString"/>
</eStructuralFeatures>
<propertyOrganizer>
  <propertyDescriptor groupName="Group.MQ" configurable="true"
      describedAttribute="Property.queueName">
    <propertyName xmi:type="utility:TranslatableString" key="Property.queueName"
        bundleName="ComIbmMQOutput" pluginId="com.ibm.etools.mft.ibmnodes.definitions"/>
  </propertyDescriptor>
</propertyOrganizer>
<attributeLinks promotedAttribute="Property.queueName" overriddenNodes="FCMComposite_1_5">
  <overriddenAttribute href="ComIbmMQOutput.msgnode#Property.queueName"/>
</attributeLinks>
```

The `<attributeLinks>` block is the structural marker - it ties the promoted name to a specific node attribute on a specific node ID.

**BAR override syntax** (in a `.properties` overrides file):
```
<MsgFlowName>#<PromotedName>=<value>
ReQueue#queueName=PROD.OUTGOING.Q
```

### Flavour B - ESQL `EXTERNAL` (consumed from ESQL only)

The promoted name is not wired to a node attribute. Instead an ESQL `DECLARE ... EXTERNAL` reads the same name. The flow declares the property and the ESQL consumes it - no `<attributeLinks>` block is present.

```xml
<eStructuralFeatures xmi:type="ecore:EAttribute" xmi:id="Property.holdQueueName"
    name="holdQueueName" lowerBound="1" defaultValueLiteral="abcAEDIMQTEST.HOLDQ">
  <eType xmi:type="ecore:EDataType" href="http://www.eclipse.org/emf/2002/Ecore#//EString"/>
</eStructuralFeatures>
<propertyOrganizer>
  <propertyDescriptor groupName="Group.HoldQueue" configurable="true"
      userDefined="true" describedAttribute="Property.holdQueueName">
    <propertyName xmi:type="utility:TranslatableString" key="Property.holdQueueName"
        bundleName="ReQueue" pluginId="MQDeadLetterRescuer"/>
  </propertyDescriptor>
</propertyOrganizer>
<!-- NO attributeLinks block -->
```

```esql
DECLARE holdQueueName EXTERNAL CHARACTER '';
-- ...used inside the module...
SET OutputLocalEnvironment.Destination.MQ.DestinationData[1].queueName =
    COALESCE(InputRoot.MQDLH.DestQName, holdQueueName);
```

The `userDefined="true"` flag on the `propertyDescriptor` is the empirical marker - the property doesn't correspond to any node-supplied attribute. The flow itself owns the property.

**BAR override syntax** (different - targets the ESQL `EXTERNAL` declaration):
```
<MsgFlowName>#<EsqlModule>.<varName>=<value>
ReQueue#ToOriginalQueue.holdQueueName=PROD.HOLD.Q
```

### Picking the right flavour

| Question | Flavour |
|---|---|
| Does the value drive an attribute on an ACE-supplied node (queueName, outputDirectory, URLSpecifier, ...)? | A |
| Is the value consumed only by ESQL via `DECLARE ... EXTERNAL`? | B |
| Both - value drives a node attribute AND is read by ESQL? | A (the node attribute path), then have the ESQL read the *node's* attribute path via `Properties` / `LocalEnvironment` instead of duplicating |

**Don't write Flavour A and then also reference the same name in ESQL via `DECLARE EXTERNAL`** - pick one. They produce two independent override points that can drift.

### When generating subflows

Subflows almost always need Flavour A - they exist to expose an underlying node attribute to the parent flow (e.g. `outputFilename` on a wrapped FileOutput). When generating a subflow, default to Flavour A unless the subflow contains no node with that attribute. Refer back to the worked example in `references/examples/` for the canonical XML.
