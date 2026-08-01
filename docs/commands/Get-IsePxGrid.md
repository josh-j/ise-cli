# Get-IsePxGrid and Watch-IsePxGrid

Configure pxGrid on the active ISE session, then request snapshots or subscribe to a discovered topic:

```powershell
$pfxPassword = Read-Host 'PFX password' -AsSecureString
Connect-Ise ise.example.com (Get-Credential) `
    -PxGridClientName ise-cli `
    -PxGridCertificatePath ./ise-cli.pfx `
    -PxGridCertificatePassword $pfxPassword

Get-IsePxGrid Session
Watch-IsePxGrid Session
```

`Get-IsePxGrid` performs pxGrid control-plane account activation and service lookup, uses the advertised REST endpoint, obtains the peer access secret, and emits source-native snapshot records. With no `-Service`, it crawls every discovered service and known snapshot operation. `-Path` permits a service-specific operation not yet present in the compatibility manifest.

`Watch-IsePxGrid` connects to the advertised WebSocket endpoint using STOMP 1.2. Specify `-Topic` to override the first advertised topic. `-Reconnect` opts into reconnecting after a socket failure; disconnecting the ISE session closes every tracked socket.

The active session's `-SkipCertificateCheck` setting applies only to that session's REST and pxGrid clients. Certificate validation remains enabled by default.
