function Register-IseDataConnectSemanticProviders {
    [CmdletBinding()]
    param()

    foreach ($definition in @(
        @{ Name = 'DataConnect.EndpointInventory'; Capability = 'EndpointInventory'
           Views = @('ENDPOINTS_DATA', 'ENDPOINTS'); Priority = 50 }
        @{ Name = 'DataConnect.ProfilingAttributes'; Capability = 'ProfilingAttributes'
           Views = @('ENDPOINTS_DATA', 'ENDPOINT_PROFILER_DATA'); Priority = 50 }
        @{ Name = 'DataConnect.AuthenticationHistory'; Capability = 'AuthenticationHistory'
           Views = @('RADIUS_AUTHENTICATIONS', 'RADIUS_AUTHENTICATIONS_WEEK'); Priority = 50 }
    )) {
        Register-IseSemanticProvider -Descriptor ([pscustomobject]@{
            PSTypeName = 'Ise.SemanticProviderDescriptor'
            Name = $definition.Name; Capability = $definition.Capability
            Source = 'DataConnect'; Invoke = 'Invoke-IseDataConnectSemanticProvider'
            Test = 'Test-IseDataConnectSemanticProvider'; Priority = $definition.Priority
            Metadata = @{ ViewCandidates = $definition.Views }
        })
    }
}
