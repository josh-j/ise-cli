@{
    RootModule        = 'Ise.Cli.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = '4f571698-e6ee-4bac-a8a7-a5653620bb25'
    Author            = 'Joshua Johnson'
    Description       = 'Read-only PowerShell interface for Cisco ISE datasources.'
    PowerShellVersion = '7.4'
    CompatiblePSEditions = @('Core')
    FormatsToProcess  = @(
        'Formats/Ise.Cli.Core.format.ps1xml'
        'Formats/Ise.Cli.Rest.format.ps1xml'
        'Formats/Ise.Cli.DataConnect.format.ps1xml'
        'Formats/Ise.Cli.PxGrid.format.ps1xml'
        'Formats/Ise.Cli.Features.format.ps1xml'
    )
    FunctionsToExport = @(
        'Connect-Ise'
        'Get-IseConnection'
        'Disconnect-Ise'
        'Get-IseRest'
        'Get-IseRestSchema'
        'Get-IseDataConnect'
        'Get-IseDataConnectSchema'
        'Get-IsePxGrid'
        'Watch-IsePxGrid'
        'Get-IseContextVisibility'
        'Start-IseTrace'
        'Stop-IseTrace'
        'Get-IseTrace'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags = @('Cisco', 'ISE', 'REST', 'DataConnect', 'pxGrid', 'PowerShell')
        }
    }
}
