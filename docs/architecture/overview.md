# Architecture

ISE CLI is a PowerShell-first modular monolith. The aggregate `Ise.Cli` module
loads Core before datasource adapters and exports only the public command
surface.

Linux is the release-blocking runtime. The implementation targets PowerShell
7.4+ and cross-platform .NET APIs, resolves paths with `Join-Path`, uses the
platform path separator for module discovery, and creates temporary files under
the runtime-provided temporary directory. It has no dependency on Windows
PowerShell, the desktop CLR, the registry, WinRM, or Windows certificate-store
paths. Windows PowerShell 7 remains a compatibility target rather than the
architectural baseline.

The aggregate loader deliberately composes internal source modules into one
PowerShell module scope. That gives every adapter the same private session,
registry, semantic providers, and trace sinks while retaining directory,
manifest, test, and staged-artifact boundaries. Internal manifests export
nothing; only `Ise.Cli.psd1` is a supported import surface.

Core owns the active session, datasource registry, operation dispatch,
structured diagnostics, and error normalization. It contains no REST paths,
pagination rules, SQL, or pxGrid protocol behavior.

Datasource adapters register capabilities and operation command names. REST v1
registers `Rest.Ers`, `Rest.OpenApi`, and `Rest.Mnt`. The independently bounded
`DataConnect` adapter discovers Oracle reporting views and columns. The
stateful `PxGrid` adapter owns account activation, service lookup, access
secrets, snapshot requests, WebSocket/STOMP subscriptions, reconnect behavior,
and cleanup. Results remain source-native and are decorated only with
PowerShell type names and `IseMetadata`.

Every datasource operation crosses `Invoke-IseSourceOperation`, giving all
present and future protocols common correlation, logging, cancellation, and
exception behavior without forcing them into one transport abstraction.

After the real adapters established the capability seam, they register semantic
providers for endpoint inventory, authentication history, active sessions, and
profiling attributes. `Ise.Cli.Features` depends only on that provider contract.
`Get-IseContextVisibility` composes normalized convenience properties while
retaining every source-native record and provider outcome as evidence.

The repository produces one installable package. Its staged hierarchy is:

```text
Ise.Cli/<version>/
├── Core/
├── Rest/
├── DataConnect/
├── PxGrid/
├── Features/
├── Formats/
└── schemas/
```

These internal package boundaries can split later if dependency weight or
release cadence justifies it; no separate publication is needed now.

See [architecture verification](verification.md) for the source and executable
evidence behind these boundaries.
