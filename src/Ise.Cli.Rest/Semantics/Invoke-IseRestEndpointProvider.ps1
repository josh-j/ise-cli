function Invoke-IseRestEndpointProvider {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [IseSession] $Session,
        [hashtable] $Filter,
        $Correlation,
        $Provider
    )

    $descriptor = @(Get-IseErsCatalog -Session $Session -Correlation $Correlation |
        Where-Object Name -EQ Endpoint | Select-Object -First 1)[0]
    $query = @{}
    if ($Filter -and $Filter.MacAddress) { $query.filter = "mac.EQ.$($Filter.MacAddress)" }
    Invoke-IseSourceOperation -Source Rest.Ers -Operation Enumerate -Arguments @{
        Descriptor = $descriptor; Query = $query
    } -Correlation $Correlation
}
