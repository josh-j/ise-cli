function Format-IseVerboseMessage {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [IseLogEvent] $Event)

    $identity = @(@($Event.CorrelationId, $Event.RequestId) |
        Where-Object { $_ } |
        ForEach-Object { $_.Substring(0, [math]::Min(8, $_.Length)) })
    $prefix = if ($identity.Count) { '[{0}] ' -f ($identity -join '/') } else { '' }
    '{0}{1}' -f $prefix, $Event.Message
}
