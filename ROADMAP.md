# ISE CLI Roadmap

Implementation status: complete. The remaining unchecked items are external
acceptance runs that require GitHub-hosted runners or an explicitly configured
ISE lab; their automated entrypoints are already present.

## Delivery checklist

### Version 1: REST foundation

- [x] Create the `Ise.Cli`, `Ise.Cli.Core`, and `Ise.Cli.Rest` module boundaries.
- [x] Implement the single active ISE connection lifecycle.
- [x] Implement the datasource registry and operation dispatcher.
- [x] Implement `Get-IseRest -Ers`, `Get-IseRest -OpenApi`, and `Get-IseRest -Mnt`.
- [x] Implement live REST schema discovery with direct-path fallback.
- [x] Implement API-specific collection unwrapping and pagination.
- [x] Stream source-native objects through the PowerShell pipeline.
- [x] Propagate downstream pipeline cancellation to active requests.
- [x] Implement structured logging, correlation, and JSON Lines tracing.
- [x] Implement typed exceptions and consistent PowerShell error records.
- [x] Add unit, contract, fixture, and optional live tests.
- [x] Record the initial architecture decisions.

### Additional datasources and features

- [x] Add the Data Connect adapter without changing Core contracts.
- [x] Add the pxGrid adapter and its stateful connection lifecycle.
- [x] Validate and expand datasource capabilities using the real adapters.
- [x] Add semantic capability providers after at least two datasources exist.
- [x] Add composed feature commands such as `Get-IseContextVisibility`.
- [x] Keep internal modules in one package because current dependencies do not justify a release split.

## Version 1 implementation specification

### Runtime and packaging

- [x] Target PowerShell 7.4 or newer in `Ise.Cli.psd1`.
- [x] Treat Linux as the primary release-blocking runtime and Windows PowerShell 7 as a compatibility target.
- [x] Avoid Windows PowerShell, desktop CLR, registry, WinRM, and fixed platform-path dependencies.
- [x] Keep v1 implemented in PowerShell; use .NET runtime types from PowerShell where connection pooling or cancellation requires them.
- [x] Publish one `Ise.Cli` package containing the Core and REST nested modules.
- [x] Export only the approved public commands from the root manifest.
- [x] Load Core before datasource modules so adapters can register during module import.
- [x] Dispose the active connection and logging sinks from the module's `OnRemove` handler.

The initial REST surface was:

```powershell
Connect-Ise
Get-IseConnection
Disconnect-Ise
Get-IseRest
Get-IseRestSchema
Start-IseTrace
Stop-IseTrace
Get-IseTrace
```

The completed aggregate package also exports `Get-IseDataConnect`,
`Get-IseDataConnectSchema`, `Get-IsePxGrid`, `Watch-IsePxGrid`, and
`Get-IseContextVisibility`.

The aggregate module layout should be:

```text
src/
├── Ise.Cli/
│   ├── Ise.Cli.psd1
│   └── Ise.Cli.psm1
├── Ise.Cli.Core/
│   ├── Ise.Cli.Core.psm1
│   ├── Types/
│   ├── Connection/
│   ├── DataSources/
│   ├── Dispatch/
│   ├── Diagnostics/
│   ├── Errors/
│   └── Semantics/
├── Ise.Cli.Rest/
│   ├── Commands/
│   ├── Client/
│   ├── Discovery/
│   ├── Output/
│   ├── Semantics/
│   └── Adapters/
│       ├── Ers/
│       ├── OpenApi/
│       └── Mnt/
├── Ise.Cli.DataConnect/
├── Ise.Cli.PxGrid/
└── Ise.Cli.Features/
```

The build should stage these under one installable version directory:

```text
out/Ise.Cli/<version>/
├── Ise.Cli.psd1
├── Ise.Cli.psm1
├── Core/
├── Rest/
├── DataConnect/
├── PxGrid/
├── Features/
├── Formats/
└── schemas/
```

### Active connection implementation

- [x] Store one active session in a module-private `$script:IseSession` variable.
- [x] Represent the session with a typed `IseSession` object.
- [x] Construct one `System.Net.Http.HttpClient` per session and reuse it for every REST request.
- [x] Construct a dedicated `HttpClientHandler` for credentials and per-connection certificate behavior.
- [x] Dispose the old session before replacing it with a new connection.
- [x] Reject datasource commands when no active connection exists.

`IseSession` should contain:

```text
ServerUri
Credential
SkipCertificateCheck
HttpClient
ConnectedAt
ConnectionId
ServerVersion
Capabilities
DatasourceState
```

`Connect-Ise` should use this parameter contract:

```powershell
Connect-Ise
    -Server <uri>
    -Credential <pscredential>
    [-SkipCertificateCheck]
    [-TimeoutSec <int>]
```

Optional Data Connect parameters supply a connection string, credential,
provider invariant name, and assembly path. Optional pxGrid parameters supply
the control URI, client name, client-certificate path, and certificate
password. They configure independently owned datasource state on the same
active `IseSession`.

