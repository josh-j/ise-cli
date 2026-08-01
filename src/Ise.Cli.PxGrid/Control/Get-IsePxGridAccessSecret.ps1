function Get-IsePxGridAccessSecret {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [IseSession] $Session,
        [Parameter(Mandatory)] [string] $PeerNodeName,
        $Correlation
    )

    Initialize-IsePxGridConnection -Session $Session -Correlation $Correlation
    $cacheKey = "PxGrid.Secret.$PeerNodeName"
    if ($Session.DatasourceState.ContainsKey($cacheKey)) {
        return [string]$Session.DatasourceState[$cacheKey]
    }
    $uri = Get-IsePxGridControlUri -Session $Session -Operation AccessSecret
    $response = Invoke-IsePxGridRequest -Session $Session -Operation AccessSecret `
        -Uri $uri -Body @{ peerNodeName = $PeerNodeName } -Target $PeerNodeName `
        -Correlation $Correlation
    if ([string]::IsNullOrWhiteSpace([string]$response.secret)) {
        throw [IsePxGridException]::new(
            "pxGrid returned no access secret for '$PeerNodeName'.",
            @{ Datasource = 'PxGrid'; Operation = 'AccessSecret'; Target = $PeerNodeName }
        )
    }
    $Session.DatasourceState[$cacheKey] = [string]$response.secret
    [string]$response.secret
}
