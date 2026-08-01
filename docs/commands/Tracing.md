# Tracing

ISE CLI emits structured events without contaminating the success pipeline.

```powershell
Get-IseRest -Ers -Verbose
Start-IseTrace -Path ./ise-cli.jsonl -Level Debug
Get-IseRest -Ers Endpoint
Stop-IseTrace
```

JSON Lines events carry stable event IDs, command correlation IDs, request IDs,
datasource, operation, target, status, timing, and record counts.

For non-interactive use, `ISE_CLI_LOG_PATH` starts a trace during module import,
`ISE_CLI_LOG_LEVEL` selects the minimum level, and `ISE_CLI_LOG_FORMAT` accepts
`JsonLines`. Core also has an internal command-based sink registration seam so
future packages can add sinks without changing datasource code.