Implementation flow:

1. Normalize `-Server` to an absolute HTTPS URI without a trailing slash.
2. Create a session-scoped HTTP handler.
3. Apply certificate bypass only to that handler when requested.
4. Configure the authentication required by the REST APIs.
5. Create the reusable `HttpClient` and its default timeout.
6. Probe lightweight API roots and version information.
7. Store detected capabilities without requiring every API to be available.
8. Publish `connection.opened` or throw a terminating connection error.
9. Return the new connection object.

`Disconnect-Ise` should call every datasource lifecycle close hook, dispose the HTTP client and handlers, clear the session, and remain idempotent.

### Datasource registration contract

- [x] Implement a module-private `Register-IseDataSource` command.
- [x] Store descriptors in a case-insensitive registry keyed by datasource name.
- [x] Validate descriptors at registration time.
- [x] Prevent duplicate names unless an explicit replacement mechanism is added later.
- [x] Expose registry contents to tests without making mutation public.

Each descriptor should contain:

```text
Name              Rest.Ers
DisplayName       ERS REST API
Capabilities      Discover, Enumerate, GetById, GetPath
Operations        command names keyed by capability
Open              optional lifecycle command
Close             optional lifecycle command
Metadata          adapter-specific static metadata
```

Operations should be registered as command names rather than copied scriptblocks. This keeps module ownership visible, works with compiled commands later, and allows contract tests to verify that an advertised operation resolves.

`Invoke-IseSourceOperation` should:

1. Resolve the datasource descriptor.
2. Verify the requested capability is advertised.
3. Create or inherit the command correlation context.
4. Log `source.operation.started`.
5. Invoke the registered operation with the active `IseSession` and native arguments.
6. Stream results without collecting them in Core.
7. Translate known exceptions into `ErrorRecord` objects.
8. Log completion or failure in `finally`.
9. Allow `PipelineStoppedException` to unwind without conversion to an ISE failure.

### `Get-IseRest` command contract

- [x] Implement mutually exclusive `-Ers`, `-OpenApi`, and `-Mnt` parameter sets.
- [x] Make `-Resource` position zero so `Get-IseRest -Ers Endpoint` works.
- [x] Treat an omitted resource as all enumerable resources in that API's catalog.
- [x] Follow every page by default.
- [x] Stream individual resource objects by default.
- [x] Return the untouched response envelope with `-Raw`.
- [x] Allow direct relative paths without requiring a catalog entry.

Proposed syntax:

```powershell
Get-IseRest
    (-Ers | -OpenApi | -Mnt)
    [[-Resource] <string[]>]
    [-Id <string>]
    [-Path <string>]
    [-Query <hashtable>]
    [-Headers <hashtable>]
    [-PageSize <int>]
    [-First <int>]
    [-Raw]
```

Parameter rules:

- `-Ers`, `-OpenApi`, and `-Mnt` are mandatory and mutually exclusive.
- `-Resource` accepts exact names and wildcards from the selected catalog.
- `-Id` requires exactly one resource and selects its detail operation.
- `-Path` bypasses resource-name resolution but still uses the selected API adapter and active connection.
- `-Query` supports scalar and array values; arrays become repeated query parameters.
- `-Headers` adds request headers but cannot replace session authentication state.
- `-PageSize` is passed through using the adapter's native pagination parameter.
- `-First` stops after emitting the requested number of objects; zero or omission means no client limit.
- `-Raw` emits one response envelope per HTTP response and does not unwrap collection items.

Execution flow for an API crawl:

1. Resolve the selected API adapter.
2. Load its resource catalog.
3. Match `-Resource`, or select all descriptors marked `CanEnumerate` when omitted.
4. Invoke resources sequentially in catalog order in v1.
5. For each resource, construct the first request from its descriptor and caller query.
6. Send the request through the shared REST client.
7. Extract and emit items immediately.
8. Resolve the next-page request through the adapter's pagination strategy.
9. Continue until no next page exists, `-First` is satisfied, or the downstream pipeline stops.
10. On a resource-local failure, write a non-terminating error and continue unless `-ErrorAction Stop` is active.

Sequential resource traversal is the initial behavior because it produces deterministic output and logs. Parallel traversal can be added later without changing adapter contracts if actual use demonstrates a need.

### Resource catalogs and schema discovery

- [x] Implement a resource descriptor model shared by REST adapters.
- [x] Record whether each descriptor came from live discovery, a bundled manifest, or caller-supplied path information.
- [x] Prefer live schema information when available.
- [x] Merge bundled metadata only where live discovery is missing information.
- [x] Preserve direct `-Path` access for anything absent from both sources.

A resource descriptor should contain:

```text
Api
Name
CollectionPath
DetailPathTemplate
CanEnumerate
CanGetById
PaginationStrategy
CollectionEnvelope
ItemTypeName
SchemaSource
RequiredParameters
```

Catalog provider order:

