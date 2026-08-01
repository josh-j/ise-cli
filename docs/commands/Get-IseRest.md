# Get-IseRest

Reads and crawls one ISE REST family.

```powershell
Get-IseRest -Ers
Get-IseRest -Ers Endpoint
Get-IseRest -Ers Endpoint -Id $id
Get-IseRest -OpenApi ListDeploymentNodes
Get-IseRest -Mnt ActiveSession
Get-IseRest -Ers -Path /config/endpoint
```

Collections follow every page by default and emit items as pages arrive.
`-First` stops after a caller-selected number, `-PageSize` selects the
server page size, and `-Raw` returns response envelopes.

A full API crawl reports resource-local failures as non-terminating errors and
continues. Use `-ErrorAction Stop` for fail-fast behavior.
