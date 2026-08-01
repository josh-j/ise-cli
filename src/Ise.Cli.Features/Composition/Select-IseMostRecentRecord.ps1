function Select-IseMostRecentRecord {
    [CmdletBinding()]
    param([object[]] $InputObject)

    if (-not $InputObject) { return $null }
    $timestampNames = @(
        'timestamp', 'Timestamp', 'authenticationTimestamp', 'AUTHENTICATION_TIMESTAMP',
        'eventTimestamp', 'EVENT_TIMESTAMP', 'date', 'Date'
    )
    $InputObject | Sort-Object -Descending -Property @{
        Expression = {
            foreach ($name in $timestampNames) {
                if ($_.PSObject.Properties.Name -contains $name -and $_.$name) {
                    try { return [datetime]$_.$name } catch { return [datetime]::MinValue }
                }
            }
            [datetime]::MinValue
        }
    } | Select-Object -First 1
}
