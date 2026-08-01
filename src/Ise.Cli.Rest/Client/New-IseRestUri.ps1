function New-IseRestUri {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [IseSession] $Session,
        [Parameter(Mandatory)] [string] $Path,
        [hashtable] $Query
    )

    [uri] $uri = $null
    if ([uri]::TryCreate($Path, [System.UriKind]::Absolute, [ref]$uri) -and
        $uri.Scheme -in @('http', 'https')) {
        $builder = [System.UriBuilder]::new($uri)
    } else {
        $relative = $Path.TrimStart('/')
        $base = $Session.ServerUri.AbsoluteUri.TrimEnd('/') + '/'
        $builder = [System.UriBuilder]::new([uri]::new($base + $relative))
    }
    $encoded = ConvertTo-IseQueryString -Query $Query
    if ($encoded) {
        $builder.Query = @($builder.Query.TrimStart('?'), $encoded) |
            Where-Object { $_ } | Join-String -Separator '&'
    }
    $builder.Uri
}
