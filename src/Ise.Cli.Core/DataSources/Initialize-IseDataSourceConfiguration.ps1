function Initialize-IseDataSourceConfiguration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [IseSession] $Session,
        [Parameter(Mandatory)] [hashtable] $BoundParameters,
        $Correlation
    )

    foreach ($descriptor in @($script:IseDataSources.Values)) {
        if (-not $descriptor.Metadata) { continue }
        $hasConnectionParameters = if ($descriptor.Metadata -is [System.Collections.IDictionary]) {
            $descriptor.Metadata.Contains('ConnectionParameters')
        } else {
            $descriptor.Metadata.PSObject.Properties.Name -contains 'ConnectionParameters'
        }
        if (-not $hasConnectionParameters) { continue }
        $definitions = @($descriptor.Metadata.ConnectionParameters)
        $arguments = @{}
        foreach ($definition in $definitions) {
            $name = [string]$definition.Name
            if ($BoundParameters.ContainsKey($name)) { $arguments[$name] = $BoundParameters[$name] }
        }
        if ($arguments.Count) {
            foreach ($definition in $definitions) {
                $name = [string]$definition.Name
                if ($arguments.ContainsKey($name)) { continue }
                $defaultFrom = if ($definition -is [System.Collections.IDictionary] -and
                    $definition.Contains('DefaultFrom')) {
                    [string]$definition['DefaultFrom']
                } elseif ($definition.PSObject.Properties.Name -contains 'DefaultFrom') {
                    [string]$definition.DefaultFrom
                }
                if ($defaultFrom -and $BoundParameters.ContainsKey($defaultFrom)) {
                    $arguments[$name] = $BoundParameters[$defaultFrom]
                }
            }
            foreach ($definition in $definitions) {
                $name = [string]$definition.Name
                if (-not $arguments.ContainsKey($name)) { continue }
                $stateKey = if ($definition -is [System.Collections.IDictionary] -and
                    $definition.Contains('SessionStateKey')) {
                    [string]$definition['SessionStateKey']
                } elseif ($definition.PSObject.Properties.Name -contains 'SessionStateKey') {
                    [string]$definition.SessionStateKey
                }
                if ($stateKey) { $Session.DatasourceState[$stateKey] = $arguments[$name] }
            }
            if ($descriptor.PSObject.Properties.Name -contains 'Configure' -and
                $descriptor.Configure) {
                & $descriptor.Configure -Session $Session -Arguments $arguments `
                    -Correlation $Correlation
            }
        }
    }
}
