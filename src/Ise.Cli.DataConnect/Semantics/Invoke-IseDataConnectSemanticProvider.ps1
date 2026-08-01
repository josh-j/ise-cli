function Invoke-IseDataConnectSemanticProvider {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [IseSession] $Session,
        [hashtable] $Filter,
        $Correlation,
        [Parameter(Mandatory)] $Provider
    )

    $catalog = @(Get-IseDataConnectCatalog -Session $Session -Correlation $Correlation)
    $descriptor = $null
    foreach ($candidate in @($Provider.Metadata.ViewCandidates)) {
        $descriptor = @($catalog | Where-Object Name -EQ $candidate | Select-Object -First 1)[0]
        if ($descriptor) { break }
    }
    if (-not $descriptor) {
        throw [IseDataConnectException]::new(
            "No Data Connect view for semantic capability '$($Provider.Capability)' was discovered.",
            @{ Datasource = 'DataConnect'; Operation = $Provider.Capability; Target = $Provider.Name }
        )
    }
    $sql = "SELECT * FROM $($descriptor.Owner).$($descriptor.Name)"
    $parameters = @{}
    $clauses = [System.Collections.Generic.List[string]]::new()
    $known = @($descriptor.Columns.Name)
    if ($Filter -and $Filter.MacAddress) {
        $column = @('MAC_ADDRESS', 'MACADDRESS', 'ENDPOINT_MAC_ADDRESS') |
            Where-Object { $_ -in $known } | Select-Object -First 1
        if ($column) { $clauses.Add("$column = :mac"); $parameters.mac = $Filter.MacAddress }
    }
    if ($Filter -and $Filter.UserName) {
        $column = @('USERNAME', 'USER_NAME') | Where-Object { $_ -in $known } |
            Select-Object -First 1
        if ($column) { $clauses.Add("$column = :username"); $parameters.username = $Filter.UserName }
    }
    if ($clauses.Count) { $sql += ' WHERE ' + ($clauses -join ' AND ') }
    Invoke-IseDataConnectCommand -Session $Session -Sql $sql -Parameters $parameters `
        -Operation Query -Target $descriptor.Name -Correlation $Correlation |
        Add-IseDataConnectTypeName -View $descriptor.Name -Correlation $Correlation
}
