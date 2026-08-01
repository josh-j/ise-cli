# Get-IseContextVisibility

`Get-IseContextVisibility` composes endpoint inventory, authentication history, active sessions, and profiling evidence from every configured semantic provider:

```powershell
Get-IseContextVisibility -MacAddress AA:BB:CC:DD:EE:FF
Get-IseContextVisibility -UserName alice
```

The normalized object includes convenient `Endpoint`, `LastAuthentication`, `CurrentSessions`, and `ProfilingAttributes` properties. It also retains `SourceData`, per-provider `Evidence`, a `Requests` summary, `Sources`, `MissingCapabilities`, and the command correlation ID. This preserves native REST, Data Connect, and pxGrid fields for troubleshooting and schema drift.

Provider failures are evidence rather than command-wide failures when another independent provider can still contribute. Inspect `Requests` and `MissingCapabilities` to distinguish no matching records from an unavailable capability.
