function Invoke-IseSourceOperation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Source,
        [Parameter(Mandatory)] [string] $Operation,
        [hashtable] $Arguments,
        $Correlation
    )

    if (-not $Correlation) {
        $Correlation = New-IseCorrelationContext -Command $MyInvocation.Line
    }
    $session = Assert-IseConnected -Correlation $Correlation
    $descriptor = Get-IseDataSource -Name $Source
    if (@($descriptor.Capabilities) -notcontains $Operation) {
        throw [System.NotSupportedException]::new(
            "Datasource '$Source' does not support '$Operation'."
        )
    }
    $commandName = [string]$descriptor.Operations[$Operation]
    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    $succeeded = $false
    $null = Write-IseLogEvent -Level Information -EventId 'source.operation.started' `
        -Message "$Source $Operation started." -Correlation $Correlation `
        -Datasource $Source -Operation $Operation
    try {
        $invoke = if ($Arguments) { $Arguments.Clone() } else { @{} }
        $invoke.Session = $session
        $invoke.Correlation = $Correlation
        & $commandName @invoke
        $succeeded = $true
    }
    catch [System.Management.Automation.PipelineStoppedException] {
        throw
    }
    catch {
        $exception = $_.Exception
        $null = Write-IseLogEvent -Level Error -EventId 'source.operation.failed' `
            -Message "$Source $Operation failed: $($exception.Message)" `
            -Correlation $Correlation -Datasource $Source -Operation $Operation `
            -DurationMilliseconds $timer.Elapsed.TotalMilliseconds -Exception $exception
        throw
    }
    finally {
        $timer.Stop()
        if ($succeeded) {
            $null = Write-IseLogEvent -Level Information -EventId 'source.operation.completed' `
                -Message "$Source $Operation completed in $([math]::Round($timer.Elapsed.TotalMilliseconds, 1)) ms." `
                -Correlation $Correlation -Datasource $Source -Operation $Operation `
                -DurationMilliseconds $timer.Elapsed.TotalMilliseconds
        }
    }
}
