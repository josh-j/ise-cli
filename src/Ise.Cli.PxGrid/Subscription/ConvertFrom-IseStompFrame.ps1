function ConvertFrom-IseStompFrame {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [string] $Frame)

    $normalized = $Frame.TrimEnd([char]0)
    $parts = $normalized -split "\r?\n\r?\n", 2
    $lines = @($parts[0] -split "\r?\n")
    $headers = [ordered]@{}
    foreach ($line in @($lines | Select-Object -Skip 1)) {
        $separator = $line.IndexOf(':')
        if ($separator -gt 0) {
            $headers[$line.Substring(0, $separator)] = $line.Substring($separator + 1)
        }
    }
    [pscustomobject]@{
        PSTypeName = 'Ise.PxGrid.StompFrame'
        Command = [string]$lines[0]
        Headers = $headers
        Body = if ($parts.Count -gt 1) { $parts[1] } else { '' }
    }
}
