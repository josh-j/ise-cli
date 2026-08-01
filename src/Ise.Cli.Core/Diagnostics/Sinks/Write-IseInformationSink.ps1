function Write-IseInformationSink {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [IseLogEvent] $Event)

    $tags = [System.Collections.Generic.List[string]]::new()
    $tags.Add('Ise.Cli')
    if ($Event.EventId) { $tags.Add($Event.EventId) }
    if ($Event.Datasource) { $tags.Add($Event.Datasource) }
    Write-Information -MessageData $Event -Tags $tags.ToArray()
}
