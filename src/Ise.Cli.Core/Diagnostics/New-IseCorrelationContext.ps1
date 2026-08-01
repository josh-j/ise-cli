function New-IseCorrelationContext {
    [CmdletBinding()]
    param(
        [string] $Command,
        [string] $CorrelationId
    )

    [pscustomobject]@{
        PSTypeName    = 'Ise.CorrelationContext'
        CorrelationId = if ($CorrelationId) { $CorrelationId } else { [guid]::NewGuid().ToString('N') }
        Command       = $Command
        StartedAt     = [datetime]::UtcNow
    }
}
