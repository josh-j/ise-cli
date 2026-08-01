function Get-IseConnection {
    [CmdletBinding()]
    param()

    $correlation = New-IseCorrelationContext -Command $MyInvocation.MyCommand.Name
    $found = $false
    $null = Write-IseLogEvent -Level Debug -EventId 'command.started' `
        -Message 'Connection inspection started.' -Correlation $correlation `
        -Operation Inspect -Target IseSession
    try {
        if ($null -eq $script:IseSession -or $script:IseSession.Disposed) { return }
        $found = $true
        [pscustomobject]@{
            PSTypeName           = 'Ise.Connection'
            Server               = $script:IseSession.ServerUri
            ConnectedAt          = $script:IseSession.ConnectedAt
            ConnectionId         = $script:IseSession.ConnectionId
            ServerVersion        = $script:IseSession.ServerVersion
            SkipCertificateCheck = $script:IseSession.SkipCertificateCheck
            Capabilities         = $script:IseSession.Capabilities.Clone()
        }
    }
    finally {
        $null = Write-IseLogEvent -Level Debug -EventId 'command.completed' `
            -Message 'Connection inspection completed.' -Correlation $correlation `
            -Operation Inspect -Target IseSession -RecordCount $(if ($found) { 1 } else { 0 })
    }
}
