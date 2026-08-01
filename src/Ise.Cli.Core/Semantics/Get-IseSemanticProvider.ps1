function Get-IseSemanticProvider {
    [CmdletBinding()]
    param([string] $Capability)

    $providers = @($script:IseSemanticProviders.Values)
    if ($Capability) { $providers = @($providers | Where-Object Capability -EQ $Capability) }
    $providers | Sort-Object Priority, Name
}
