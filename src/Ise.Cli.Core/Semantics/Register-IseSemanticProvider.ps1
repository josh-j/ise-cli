function Register-IseSemanticProvider {
    [CmdletBinding()]
    param([Parameter(Mandatory)] $Descriptor)

    $null = Test-IseSemanticProviderDescriptor -Descriptor $Descriptor
    if ($script:IseSemanticProviders.ContainsKey([string]$Descriptor.Name)) {
        throw [System.ArgumentException]::new(
            "Semantic provider '$($Descriptor.Name)' is already registered."
        )
    }
    $script:IseSemanticProviders.Add([string]$Descriptor.Name, $Descriptor)
}
