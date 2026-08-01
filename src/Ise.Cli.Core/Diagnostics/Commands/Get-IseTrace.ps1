function Get-IseTrace {
    [CmdletBinding()]
    param()

    $correlation = New-IseCorrelationContext -Command $MyInvocation.MyCommand.Name
    $count = 0
    $null = Write-IseLogEvent -Level Debug -EventId 'command.started' `
        -Message 'Trace inspection started.' -Correlation $correlation `
        -Operation Inspect -Target TraceSinks
    try {
        foreach ($sink in $script:IseTraceSinks) {
            [pscustomobject]@{
                PSTypeName = 'Ise.TraceConfiguration'
                Type       = $sink.Type
                Path       = $sink.Path
                Level      = $sink.Level
                Disabled   = $sink.Disabled
            }
            $count++
        }
    }
    finally {
        $null = Write-IseLogEvent -Level Debug -EventId 'command.completed' `
            -Message 'Trace inspection completed.' -Correlation $correlation `
            -Operation Inspect -Target TraceSinks -RecordCount $count
    }
}
