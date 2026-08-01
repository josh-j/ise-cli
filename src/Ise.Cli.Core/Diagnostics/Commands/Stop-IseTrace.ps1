function Stop-IseTrace {
    [CmdletBinding()]
    param()

    $correlation = New-IseCorrelationContext -Command $MyInvocation.MyCommand.Name
    $count = $script:IseTraceSinks.Count
    $null = Write-IseLogEvent -Level Debug -EventId 'command.started' `
        -Message 'Stopping trace sinks.' -Correlation $correlation `
        -Operation Close -Target TraceSinks
    foreach ($sink in @($script:IseTraceSinks)) {
        try {
            if ($sink.PSObject.Properties.Name -contains 'CloseCommand' -and $sink.CloseCommand) {
                & $sink.CloseCommand -Sink $sink
            }
            if ($sink.PSObject.Properties.Name -contains 'Writer' -and $sink.Writer) {
                if (-not $sink.Disabled) { $sink.Writer.Flush() }
                $sink.Writer.Dispose()
            }
        }
        catch {
            Write-Error -ErrorId 'Ise.Logging.SinkCloseFailed' `
                -Category CloseError -TargetObject $sink -Message $_.Exception.Message
        }
    }
    $script:IseTraceSinks.Clear()
    $null = Write-IseLogEvent -Level Information -EventId 'command.completed' `
        -Message "Stopped $count trace sinks." -Correlation $correlation `
        -Operation Close -Target TraceSinks -RecordCount $count
}
