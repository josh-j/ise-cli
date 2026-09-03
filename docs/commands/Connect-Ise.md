# Connect-Ise

Creates the single active ISE connection.

```powershell
$credential = Get-Credential
Connect-Ise -Server https://ise.example.net -Credential $credential
Connect-Ise -Server https://ise.lab -Credential $credential -SkipCertificateCheck
```

The connection owns a reusable HTTP client. Connecting again disposes the
previous session. Credentials are kept only on the internal session.

During connection, the REST adapters probe lightweight ERS, Open API, and MnT
endpoints. Reachable APIs are recorded in `Get-IseConnection().Capabilities`,
and the MnT version response populates `ServerVersion` when available. A 404 or
disabled API does not prevent other API families from connecting; network,
certificate, and authentication failures are terminating structured errors.

Optional adapters are configured on the same connection:

```powershell
Connect-Ise https://ise.example.net $credential `
    -DataConnectConnectionString $oracleConnectionString `
    -PxGridControlUri https://ise.example.net:8910/pxgrid/control/ `
    -PxGridClientName ise-cli `
    -PxGridCertificatePath ./ise-cli.pfx `
    -PxGridCertificatePassword (Read-Host -AsSecureString)
```

Data Connect reuses `-Credential` by default. When the reporting database has
a different account, pass `-DataConnectCredential` to override it.

`Get-IseConnection` returns a non-secret view of the current session.
`Disconnect-Ise` closes Data Connect, pxGrid sockets, HTTP clients, and trace
sinks; it is safe to invoke repeatedly. Only one ISE deployment is active in a
PowerShell session.
