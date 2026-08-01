function Register-IseMntAdapter {
    [CmdletBinding()]
    param()
    Register-IseDataSource -Descriptor ([pscustomobject]@{
        PSTypeName = 'Ise.DataSourceDescriptor'; Name = 'Rest.Mnt'
        DisplayName = 'Monitoring and Troubleshooting REST API'
        Capabilities = @('Discover', 'Enumerate', 'GetById', 'GetPath')
        Operations = @{ Discover = 'Get-IseMntCatalog'; Enumerate = 'Read-IseMntResource'
                        GetById = 'Read-IseMntResource'; GetPath = 'Read-IseMntResource' }
        Open = 'Open-IseMntConnection'; Close = $null; Metadata = @{ ApiRoot = '/admin/API/mnt' }
    })
}