1. Live API discovery.
2. Bundled, versioned resource manifest.
3. Explicit caller path.

Open API discovery should use the authenticated Swagger resource index and group documents. ERS and MnT should use live discovery where the appliance exposes usable metadata and bundled manifests where it does not. `Get-IseRestSchema` should expose the resulting descriptors and clearly report their `SchemaSource`.

Bundled manifests are compatibility data, not code. Add a new manifest or fixture for a newly observed ISE version rather than scattering version checks through commands.

### REST client implementation

- [x] Centralize all HTTP calls in `Send-IseRestRequest`.
- [x] Resolve relative paths against the active server URI.
- [x] Encode query keys and values independently.
- [x] Support repeated query parameters.
- [x] Attach request IDs and correlation IDs to diagnostics.
- [x] Parse JSON based on content type while preserving text or bytes for non-JSON responses.
- [x] Capture response status, headers, body, and timing before translating failures.
- [x] Never write response objects directly from the HTTP layer; return a transport response to the owning adapter.

The internal transport response should contain:

```text
RequestUri
StatusCode
Headers
ContentType
BodyText
BodyBytes
BodyObject
DurationMilliseconds
RequestId
```

The HTTP layer should not know about ERS envelopes, Open API schemas, MnT payload shapes, or pagination. Those belong to adapters.

Authentication headers and credentials must be omitted from logs. Caller-supplied headers should be logged by name, with values available only through explicit diagnostic body/header capture if that capability is added later.

### Pagination implementations

- [x] Define pagination as an adapter-owned strategy.
- [x] Make each strategy return both the current items and the next request.
- [x] Treat a missing next link or exhausted total as normal completion.
- [x] Detect a repeated next URI and raise `IsePaginationException` rather than loop forever.
- [x] Preserve objects already emitted when a later page fails.

Each strategy implements the logical operations:

```text
ExtractItems(response, resourceDescriptor)
GetNextRequest(response, resourceDescriptor, currentRequest)
```

Initial strategies:

- ERS search-result envelope and `_links.next.href` traversal.
- Open API page/size/total or link traversal, selected by resource descriptor.
- Single-response resources with no pagination.
- Manifest-defined pagination for MnT endpoints that support it.

Pipeline behavior is implemented by emitting each item inside the page loop. Do not catch `PipelineStoppedException`; this allows commands such as `Select-Object -First 10` to stop subsequent requests naturally.

### Source-native output implementation

- [x] Emit `PSCustomObject` instances created from the source payload.
- [x] Insert a source-specific type name at the front of `PSTypeNames`.
- [x] Add provenance through a reserved adapted property set without renaming source fields.
- [x] Keep formatting definitions separate from the data transformation path.
- [x] Ensure `ConvertTo-Json` and `Export-Csv` receive the source properties.

Type-name examples:

```text
Ise.Rest.Ers.Endpoint
Ise.Rest.OpenApi.DeploymentNode
Ise.Rest.Mnt.ActiveSession
Ise.Rest.Unknown
```

Common provenance should be exposed through a reserved `IseMetadata` property containing `Datasource`, `Resource`, `RequestUri`, `RetrievedAt`, and `CorrelationId`. If the source already contains `IseMetadata`, preserve it and attach the CLI metadata through the PowerShell extended type system instead of overwriting it.

### Logging implementation

- [x] Implement one `Write-IseLogEvent` entry point.
- [x] Define stable event names in one Core file.
- [x] Create one correlation context per public command invocation.
- [x] Create one request ID per protocol request.
- [x] Send human-readable lifecycle messages to `Verbose` and protocol details to `Debug`.
- [x] Send structured event objects through the Information stream.
- [x] Add an optional JSON Lines sink managed by `Start-IseTrace` and `Stop-IseTrace`.
- [x] Flush and dispose file sinks during `Stop-IseTrace`, `Disconnect-Ise`, and module removal.

`Write-IseLogEvent` should accept:

```text
Level
EventId
Message
CorrelationId
RequestId
Datasource
Operation
Target
Properties
Exception
```

It should construct the timestamp and common fields once, emit the structured object to the Information stream with tags such as `Ise.Cli`, `Rest.Ers`, and `rest.page.completed`, then forward the same object to registered sinks.

`Start-IseTrace` syntax:

```powershell
Start-IseTrace
    -Path <string>
    [-Level <Debug|Information|Warning|Error>]
```

The file format is UTF-8 JSON Lines with one complete event per line. A sink failure produces a separate logging error and disables that sink; it must not replace or hide the datasource operation's result or exception.

### Exception implementation

- [x] Define `IseException` and its initial subclasses in Core before command files load.
- [x] Preserve the original exception as `InnerException` whenever translating.
- [x] Store structured failure context on every ISE exception.
- [x] Convert exceptions to `ErrorRecord` objects only at the dispatcher or public-command boundary.
- [x] Use stable fully qualified error IDs independent of exception messages.

Initial classes:

