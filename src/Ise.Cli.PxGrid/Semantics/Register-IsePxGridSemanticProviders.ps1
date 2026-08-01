function Register-IsePxGridSemanticProviders {
    [CmdletBinding()]
    param()

    foreach ($definition in @(
        @{ Name = 'PxGrid.ActiveSessions'; Capability = 'ActiveSessions'
           Service = 'com.cisco.ise.session'; Path = 'getSessions'; Priority = 25 }
        @{ Name = 'PxGrid.EndpointInventory'; Capability = 'EndpointInventory'
           Service = 'com.cisco.endpoint.asset'; Path = 'getAssets'; Priority = 25 }
    )) {
        Register-IseSemanticProvider -Descriptor ([pscustomobject]@{
            PSTypeName = 'Ise.SemanticProviderDescriptor'
            Name = $definition.Name; Capability = $definition.Capability
            Source = 'PxGrid'; Invoke = 'Invoke-IsePxGridSemanticProvider'
            Test = 'Test-IsePxGridSemanticProvider'; Priority = $definition.Priority
            Metadata = @{ Service = $definition.Service; SnapshotPath = $definition.Path }
        })
    }
}
