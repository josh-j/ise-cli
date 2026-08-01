function Test-IseDataConnectSemanticProvider {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [IseSession] $Session, $Provider)
    $Session.DatasourceState.ContainsKey('DataConnect.Config') -or
        $Session.DatasourceState.ContainsKey('DataConnect.Executor')
}