```text
IseException
IseConnectionException
IseAuthenticationException
IseCertificateException
IseHttpException
IseDiscoveryException
IsePaginationException
IseSerializationException
```

`IseException.Context` should carry:

```text
Datasource
Operation
Target
Uri
StatusCode
ResponseHeaders
ResponseBody
CorrelationId
RequestId
Page
```

Error conversion rules:

| Condition | Fully qualified error ID | Category | Behavior |
| --- | --- | --- | --- |
| No active connection | `Ise.Connection.NotConnected` | `ConnectionError` | Terminating |
| Authentication failure | `Ise.Rest.AuthenticationFailed` | `AuthenticationError` | Terminating |
| Certificate failure | `Ise.Rest.CertificateValidationFailed` | `SecurityError` | Terminating |
| Explicit resource 404 | `Ise.Rest.ResourceNotFound` | `ObjectNotFound` | Terminating |
| Resource failure in full crawl | `Ise.Rest.ResourceFailed` | Status-dependent | Non-terminating |
| Invalid JSON | `Ise.Rest.Response.InvalidJson` | `ParserError` | Resource-local |
| Repeated next link | `Ise.Rest.Pagination.Cycle` | `InvalidData` | Resource-local |
| Timeout | `Ise.Rest.RequestTimeout` | `OperationTimeout` | Status-dependent |

Public commands should use `$PSCmdlet.ThrowTerminatingError()` for command-blocking failures and `$PSCmdlet.WriteError()` for resource-local crawl failures. PowerShell then provides `-ErrorAction`, `-ErrorVariable`, and normal `try`/`catch` behavior without a parallel error policy.

### Testing implementation

- [x] Use Pester 5 for unit, contract, command, and fixture tests.
- [x] Run module-import tests in fresh PowerShell processes when validating type definitions.
- [x] Provide an in-process fake HTTP server for pagination and error tests.
- [x] Keep live ISE tests opt-in and selected by environment configuration.
- [x] Test both source layout and the staged installable module.
- [x] Validate a clean Linux installation from outside the repository through normal `PSModulePath` discovery.
- [x] Provide a cross-platform user-scoped install helper with an explicit destination override.
- [x] Maintain an architecture verification matrix linking promises to executable evidence.

Test ownership:

```text
tests/
├── Core/
│   ├── Connection.Tests.ps1
│   ├── Registry.Tests.ps1
│   ├── Dispatch.Tests.ps1
│   ├── Logging.Tests.ps1
│   └── Errors.Tests.ps1
├── Contracts/
│   └── DataSourceContract.Tests.ps1
├── Rest/
│   ├── Get-IseRest.Tests.ps1
│   ├── RestClient.Tests.ps1
│   ├── Discovery.Tests.ps1
│   ├── ErsPagination.Tests.ps1
│   ├── OpenApiPagination.Tests.ps1
│   └── Mnt.Tests.ps1
├── Fixtures/
│   └── <version-and-api-response fixtures>
└── Live/
    └── Rest.Live.Tests.ps1
```

Minimum contract scenarios:

- [x] Importing the module exports only approved commands.
- [x] Connecting twice disposes the first session.
- [x] Disconnecting twice succeeds.
- [x] Certificate bypass is scoped to one session handler.
- [x] Every registered datasource advertises resolvable operations.
- [x] `Get-IseRest -Ers Endpoint` streams all fixture pages in order.
- [x] `Get-IseRest -Ers` continues after one resource-level failure.
- [x] `-ErrorAction Stop` terminates that same crawl.
- [x] `-Raw` returns envelopes rather than unwrapped items.
- [x] Repeated query parameters are encoded correctly.
- [x] A repeated next link terminates with a pagination error.
- [x] Pipeline cancellation prevents later page requests.
- [x] Unknown response fields survive unchanged.
- [x] All page events share a command correlation ID and have unique request IDs.
- [x] JSON Lines events deserialize independently.
- [x] Logging failure does not replace an HTTP failure.
- [x] No exported command can perform a mutating REST operation.

### Build and validation

- [x] Add `build.ps1` to stage the installable module without editing source files.
- [x] Add `test.ps1` to run static analysis, unit tests, contract tests, staged-module tests, and the Linux clean-install smoke test.
- [x] Add PSScriptAnalyzer with repository-owned settings.
- [x] Validate the module manifest and exported-command list during every test run.
- [x] Run source, staged-package, fresh-process, and clean-install validation on Linux.
- [ ] Run the configured compatibility workflow on GitHub-hosted Windows after the project has a GitHub repository.
- [x] Publish test results and the staged module as CI artifacts.

The normal local validation sequence should be:

```powershell
./build.ps1
./test.ps1
Import-Module ./out/Ise.Cli/<version>/Ise.Cli.psd1 -Force
Get-Command -Module Ise.Cli
```

### Implementation order and completion gates

#### Phase 1: module and Core

- [x] Create manifests, loaders, Core types, and the active connection.
- [x] Implement registry, dispatcher, basic logging, and error conversion.
- [x] Pass Core unit tests and staged-module import tests.

