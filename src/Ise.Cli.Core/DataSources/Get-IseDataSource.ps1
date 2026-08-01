function Get-IseDataSource {
    [CmdletBinding()]
    param([string] $Name)

    if (-not $Name) { return @($script:IseDataSources.Values) }
    if (-not $script:IseDataSources.ContainsKey($Name)) {
        throw [System.ArgumentException]::new("Datasource '$Name' is not registered.")
    }
    $script:IseDataSources[$Name]
}
