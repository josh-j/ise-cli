function Open-IseMntConnection {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [IseSession] $Session, $Correlation)

    Invoke-IseRestConnectionProbe -Session $Session -Source Rest.Mnt `
        -Path '/admin/API/mnt/Version' -DetectVersion -Correlation $Correlation
}