Completion gate: the staged module connects to a fake server, exposes only approved commands, produces a correlated log event, and returns a structured connection error.

#### Phase 2: one ERS vertical slice

- [x] Register `Rest.Ers`.
- [x] Implement the HTTP transport response and ERS resource descriptor.
- [x] Implement one collection envelope, pagination, and source-native typing.
- [x] Implement `Get-IseRest -Ers Endpoint` against fixtures and a fake server.

Completion gate: the command streams a multi-page endpoint collection, stops on downstream cancellation, and preserves unknown fields.

#### Phase 3: complete REST crawling

- [x] Add ERS catalog traversal.
- [x] Add Open API discovery and adapter behavior.
- [x] Add MnT manifest and adapter behavior.
- [x] Add direct paths, raw responses, query parameters, `-First`, and `-PageSize`.

Completion gate: `Get-IseRest -Ers`, `-OpenApi`, and `-Mnt` work through their distinct adapters without protocol branches in Core.

#### Phase 4: production diagnostics

- [x] Complete stable event IDs and structured event fields.
- [x] Complete JSON Lines tracing and sink lifecycle.
- [x] Complete exception taxonomy and error-category mapping.
- [x] Verify partial crawl, `-ErrorAction`, and sink-failure behavior.

Completion gate: every request and error can be traced from command correlation ID to request ID, with no logging events entering the success pipeline.

#### Phase 5: release readiness

- [x] Capture representative ISE REST fixtures.
- [ ] Run optional live tests after an ISE lab is explicitly configured through `ISE_TEST_*` environment variables.
- [x] Document every public command and error contract.
- [x] Classify Windows execution as compatibility evidence rather than a Linux release gate.

Completion gate: the staged artifact passes the full test suite and can crawl each available REST family on the live lab without code changes.

## Project architecture

A modular monolith with capability-based datasource adapters is the best fit: one PowerShell product, strong internal boundaries, and no attempt to force REST, Data Connect, and pxGrid into the same transport model.

### Recommended architecture

```text
                      Ise.Cli
                         │
              PowerShell command surface
                         │
                Operation dispatcher
                         │
              Datasource registry
              ┌──────────┼───────────┐
              ▼          ▼           ▼
            REST    Data Connect    pxGrid
           adapter     adapter      adapter
              │          │           │
       ERS/OpenAPI/MnT  Oracle   Control + pubsub

Feature commands
        │
        └──── compose datasource operations through the registry
```

The dependency rule should be:

```text
Commands → Core contracts ← Datasource adapters
Features → Core contracts
```

Core never imports REST, Data Connect, pxGrid, or feature logic directly.

### One repository, independently bounded modules

Use one repository and one distributable `Ise.Cli` package, with independently bounded source modules composed into one shared aggregate module scope:

```text
ise-cli/
├── src/
│   ├── Ise.Cli/
│   │   ├── Ise.Cli.psd1
│   │   └── Ise.Cli.psm1
│   │
│   ├── Ise.Cli.Core/
│   │   ├── Connection/
│   │   ├── DataSources/
│   │   ├── Dispatch/
│   │   ├── Diagnostics/
│   │   └── Errors/
│   │
│   ├── Ise.Cli.Rest/
│   │   ├── Commands/
│   │   │   ├── Get-IseRest.ps1
│   │   │   └── Get-IseRestSchema.ps1
│   │   ├── Ers/
│   │   ├── OpenApi/
│   │   ├── Mnt/
│   │   ├── Discovery/
│   │   └── Pagination/
│   │
│   ├── Ise.Cli.DataConnect/
│   ├── Ise.Cli.PxGrid/
│   └── Ise.Cli.Features/
│
├── tests/
│   ├── Core/
│   ├── Contracts/
│   ├── Rest/
│   ├── DataConnect/
│   ├── PxGrid/
│   ├── Features/
│   ├── Fixtures/
│   └── Live/
│
├── schemas/
├── docs/
│   ├── architecture/
│   ├── decisions/
│   └── commands/
└── build/
```

Do not publish each internal module separately in v1. The boundaries should exist in code and tests first; packaging can split later if Data Connect or pxGrid introduces heavy dependencies.

### Core responsibilities

`Ise.Cli.Core` should remain small and protocol-independent:

- [x] Implement the active ISE connection.
- [x] Implement datasource registration.
- [x] Implement operation dispatch.
- [x] Implement structured diagnostic events.
- [x] Implement shared error records.
- [x] Implement pipeline cancellation.
- [x] Implement module lifecycle and cleanup.

It should not contain:

- Pagination rules
- REST envelope parsing
- SQL generation
- pxGrid subscriptions
- Cisco resource names
- Normalized endpoint/session models
- Rate limiting or safety policy

This prevents the core from becoming a miscellaneous dependency bucket.

### Datasource contract

Avoid creating one giant interface that assumes every datasource behaves like REST. Use a minimal registration contract plus declared capabilities.

