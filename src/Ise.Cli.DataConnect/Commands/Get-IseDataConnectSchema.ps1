function Get-IseDataConnectSchema {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)] [string[]] $View,
        [switch] $Refresh
    )
    $correlation = New-IseCorrelationContext -Command $MyInvocation.MyCommand.Name
    try { $session = Assert-IseConnected -Correlation $correlation }
    catch { $PSCmdlet.ThrowTerminatingError((ConvertTo-IseErrorRecord -Exception $_.Exception -ErrorId 'Ise.Connection.NotConnected')) }
    try {
        $catalog = @(Get-IseDataConnectCatalog -Session $session -Refresh:$Refresh -Correlation $correlation)
        if (-not $View) { $catalog; return }
        foreach ($pattern in $View) { $catalog | Where-Object Name -Like $pattern }
    }
    catch { $PSCmdlet.ThrowTerminatingError((ConvertTo-IseErrorRecord -Exception $_.Exception `
        -Correlation $correlation)) }
}
