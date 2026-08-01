function Get-IsePxGridControlUri {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [IseSession] $Session,
        [Parameter(Mandatory)] [string] $Operation
    )

    $config = $Session.DatasourceState['PxGrid.Config']
    $baseUri = if ($config.ControlUri) {
        [uri]$config.ControlUri
    } else {
        [uri]::new("https://$($Session.ServerUri.DnsSafeHost):8910/pxgrid/control/")
    }
    $baseText = $baseUri.AbsoluteUri.TrimEnd('/') + '/'
    [uri]::new([uri]$baseText, $Operation)
}