A datasource registers:

```text
Name
Capabilities
Operations
Connection requirements
Lifecycle hooks
```

Example capabilities:

| Source | Capabilities |
| --- | --- |
| REST | Discover, Enumerate, GetById |
| Data Connect | Discover, Query |
| pxGrid | Discover, Snapshot, Subscribe |
| Future log source | Search, Stream |

Adapters only implement capabilities that make sense. `pxGrid` should not pretend its subscription is pagination, and Data Connect should not pretend a reporting view is a REST resource.

The registry prevents future code like:

```powershell
if ($Source -eq 'Rest') { ... }
elseif ($Source -eq 'DataConnect') { ... }
elseif ($Source -eq 'PxGrid') { ... }
```

Adding a datasource should mean adding a module and registering it—not editing core dispatch branches.

### Datasource-native commands

Each datasource gets commands matching its real semantics:

```powershell
Get-IseRest -Ers
Get-IseRest -OpenApi
Get-IseRest -Mnt

Get-IseDataConnect
Get-IseDataConnectSchema

Get-IsePxGrid
Watch-IsePxGrid
```

There does not need to be a premature universal `Get-IseData`. The shared architecture is beneath the command surface; users should not have to learn a vague abstraction that hides meaningful protocol differences.

### Preserve source-native data

Adapters should emit the data they actually received:

```text
Ise.Rest.Ers.Endpoint
Ise.DataConnect.RadiusAuthentications
Ise.PxGrid.Session
```

They may:

- [x] Add source-specific `PSTypeNames`.
- [x] Attach source metadata without discarding native fields.
- [x] Provide default formatting independently of the data objects.
- [x] Unwrap transport envelopes inside the owning adapter.
- [x] Stream collection members instead of buffering complete results.

They should not rename or discard source fields.

This matters because ISE schemas vary between releases and deployments. Unknown fields should pass through automatically, and missing fields should remain missing rather than breaking a rigid universal model.

### Discovery before hard-coding

Each adapter owns live discovery:

- [x] Make REST read available Swagger/OpenAPI information when present.
- [x] Make ERS support direct path access when schema discovery is incomplete.
- [x] Make Data Connect inspect its live catalog, views, and columns.
- [x] Make pxGrid perform service discovery and use advertised service endpoints.

Captured schemas remain valuable as fixtures and documentation, but they should not be treated as universal runtime truth.

### One dispatch point, no policy engine

All adapter operations should pass through one internal dispatcher:

```text
Invoke-IseSourceOperation
```

In v1 it only:

- [x] Resolve the registered datasource.
- [x] Supply the active connection.
- [x] Invoke the requested operation.
- [x] Emit verbose diagnostics.
- [x] Preserve errors and their original context.
- [x] Propagate pipeline cancellation.

It should not initially add retries, pacing, budgets, caching, or concurrency rules. If experience later proves one necessary, it can be added at this single boundary without rewriting every adapter.

### Feature commands

Abstract commands belong in `Ise.Cli.Features`, not inside adapters.

For example, `Get-IseContextVisibility` could request:

```text
Endpoint inventory       → REST ERS
Last authentication      → REST MnT or Data Connect
Current session          → pxGrid
Profiling attributes     → whichever source exposes them
```

The feature command:

- [x] Select contributing capabilities.
- [x] Perform the required series of reads.
- [x] Join results without placing transport logic in the feature.
- [x] Produce a normalized feature object.
- [x] Retain the source evidence used to produce it.

It never opens HTTP connections, constructs SQL, or manages pxGrid subscriptions itself.

Adapters register semantic capabilities such as:

```text
EndpointInventory
AuthenticationHistory
ActiveSessions
ProfilingAttributes
```

A feature requests a capability instead of hard-coding a datasource. The semantic-provider layer was added only after REST, Data Connect, and pxGrid existed, so its contracts were derived from real adapters rather than guesses.

### pxGrid owns its lifecycle

pxGrid is isolated because it is stateful:

- [x] Implement account activation.
- [x] Implement service discovery.
- [x] Implement certificate and hostname handling.
- [x] Implement the initial session snapshot.
- [x] Implement WebSocket/STOMP subscription.
- [x] Implement reconnection.
- [x] Implement subscription cleanup.

The active `IseSession` can own disposable datasource sessions. `Disconnect-Ise` asks every active adapter to close itself. REST will have little to close; pxGrid may have threads, sockets, and subscriptions.

### Testing strategy

The architecture becomes durable through contract tests:

- [x] Verify every adapter registers a valid descriptor.
- [x] Verify advertised operations exist.
- [x] Verify results stream rather than buffer.
- [x] Verify pipeline cancellation reaches the adapter.
- [x] Verify errors preserve source, operation, target, status, and response detail.
- [x] Verify closing the ISE connection closes active adapters.
- [x] Verify unknown source fields survive unchanged.

Then maintain adapter-specific fixtures:

