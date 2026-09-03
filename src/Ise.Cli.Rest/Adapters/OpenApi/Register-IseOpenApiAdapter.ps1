function Register-IseOpenApiAdapter {
    [CmdletBinding()]
    param()
    Register-IseDataSource -Descriptor ([pscustomobject]@{
        PSTypeName = 'Ise.DataSourceDescriptor'; Name = 'Rest.OpenApi'
        DisplayName = 'ISE Open API'; Capabilities = @('Discover', 'Enumerate', 'GetById', 'GetPath')
        Operations = @{ Discover = 'Get-IseOpenApiCatalog'; Enumerate = 'Read-IseOpenApiResource'
                        GetById = 'Read-IseOpenApiResource'; GetPath = 'Read-IseOpenApiResource' }
        Open = 'Open-IseOpenApiConnection'; Close = $null
        Metadata = @{
            ApiRoot = '/api/v1'
            ConnectionParameters = @(
                @{ Name = 'OpenApiCredential'; ParameterType = [pscredential]
                   SessionStateKey = 'Credential.Rest.OpenApi' }
            )
        }
    })
}
