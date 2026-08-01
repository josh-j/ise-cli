# ISE CLI

A read-only, PowerShell-native interface for Cisco ISE datasources.

Linux with PowerShell 7.4 or newer is the primary supported runtime. The module
does not require Windows PowerShell, the Windows desktop runtime, or a
Windows-specific installation path. The normal test command includes a
clean-install Linux smoke test that discovers the built module by name through
`PSModulePath`, runs from outside the repository, and crawls a paginated ERS
resource. Windows PowerShell 7 is maintained as a compatibility target in CI.

## Quick start

Build and install into the first user-scoped directory in `PSModulePath`:

```powershell
./eng/Install-IseCli.ps1
Import-Module Ise.Cli
```

Use `-Force` to replace the same installed version or `-DestinationRoot` to
select a custom module root. Installation and use are the same from `pwsh` on
Linux and Windows.

```powershell
Connect-Ise -Server https://ise.example.net -Credential (Get-Credential)
Get-IseRest -Ers Endpoint
Disconnect-Ise
```

The same active session can expose the optional Data Connect and pxGrid
adapters when their connection settings are supplied:

```powershell
Connect-Ise https://ise.example.net (Get-Credential) `
    -DataConnectConnectionString $oracleConnectionString `
    -PxGridClientName ise-cli -PxGridCertificatePath ./ise-cli.pfx

Get-IseDataConnect ENDPOINTS_DATA
Get-IsePxGrid Session
Get-IseContextVisibility -MacAddress AA:BB:CC:DD:EE:FF
```

All commands are read-only. REST calls are always GET requests, Data Connect
accepts only a single `SELECT`/`WITH` statement, and pxGrid exposes snapshots
and subscriptions without mutation operations.

See [ROADMAP.md](ROADMAP.md) for the implementation plan, [architecture](docs/architecture/overview.md) for module boundaries, and [commands](docs/commands/) for usage.

## Development validation

```powershell
Install-PSResource Pester, PSScriptAnalyzer -Scope CurrentUser
./test.ps1
```

The installable module is staged under `out/Ise.Cli/<version>`.

Live REST acceptance is deliberately opt-in:

```powershell
$env:ISE_TEST_SERVER = 'https://ise.example.net'
$env:ISE_TEST_USERNAME = 'readonly-api-user'
$env:ISE_TEST_PASSWORD = '<secret>'
$env:ISE_TEST_SKIP_CERTIFICATE_CHECK = '1' # only when the lab requires it
./eng/Test-Live.ps1
```

The live harness requires ERS, proves that Open API descriptors came from live
Swagger when Open API is available, and exercises MnT when the deployment
advertises it.