```text
tests/Fixtures/
├── ise-3.2/
├── ise-3.3-p11/
├── ers/
├── openapi/
├── mnt/
├── dataconnect/
└── pxgrid/
```

Live tests should be optional and configuration-driven. Fixture tests cover known drift; live discovery catches new drift.

### How change stays localized

| Change | Expected impact |
| --- | --- |
| New ERS pagination shape | REST/ERS adapter only |
| New OpenAPI group | Usually discovery only |
| Data Connect column drift | Data Connect adapter and fixture |
| pxGrid reconnect behavior | pxGrid adapter only |
| New datasource | New module plus registration |
| New composed workflow | Features module only |
| New output formatting | Relevant format definition |
| Future retry or tracing behavior | Dispatcher only |

### Architecture decisions worth recording

Create short decision records for:

- [x] PowerShell is the primary interface.
- [x] The product is read-only.
- [x] Only one active ISE connection is supported initially.
- [x] Datasource-native objects are preserved.
- [x] Datasources register capabilities rather than inherit one universal model.
- [x] REST is the only v1 datasource.
- [x] No client-side operational safety policy exists in v1.
- [x] Abstract feature commands wait until multiple datasources justify them.

The key is a stable extension seam, not a generalized framework. Version 1 established Core plus REST; the subsequently implemented Data Connect and pxGrid adapters validated and expanded the capability contract, and only then justified semantic providers and composed features.

## Logging and exception handling

Logging and exception handling should be first-class Core subsystems, not utilities added independently by each datasource.

### Updated architecture

```text
PowerShell commands
        │
        ▼
Operation dispatcher
   │           │
   ▼           ▼
Logging     Exception normalization
   │           │
   └─────┬─────┘
         ▼
Datasource registry
   ┌─────┼──────────┐
   ▼     ▼          ▼
 REST  DataConnect  pxGrid
```

Every datasource operation crosses the same dispatch boundary. That provides consistent logging, correlation, timing, cancellation, and error behavior without embedding policy in each adapter.

### Structured logging

Internally, logs should be structured event objects rather than formatted strings.

- [x] Define one structured log-event contract in Core.
- [x] Assign stable event IDs independent of human-readable messages.
- [x] Give each public command a correlation ID.
- [x] Give each datasource request a request ID.
- [x] Carry correlation and request IDs into exceptions and error records.

Each event should support:

```text
Timestamp
Level
EventId
CorrelationId
RequestId
Command
Datasource
Operation
Target
Uri
Page
StatusCode
DurationMilliseconds
RecordCount
Message
Exception
Properties
```

Example JSON Lines event:

```json
{
  "timestamp": "2026-08-01T12:34:56.123Z",
  "level": "Information",
  "event_id": "rest.page.completed",
  "correlation_id": "80ca24b1",
  "request_id": "req-17",
  "command": "Get-IseRest",
  "datasource": "Rest.Ers",
  "operation": "Enumerate",
  "target": "Endpoint",
  "page": 4,
  "status_code": 200,
  "duration_ms": 318,
  "record_count": 100
}
```

Event IDs should be stable. Human-readable messages may improve over time without breaking log searches.

Useful event families:

```text
connection.opening
connection.opened
connection.failed
command.started
command.completed
command.failed
source.operation.started
source.operation.completed
source.operation.failed
rest.request.started
rest.request.completed
rest.page.completed
rest.pagination.completed
rest.resource.failed
schema.discovery.completed
pipeline.cancelled
```

### PowerShell streams

Logging must not contaminate the success pipeline.

| Content | PowerShell stream |
| --- | --- |
| Resource objects | Success/output |
| Request lifecycle | Verbose |
| Detailed protocol diagnostics | Debug |
| Structured log events | Information |
| Recoverable resource failures | Error, non-terminating |
| Command-blocking failures | Error, terminating |
| Deprecation or unusual state | Warning |

No `Write-Host` in library code.

Examples:

```powershell
Get-IseRest -Ers -Verbose
Get-IseRest -Ers -Debug
```

`-Verbose` might show:

```text
VERBOSE: [80ca24b1] ERS Endpoint page 4: 100 records in 318 ms
```

The underlying structured event still carries all fields.

### Persistent logging

Provide an optional file sink:

```powershell
Start-IseTrace -Path ./ise-cli.jsonl -Level Information

Get-IseRest -Ers

Stop-IseTrace
```

Recommended sinks:

- [x] Implement the always-available PowerShell stream sink.
- [x] Implement the opt-in JSON Lines file sink.
- [x] Implement an in-memory test sink.
- [x] Leave a registration seam for custom sinks.

JSON Lines is preferable to a formatted text log because it can be searched with PowerShell, `jq`, Loki, or other tooling.

Environment variables can configure non-interactive use:

```text
ISE_CLI_LOG_PATH
ISE_CLI_LOG_LEVEL
ISE_CLI_LOG_FORMAT
```

A logging sink failure must never replace the underlying ISE exception. If file logging fails, preserve the source operation and report the logging failure separately.

