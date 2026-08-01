function Disconnect-Ise {
    [CmdletBinding()]
    param()

    if ($null -eq $script:IseSession) { return }
    $connection = $script:IseSession
    $correlation = New-IseCorrelationContext -Command $MyInvocation.MyCommand.Name
    try { Close-IseSession -Session $connection }
    finally {
        $script:IseSession = $null
        $null = Write-IseLogEvent -Level Information -EventId 'connection.closed' `
            -Message "ISE connection closed for $($connection.ServerUri)." `
            -Correlation $correlation -Operation 'Disconnect' `
            -Target $connection.ServerUri.AbsoluteUri
        Stop-IseTrace
    }
}
