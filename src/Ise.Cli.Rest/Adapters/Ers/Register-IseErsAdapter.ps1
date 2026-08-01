function Register-IseErsAdapter {
    [CmdletBinding()]
    param()

    Register-IseDataSource -Descriptor ([pscustomobject]@{
        PSTypeName   = 'Ise.DataSourceDescriptor'
        Name         = 'Rest.Ers'
        DisplayName  = 'ERS REST API'
        Capabilities = @('Discover', 'Enumerate', 'GetById', 'GetPath')
        Operations   = @{
            Discover  = 'Get-IseErsCatalog'
            Enumerate = 'Read-IseErsResource'
            GetById   = 'Read-IseErsResource'
            GetPath   = 'Read-IseErsResource'
        }
        Open         = 'Open-IseErsConnection'
        Close        = $null
        Metadata     = @{ ApiRoot = '/ers' }
    })
}
