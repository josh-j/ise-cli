function Initialize-IseDataSourceConfiguration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [IseSession] $Session,
        [Parameter(Mandatory)] [hashtable] $BoundParameters,
        $Correlation
    )

    foreach ($descriptor in @($script:IseDataSources.Values)) {
        if ($descriptor.PSObject.Properties.Name -notcontains 'Configure' -or
            -not $descriptor.Configure) { continue }
        $arguments = @{}
        foreach ($definition in @($descriptor.Metadata.ConnectionParameters)) {
            $name = [string]$definition.Name
            if ($BoundParameters.ContainsKey($name)) { $arguments[$name] = $BoundParameters[$name] }
        }
        if ($arguments.Count) {
            foreach ($definition in @($descriptor.Metadata.ConnectionParameters)) {
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
            & $descriptor.Configure -Session $Session -Arguments $arguments `
                -Correlation $Correlation
        }
    }
}
