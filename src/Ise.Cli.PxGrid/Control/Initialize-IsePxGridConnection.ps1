function Initialize-IsePxGridConnection {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [IseSession] $Session, $Correlation)

    if (-not $Session.DatasourceState.ContainsKey('PxGrid.Config')) { return }
    if ($Session.DatasourceState.ContainsKey('PxGrid.Account')) { return }
    $config = $Session.DatasourceState['PxGrid.Config']
    $uri = Get-IsePxGridControlUri -Session $Session -Operation AccountActivate
    $response = Invoke-IsePxGridRequest -Session $Session -Operation AccountActivate `
        -Uri $uri -Body @{ account = $config.ClientName } -Target $config.ClientName `
        -Correlation $Correlation
    $state = [string]$response.accountState
    if ($state -notin @('ENABLED', 'ENABLED_BY_ADMIN')) {
        throw [IsePxGridException]::new(
            "pxGrid account '$($config.ClientName)' is '$state'; activate it in ISE and retry.",
            @{ Datasource = 'PxGrid'; Operation = 'AccountActivate'; Target = $config.ClientName
               AccountState = $state; CorrelationId = $Correlation.CorrelationId }
        )
    }
    $Session.DatasourceState['PxGrid.Account'] = $response
    $Session.Capabilities['PxGrid'] = $true
    $null = Write-IseLogEvent -Level Information -EventId 'pxgrid.account.activated' `
        -Message "pxGrid account '$($config.ClientName)' is enabled." -Correlation $Correlation `
        -Datasource PxGrid -Operation AccountActivate -Target $config.ClientName
}
