# Get-IseDataConnect

Configure Data Connect on the active session, inspect its live catalog, and
stream view rows or an explicit read query.

```powershell
Connect-Ise -Server https://ise.example.net -Credential $credential `
    -DataConnectConnectionString 'Data Source=ise-reporting'

Get-IseDataConnectSchema
Get-IseDataConnect RADIUS_AUTHENTICATIONS
Get-IseDataConnect -Sql 'SELECT * FROM RADIUS_AUTHENTICATIONS WHERE USERNAME = :user' `
    -Parameter @{ user = 'alice' }
```

Data Connect reuses the connection's `-Credential`. Supply
`-DataConnectCredential $databaseCredential` only when the database account is
different.

Omitting `-View` reads every catalog view. The CLI adds no paging, row limit,
or retry policy unless the caller supplies `-First`.
