# Get-IseRestSchema

Returns the resource catalog used by a REST adapter.

```powershell
Get-IseRestSchema -Ers
Get-IseRestSchema -Ers '*Group'
Get-IseRestSchema -OpenApi -Refresh
```

Descriptors identify paths, supported operations, pagination strategy, output
type, required parameters, and whether the schema came from live discovery or a
bundled manifest. ERS and Open API share the authenticated Swagger document
cache, while remaining separate adapters. `-Refresh` clears that cache and
rediscovers the currently available GET surface.
