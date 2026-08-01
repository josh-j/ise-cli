function Get-IseResourceCatalog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Ers', 'OpenApi', 'Mnt')]
        [string] $Api,
        [switch] $Refresh,
        $Correlation
    )

    if (-not $Correlation) { $Correlation = New-IseCorrelationContext -Command $MyInvocation.MyCommand.Name }
    Invoke-IseSourceOperation -Source "Rest.$Api" -Operation Discover `
        -Arguments @{ Refresh = $Refresh } -Correlation $Correlation
}
