# Architecture verification

This matrix links the architectural promises to executable evidence. A roadmap
checkbox is complete only when its evidence exists in source, contract tests,
or the staged package.

| Promise | Implementation evidence | Executable evidence |
| --- | --- | --- |
| Linux is the primary runtime | Root manifest requires PowerShell Core 7.4+; paths and temporary locations use platform APIs | `eng/Test-LinuxInstall.ps1` imports a clean staged install from outside the repository and crawls two ERS pages |
| One active connection | `IseSession` and the module-private session lifecycle in Core | `tests/Core/Connection.Tests.ps1` covers replacement, disposal, idempotent disconnect, probes, and scoped certificate bypass |
| Read-only command surface | REST transport constructs only `HttpMethod.Get`; Data Connect accepts one `SELECT` or `WITH`; pxGrid exposes reads and subscriptions | `tests/Contracts/DataSourceContract.Tests.ps1` rejects mutating REST methods and validates every capability |
| Datasources remain replaceable | Adapters register named capabilities, lifecycle hooks, operations, and connection parameters | Core has no REST, Oracle, STOMP, WebSocket, Data Connect, or pxGrid protocol branches |
| REST can crawl the available surface | ERS and Open API use live Swagger documents, bundled descriptors, and direct paths; each adapter owns pagination | REST discovery and command tests cover live-only resources, wildcard selection, pagination, raw output, partial failure, and cancellation |
| Output stays PowerShell-native | Adapters preserve source fields, add a leading type name, and attach `IseMetadata` | REST, Data Connect, pxGrid, and feature tests inspect type names, native fields, and evidence |
| Diagnostics are consistent | Core owns correlation, stable event IDs, JSON Lines sinks, exception types, and error conversion | Logging and error tests cover event shape, sink isolation, status mapping, and correlation/request IDs |
| The package is the product | `eng/Build-Module.ps1` stages one versioned aggregate module | Integration tests import the staged artifact and a fresh PowerShell process verifies type loading and exports |

The standard local gate is `./test.ps1`. On Linux it runs static analysis,
builds the artifact, executes the complete Pester suite, and then runs the
clean-install Linux smoke process. Live ISE and hosted Windows executions are
separate acceptance evidence because they require external infrastructure.
