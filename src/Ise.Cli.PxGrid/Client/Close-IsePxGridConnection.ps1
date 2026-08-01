function Close-IsePxGridConnection {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [IseSession] $Session)

    if ($Session.DatasourceState.ContainsKey('PxGrid.WebSockets')) {
        foreach ($socket in @($Session.DatasourceState['PxGrid.WebSockets'])) {
            try { $socket.Abort() } catch { Write-Debug "Could not abort pxGrid socket: $($_.Exception.Message)" }
            try { $socket.Dispose() } catch { Write-Debug "Could not dispose pxGrid socket: $($_.Exception.Message)" }
        }
        $Session.DatasourceState.Remove('PxGrid.WebSockets')
    }
    if ($Session.DatasourceState.ContainsKey('PxGrid.HttpClient')) {
        $Session.DatasourceState['PxGrid.HttpClient'].Dispose()
        $Session.DatasourceState.Remove('PxGrid.HttpClient')
    }
    if ($Session.DatasourceState.ContainsKey('PxGrid.Certificate')) {
        $Session.DatasourceState['PxGrid.Certificate'].Dispose()
        $Session.DatasourceState.Remove('PxGrid.Certificate')
    }
    foreach ($key in @($Session.DatasourceState.Keys | Where-Object { $_ -like 'PxGrid.Secret.*' })) {
        $Session.DatasourceState.Remove($key)
    }
    $Session.DatasourceState.Remove('PxGrid.Account')
    $Session.DatasourceState.Remove('PxGrid.Catalog')
}
