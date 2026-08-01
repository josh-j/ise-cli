# Get-IseDataConnect

Configure Data Connect on the active session, inspect its live catalog, and
stream view rows or an explicit read query.

```powershell
Connect-Ise -Server https://ise.example.net -Credential $restCredential `
    -DataConnectConnectionString 'Data Source=ise-reporting' `
    -DataConnectCredential $databaseCredential

Get-IseDataConnectSchema
Get-IseDataConnect RADIUS_AUTHENTICATIONS
Get-IseDataConnect -Sql 'SELECT * FROM RADIUS_AUTHENTICATIONS WHERE USERNAME = :user' `
    -Parameter @{ user = 'alice' }
```

Omitting `-View` reads every catalog view. The CLI adds no paging, row limit,
or retry policy unless the caller supplies `-First`.
