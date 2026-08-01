function Test-IseRestSemanticProvider {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [IseSession] $Session, $Provider)
    if ($Session.DatasourceState.ContainsKey('Semantic.DisabledSources')) {
        return $Provider.Source -notin @($Session.DatasourceState['Semantic.DisabledSources'])
    }
    -not $Session.Disposed
}
