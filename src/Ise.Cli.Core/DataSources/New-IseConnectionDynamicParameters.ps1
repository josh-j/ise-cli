function New-IseConnectionDynamicParameters {
    [CmdletBinding()]
    param()

    $dictionary = [System.Management.Automation.RuntimeDefinedParameterDictionary]::new()
    foreach ($descriptor in @($script:IseDataSources.Values)) {
        if (-not $descriptor.Metadata) {
            continue
        }
        $hasConnectionParameters = if ($descriptor.Metadata -is [System.Collections.IDictionary]) {
            $descriptor.Metadata.Contains('ConnectionParameters')
        } else {
            $descriptor.Metadata.PSObject.Properties.Name -contains 'ConnectionParameters'
        }
        if (-not $hasConnectionParameters) { continue }
        foreach ($definition in @($descriptor.Metadata.ConnectionParameters)) {
            $name = [string]$definition.Name
            if ($dictionary.ContainsKey($name)) {
                throw [System.InvalidOperationException]::new(
                    "Datasource connection parameter '$name' is registered more than once."
                )
            }
            $attributes = [System.Collections.ObjectModel.Collection[System.Attribute]]::new()
            $parameterAttribute = [System.Management.Automation.ParameterAttribute]::new()
            $mandatory = if ($definition -is [System.Collections.IDictionary]) {
                $definition.Contains('Mandatory') -and [bool]$definition['Mandatory']
            } else {
                $definition.PSObject.Properties.Name -contains 'Mandatory' -and
                    [bool]$definition.Mandatory
            }
            if ($mandatory) { $parameterAttribute.Mandatory = $true }
            $attributes.Add($parameterAttribute)
            $parameterType = if ($definition.ParameterType -is [type]) {
                $definition.ParameterType
            } else { [type]::GetType([string]$definition.ParameterType, $true) }
            $dictionary.Add(
                $name,
                [System.Management.Automation.RuntimeDefinedParameter]::new(
                    $name,
                    $parameterType,
                    $attributes
                )
            )
        }
    }
    $dictionary
}
