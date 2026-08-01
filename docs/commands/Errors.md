# Errors

ISE CLI uses typed exceptions and PowerShell `ErrorRecord` objects. Error IDs
are stable independently of message wording.

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

Connection, authentication, certificate, serialization, pagination, and HTTP
failures retain their inner exception and structured request context.
