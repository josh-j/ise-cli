function Assert-IseConnected {
    [CmdletBinding()]
    param($Correlation)

    if ($null -eq $script:IseSession -or $script:IseSession.Disposed) {
        throw [IseConnectionException]::new(
            'No active ISE connection. Run Connect-Ise first.',
            @{ Operation = 'Connect'; Target = 'IseSession'
               CorrelationId = if ($Correlation) { $Correlation.CorrelationId } else { $null } }
        )
    }
    $script:IseSession
}