### Correlation

Each public command invocation receives one correlation ID. Every API request, page, discovery request, and exception under it carries that ID.

For a complete crawl:

```text
Command correlation: 80ca24b1
├── ERS schema request: req-1
├── Endpoint page 1: req-2
├── Endpoint page 2: req-3
├── NetworkDevice page 1: req-4
└── IdentityGroup failure: req-5
```

This becomes particularly important when a future feature command consults REST, Data Connect, and pxGrid during one invocation.

### Exception taxonomy

Use typed exceptions with a common base:

```text
IseException
├── IseConnectionException
├── IseAuthenticationException
├── IseCertificateException
├── IseHttpException
├── IseDiscoveryException
├── IsePaginationException
├── IseSerializationException
├── IseDataConnectException
└── IsePxGridException
```

All exceptions should carry structured context:

```text
Datasource
Operation
Target
Uri
StatusCode
ResponseHeaders
ResponseBody
CorrelationId
RequestId
Page
InnerException
```

Do not reduce an HTTP failure to `"request failed"` or discard the original exception.

### PowerShell error records

Exceptions must become proper `ErrorRecord` instances with:

- [x] Assign a stable `FullyQualifiedErrorId`.
- [x] Assign the appropriate `ErrorCategory`.
- [x] Attach a structured `TargetObject`.
- [x] Preserve the original exception as `InnerException`.
- [x] Produce a concise, actionable message.

Examples:

```text
Ise.Rest.AuthenticationFailed
Ise.Rest.CertificateValidationFailed
Ise.Rest.Http.404
Ise.Rest.Pagination.InvalidNextLink
Ise.Rest.Response.InvalidJson
Ise.Connection.Unavailable
```

Suggested category mapping:

| Failure | Error category |
| --- | --- |
| 401 | `AuthenticationError` |
| 403 | `PermissionDenied` |
| 404 | `ObjectNotFound` |
| Invalid query | `InvalidArgument` |
| TLS failure | `SecurityError` |
| Connection failure | `ConnectionError` |
| Invalid JSON/schema | `ParserError` |
| Timeout | `OperationTimeout` |

Scripts can then handle errors reliably:

```powershell
try {
    Get-IseRest -Ers Endpoint -ErrorAction Stop
}
catch {
    $_.FullyQualifiedErrorId
    $_.CategoryInfo.Category
    $_.TargetObject.StatusCode
    $_.TargetObject.ResponseBody
    $_.TargetObject.CorrelationId
}
```

### Terminating versus non-terminating

Follow normal PowerShell semantics.

Terminating errors:

- Cannot connect to ISE
- Authentication fails
- Connection certificate fails
- Requested API is unavailable
- Explicit single-resource request fails
- Command arguments are invalid

Non-terminating errors during a broad crawl:

- One resource is inaccessible
- One independently crawlable collection fails
- One discovered route has an unsupported response
- One resource cannot be deserialized

A broad crawl should continue with the next independent resource. The caller can choose fail-fast behavior:

```powershell
Get-IseRest -Ers -ErrorAction Continue
Get-IseRest -Ers -ErrorAction Stop
```

If page 4 of a collection fails, that collection stops because pages 5 onward cannot be located reliably. Previously emitted objects remain in the pipeline, and the crawl proceeds to the next resource unless `-ErrorAction Stop` is active.

Pipeline cancellation, such as `Select-Object -First 10`, is a normal completion path—not an exception.

### Catching rules

Code should catch an exception only when it can:

- Add datasource or request context
- Translate a known protocol failure
- Convert it into a correct PowerShell error record
- Perform lifecycle cleanup

Never use empty catches or replace an exception with a context-free string.

Adapters create source-specific exceptions. The dispatcher adds command-level context and converts them into consistent PowerShell errors.

### Source layout

```text
src/Ise.Cli.Core/
├── Dispatch/
│   └── Invoke-IseSourceOperation.ps1
├── Diagnostics/
│   ├── New-IseLogEvent.ps1
│   ├── Write-IseLogEvent.ps1
│   ├── Correlation.ps1
│   └── Sinks/
│       ├── PowerShellStream.ps1
│       └── JsonLines.ps1
└── Errors/
    ├── New-IseException.ps1
    ├── New-IseErrorRecord.ps1
    ├── ConvertTo-IseErrorRecord.ps1
    └── ErrorCategories.ps1
```

Logging and exception tests should:

- [x] Verify all required event fields.
- [x] Verify correlation across pages and datasource operations.
- [x] Verify exception and inner-exception preservation.
- [x] Verify `-ErrorAction Continue` and `-ErrorAction Stop` behavior.
- [x] Verify partial crawl results survive later failures.
- [x] Verify pipeline cancellation is not reported as an error.
- [x] Verify logging-sink failures do not replace datasource failures.

This gives the project one observable execution path: every future REST request, Data Connect query, pxGrid subscription, and composed feature operation produces the same quality of diagnostics and errors.
