function Open-IseErsConnection {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [IseSession] $Session, $Correlation)

    Invoke-IseRestConnectionProbe -Session $Session -Source Rest.Ers `
        -Path '/ers/config/endpoint' -Query @{ size = 1 } -Correlation $Correlation
}
