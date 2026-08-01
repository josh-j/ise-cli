function Register-IseRestSemanticProviders {
    [CmdletBinding()]
    param()

    foreach ($definition in @(
        @{ Name = 'Rest.Ers.EndpointInventory'; Capability = 'EndpointInventory'
           Source = 'Rest.Ers'; Invoke = 'Invoke-IseRestEndpointProvider'; Priority = 100 }
        @{ Name = 'Rest.Ers.ProfilingAttributes'; Capability = 'ProfilingAttributes'
           Source = 'Rest.Ers'; Invoke = 'Invoke-IseRestEndpointProvider'; Priority = 100 }
        @{ Name = 'Rest.Mnt.ActiveSessions'; Capability = 'ActiveSessions'
           Source = 'Rest.Mnt'; Invoke = 'Invoke-IseRestActiveSessionProvider'; Priority = 100 }
    )) {
        Register-IseSemanticProvider -Descriptor ([pscustomobject]@{
            PSTypeName = 'Ise.SemanticProviderDescriptor'
            Name = $definition.Name; Capability = $definition.Capability
            Source = $definition.Source; Invoke = $definition.Invoke
            Test = 'Test-IseRestSemanticProvider'; Priority = $definition.Priority
            Metadata = @{}
        })
    }
}
