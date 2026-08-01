function Get-IseVersionFromProbe {
    [CmdletBinding()]
    param($InputObject)

    if ($null -eq $InputObject) { return $null }
    if ($InputObject -is [xml]) {
        $node = $InputObject.SelectSingleNode(
            '//*[contains(translate(local-name(), "VERSION", "version"), "version")]'
        )
        if ($node -and -not [string]::IsNullOrWhiteSpace($node.InnerText)) {
            return $node.InnerText.Trim()
        }
        return $null
    }
    foreach ($name in @('version', 'Version', 'iseVersion', 'serverVersion')) {
        $property = $InputObject.PSObject.Properties[$name]
        if ($property -and -not [string]::IsNullOrWhiteSpace([string]$property.Value)) {
            return [string]$property.Value
        }
    }
    foreach ($property in $InputObject.PSObject.Properties) {
        if ($null -eq $property.Value -or $property.Value -is [string] -or
            $property.Value.GetType().IsPrimitive) { continue }
        $nested = Get-IseVersionFromProbe -InputObject $property.Value
        if ($nested) { return $nested }
    }
    $null
}
