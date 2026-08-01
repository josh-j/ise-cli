function Invoke-IsePxGridSemanticProvider {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [IseSession] $Session,
        [hashtable] $Filter,
        $Correlation,
        [Parameter(Mandatory)] $Provider
    )

    $catalog = @(Get-IsePxGridCatalog -Session $Session -Correlation $Correlation)
    $descriptor = @($catalog | Where-Object Service -EQ $Provider.Metadata.Service |
        Select-Object -First 1)[0]
    if (-not $descriptor) {
        throw [IsePxGridException]::new(
            "pxGrid service '$($Provider.Metadata.Service)' was not discovered.",
            @{ Datasource = 'PxGrid'; Operation = $Provider.Capability; Target = $Provider.Metadata.Service }
        )
    }
    $records = @(Read-IsePxGridSnapshot -Session $Session -Descriptor $descriptor `
        -Path $Provider.Metadata.SnapshotPath -Correlation $Correlation)
    foreach ($record in $records) {
        if ($Filter -and $Filter.MacAddress) {
            $mac = @($record.macAddress, $record.mac, $record.MAC_ADDRESS |
                Where-Object { $_ } | Select-Object -First 1)[0]
            if ($mac -and [string]$mac -ne [string]$Filter.MacAddress) { continue }
        }
        if ($Filter -and $Filter.UserName) {
            $user = @($record.userName, $record.username, $record.USERNAME |
                Where-Object { $_ } | Select-Object -First 1)[0]
            if ($user -and [string]$user -ne [string]$Filter.UserName) { continue }
        }
        $record
    }
}
