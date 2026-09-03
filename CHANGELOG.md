# Changelog

## 0.1.0 - Unreleased

- Added the PowerShell module, Core runtime, and REST datasource adapters.
- Added ERS, Open API, and MnT discovery and crawling.
- Added structured JSON Lines tracing and typed PowerShell errors.
- Added source and staged-artifact validation.
- Added live-catalog Data Connect queries with source-native output.
- Reused the primary connection credential for Data Connect by default while
  retaining `-DataConnectCredential` as an override.
- Added independent ERS, MnT, Open API, and Data Connect credentials plus a
  gitignored local connection-profile workflow.
- Added pxGrid 2.0 control discovery, snapshots, STOMP subscriptions, optional
  reconnect, and deterministic session cleanup.
- Added semantic provider registration and `Get-IseContextVisibility` with
  retained per-source evidence.
- Added Linux/Windows CI, representative protocol fixtures, formatting views,
  custom trace sink extensibility, and fresh-process staged import checks.
