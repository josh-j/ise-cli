function Start-IseTrace {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Path,
        [ValidateSet('Debug', 'Information', 'Warning', 'Error')]
        [string] $Level = 'Information'
    )

    $correlation = New-IseCorrelationContext -Command $MyInvocation.MyCommand.Name
    $null = Write-IseLogEvent -Level Debug -EventId 'command.started' `
        -Message "Starting JSON Lines trace at '$Path'." -Correlation $correlation `
        -Operation Open -Target $Path
    $resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    $parent = Split-Path -Parent $resolved
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        $null = New-Item -ItemType Directory -Path $parent -Force
    }
    $stream = [System.IO.FileStream]::new(
        $resolved,
        [System.IO.FileMode]::Append,
        [System.IO.FileAccess]::Write,
        [System.IO.FileShare]::Read
    )
    $writer = [System.IO.StreamWriter]::new(
        $stream,
        [System.Text.UTF8Encoding]::new($false)
    )
    $sink = [pscustomobject]@{
        PSTypeName = 'Ise.TraceSink'
        Type       = 'JsonLines'
        Path       = $resolved
        Level      = $Level
        Writer     = $writer
        Disabled   = $false
    }
    $script:IseTraceSinks.Add($sink)
    $null = Write-IseLogEvent -Level Information -EventId 'command.completed' `
        -Message "JSON Lines trace started at '$resolved'." -Correlation $correlation `
        -Operation Open -Target $resolved -RecordCount 1
    [pscustomobject]@{
        PSTypeName = 'Ise.TraceConfiguration'
        Type = $sink.Type; Path = $sink.Path; Level = $sink.Level; Disabled = $sink.Disabled
    }
}
