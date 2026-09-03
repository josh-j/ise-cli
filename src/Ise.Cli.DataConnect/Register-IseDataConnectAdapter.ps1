function Register-IseDataConnectAdapter {
    [CmdletBinding()]
    param()
    Register-IseDataSource -Descriptor ([pscustomobject]@{
        PSTypeName = 'Ise.DataSourceDescriptor'; Name = 'DataConnect'
        DisplayName = 'ISE Data Connect'; Capabilities = @('Discover', 'Enumerate', 'Query')
        Operations = @{ Discover = 'Get-IseDataConnectCatalog'
                        Enumerate = 'Invoke-IseDataConnectCommand'
                        Query = 'Invoke-IseDataConnectCommand' }
        Configure = 'Set-IseDataConnectConfiguration'
        Open = $null; Close = 'Close-IseDataConnectConnection'
        Metadata = @{
            Provider = 'Oracle.ManagedDataAccess.Client'
            ConnectionParameters = @(
                @{ Name = 'DataConnectConnectionString'; ParameterType = [string] }
                @{ Name = 'DataConnectCredential'; ParameterType = [pscredential]
                   DefaultFrom = 'Credential' }
                @{ Name = 'DataConnectProvider'; ParameterType = [string] }
                @{ Name = 'DataConnectAssemblyPath'; ParameterType = [string] }
            )
        }
    })
}
