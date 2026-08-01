function Close-IseDataConnectConnection {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [IseSession] $Session)

    if (-not $Session.DatasourceState.ContainsKey('DataConnect.Connection')) { return }
    $connection = $Session.DatasourceState['DataConnect.Connection']
    try { $connection.Close() }
    finally {
        $connection.Dispose()
        $Session.DatasourceState.Remove('DataConnect.Connection')
    }
}
