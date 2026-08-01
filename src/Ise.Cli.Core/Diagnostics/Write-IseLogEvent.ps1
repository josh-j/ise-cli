function Write-IseLogEvent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Debug', 'Information', 'Warning', 'Error')]
        [string] $Level,
        [Parameter(Mandatory)] [string] $EventId,
        [Parameter(Mandatory)] [string] $Message,
        $Correlation,
        [string] $RequestId,
        [string] $Datasource,
        [string] $Operation,
        [string] $Target,
        [string] $Uri,
        [Nullable[int]] $Page,
        [Nullable[int]] $StatusCode,
        [Nullable[double]] $DurationMilliseconds,
        [Nullable[int]] $RecordCount,
        [System.Exception] $Exception,
        [hashtable] $Properties
    )

    $event = [IseLogEvent]::new()
    if (-not $script:IseEventIds.Contains($EventId)) {
        Write-Debug "Unregistered ISE event ID '$EventId' was emitted."
    }
    $event.Level = $Level
    $event.EventId = $EventId
    $event.Message = $Message
    if ($Correlation) {
        $event.CorrelationId = $Correlation.CorrelationId
        $event.Command = $Correlation.Command
    }
    $event.RequestId = $RequestId
    $event.Datasource = $Datasource
    $event.Operation = $Operation
    $event.Target = $Target
    $event.Uri = $Uri
    $event.Page = $Page
    $event.StatusCode = $StatusCode
    $event.DurationMilliseconds = $DurationMilliseconds
    $event.RecordCount = $RecordCount
    $event.Exception = $Exception
    if ($Properties) { $event.Properties = $Properties }

    $formatted = Format-IseVerboseMessage -Event $event
    if ($Level -eq 'Debug') { Write-Debug $formatted }
    else { Write-Verbose $formatted }
    Write-IseInformationSink -Event $event

    foreach ($sink in @($script:IseTraceSinks)) {
        if ($sink.Disabled) { continue }
        $levels = @('Debug', 'Information', 'Warning', 'Error')
        if ($levels.IndexOf($Level) -lt $levels.IndexOf($sink.Level)) { continue }
        try {
            switch ($sink.Type) {
                'JsonLines' { Write-IseJsonLinesSink -Event $event -Sink $sink }
                'Memory' { Write-IseMemorySink -Event $event -Sink $sink }
                default {
                    if (-not $sink.WriteCommand) {
                        throw "Custom trace sink '$($sink.Type)' has no write command."
                    }
                    & $sink.WriteCommand -Event $event -Sink $sink
                }
            }
        }
        catch {
            $sink.Disabled = $true
            Write-Error -ErrorId 'Ise.Logging.SinkFailed' `
                -Category WriteError `
                -TargetObject $sink `
                -Message "ISE logging sink '$($sink.Type)' failed and was disabled: $($_.Exception.Message)" `
                -ErrorAction Continue
        }
    }

    $event
}
