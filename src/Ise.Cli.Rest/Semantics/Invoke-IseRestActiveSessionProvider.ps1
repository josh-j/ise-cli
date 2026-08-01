function Invoke-IseRestActiveSessionProvider {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [IseSession] $Session,
        [hashtable] $Filter,
        $Correlation,
        $Provider
    )

    $catalog = @(Get-IseMntCatalog -Session $Session -Correlation $Correlation)
    if ($Filter -and $Filter.MacAddress) {
        $descriptor = @($catalog | Where-Object Name -EQ SessionByMac)[0]
        Invoke-IseSourceOperation -Source Rest.Mnt -Operation GetById -Arguments @{
            Descriptor = $descriptor; Id = [string]$Filter.MacAddress
        } -Correlation $Correlation
    } else {
        $descriptor = @($catalog | Where-Object Name -EQ ActiveSession)[0]
        Invoke-IseSourceOperation -Source Rest.Mnt -Operation Enumerate -Arguments @{
            Descriptor = $descriptor
        } -Correlation $Correlation
    }
}
