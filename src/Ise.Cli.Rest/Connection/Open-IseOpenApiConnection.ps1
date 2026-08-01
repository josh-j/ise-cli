function Open-IseOpenApiConnection {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [IseSession] $Session, $Correlation)

    Invoke-IseRestConnectionProbe -Session $Session -Source Rest.OpenApi `
        -Path '/api/swagger-resources' -Correlation $Correlation
}
