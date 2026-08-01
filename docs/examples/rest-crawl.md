# REST crawl examples

```powershell
Connect-Ise -Server https://ise.example.net -Credential (Get-Credential)

Get-IseRest -Ers |
    Where-Object name -Like '*phone*' |
    Export-Csv ./ise-ers.csv -NoTypeInformation

Get-IseRest -OpenApi -Verbose |
    ConvertTo-Json -Depth 20 |
    Set-Content ./ise-openapi.json

Get-IseRest -Mnt ActiveSession |
    Select-Object user_name, calling_station_id

Disconnect-Ise
```
