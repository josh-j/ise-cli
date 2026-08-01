function Open-IseMntConnection {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [IseSession] $Session, $Correlation)

    Invoke-IseRestConnectionProbe -Session $Session -Source Rest.Mnt `
        -Path '/admin/API/mnt/Version' -Accept 'application/xml' -DetectVersion `
        -Correlation $Correlation
}
