function Register-IseTraceSink {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Name,
        [Parameter(Mandatory)] [string] $WriteCommand,
        [string] $CloseCommand,
        [ValidateSet('Debug', 'Information', 'Warning', 'Error')]
        [string] $Level = 'Information',
        $State
    )

    if (-not (Get-Command $WriteCommand -CommandType Function, Cmdlet -ErrorAction SilentlyContinue)) {
        throw [System.ArgumentException]::new("Trace sink write command '$WriteCommand' does not resolve.")
    }
    if ($CloseCommand -and -not (Get-Command $CloseCommand -CommandType Function, Cmdlet -ErrorAction SilentlyContinue)) {
        throw [System.ArgumentException]::new("Trace sink close command '$CloseCommand' does not resolve.")
    }
    $sink = [pscustomobject]@{
        PSTypeName   = 'Ise.TraceSink'
        Type         = $Name
        Path         = $null
        Level        = $Level
        WriteCommand = $WriteCommand
        CloseCommand = $CloseCommand
        State        = $State
        Disabled     = $false
    }
    $script:IseTraceSinks.Add($sink)
    $sink
}
