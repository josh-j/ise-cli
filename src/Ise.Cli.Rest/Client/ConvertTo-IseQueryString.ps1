function ConvertTo-IseQueryString {
    [CmdletBinding()]
    param([hashtable] $Query)

    if (-not $Query -or -not $Query.Count) { return '' }
    $parts = foreach ($key in ($Query.Keys | Sort-Object)) {
        foreach ($value in @($Query[$key])) {
            if ($null -eq $value) { continue }
            '{0}={1}' -f `
                [uri]::EscapeDataString([string]$key), `
                [uri]::EscapeDataString([string]$value)
        }
    }
    $parts -join '&'
}
