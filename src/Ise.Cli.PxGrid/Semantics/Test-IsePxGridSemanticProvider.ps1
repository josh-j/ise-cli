function Test-IsePxGridSemanticProvider {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [IseSession] $Session, $Provider)
    $Session.DatasourceState.ContainsKey('PxGrid.Config') -or
        $Session.DatasourceState.ContainsKey('PxGrid.Executor')
}
