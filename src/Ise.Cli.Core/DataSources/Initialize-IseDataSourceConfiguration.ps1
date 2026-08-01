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
            & $descriptor.Configure -Session $Session -Arguments $arguments `
                -Correlation $Correlation
        }
    }
}
