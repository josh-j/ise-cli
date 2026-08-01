function Write-IseMemorySink {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [IseLogEvent] $Event,
        [Parameter(Mandatory)] $Sink
    )

    $Sink.Events.Add($Event)
}
