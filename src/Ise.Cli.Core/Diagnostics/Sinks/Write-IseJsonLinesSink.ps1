function Write-IseJsonLinesSink {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [IseLogEvent] $Event,
        [Parameter(Mandatory)] $Sink
    )

    $json = $Event | ConvertTo-Json -Depth 12 -Compress
    $Sink.Writer.WriteLine($json)
    $Sink.Writer.Flush()
}
