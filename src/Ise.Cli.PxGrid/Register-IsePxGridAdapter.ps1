function Register-IsePxGridAdapter {
    [CmdletBinding()]
    param()

    Register-IseDataSource -Descriptor ([pscustomobject]@{
        PSTypeName   = 'Ise.DataSourceDescriptor'
        Name         = 'PxGrid'
        DisplayName  = 'pxGrid 2.0'
        Capabilities = @('Discover', 'Snapshot', 'Subscribe')
        Operations   = @{
            Discover  = 'Get-IsePxGridCatalog'
            Snapshot  = 'Read-IsePxGridSnapshot'
            Subscribe = 'Watch-IsePxGridSubscription'
        }
        Configure    = 'Set-IsePxGridConfiguration'
        Open         = 'Initialize-IsePxGridConnection'
        Close        = 'Close-IsePxGridConnection'
        Metadata     = @{
            Protocol = 'pxGrid 2.0'; Stateful = $true
            ConnectionParameters = @(
                @{ Name = 'PxGridControlUri'; ParameterType = [uri] }
                @{ Name = 'PxGridClientName'; ParameterType = [string] }
                @{ Name = 'PxGridCertificatePath'; ParameterType = [string] }
                @{ Name = 'PxGridCertificatePassword'; ParameterType = [securestring] }
            )
        }
    })
}
