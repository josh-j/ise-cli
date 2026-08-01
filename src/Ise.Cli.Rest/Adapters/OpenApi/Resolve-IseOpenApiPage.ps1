function Resolve-IseOpenApiPage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Response,
        [Parameter(Mandatory)] $Descriptor,
        [Parameter(Mandatory)] [int] $Page
    )

    $body = $Response.BodyObject
    $items = if ($null -ne $body -and $body.PSObject.Properties.Name -contains 'response') {
        @($body.response)
    } elseif ($null -ne $body -and $body.PSObject.Properties.Name -contains 'items') {
        @($body.items)
    } elseif ($null -ne $body -and $body.PSObject.Properties.Name -contains 'data' -and
        $body.data -is [System.Collections.IEnumerable] -and $body.data -isnot [string]) {
        @($body.data)
    } elseif ($body -is [System.Collections.IEnumerable] -and $body -isnot [string] -and $body -isnot [pscustomobject]) {
        @($body)
    } else { @($body) }
    $next = $null
    if ($null -ne $body -and $body.PSObject.Properties.Name -contains 'nextPage' -and $body.nextPage) {
        $next = if ($body.nextPage -is [string]) {
            [string]$body.nextPage
        } elseif ($body.nextPage.PSObject.Properties.Name -contains 'href') {
            [string]$body.nextPage.href
        }
    }
    if (-not $next -and $null -ne $body) {
        foreach ($containerName in @('_links', 'links')) {
            $container = $body.PSObject.Properties[$containerName]
            if (-not $container -or -not $container.Value) { continue }
            $nextValue = $container.Value.PSObject.Properties['next']
            if (-not $nextValue -or -not $nextValue.Value) { continue }
            $next = if ($nextValue.Value -is [string]) {
                [string]$nextValue.Value
            } elseif ($nextValue.Value.PSObject.Properties.Name -contains 'href') {
                [string]$nextValue.Value.href
            }
            if ($next) { break }
        }
    }
    $pagination = if ($null -ne $body -and
        $body.PSObject.Properties.Name -contains 'pagination') { $body.pagination } else { $body }
    $total = $null
    $currentPage = $null
    $pageSize = $null
    if ($null -ne $pagination) {
        foreach ($name in @('total', 'totalCount', 'total_count', 'count')) {
            $property = $pagination.PSObject.Properties[$name]
            if ($property -and $null -ne $property.Value) { $total = [long]$property.Value; break }
        }
        foreach ($name in @('page', 'pageNumber', 'page_number')) {
            $property = $pagination.PSObject.Properties[$name]
            if ($property -and $null -ne $property.Value) { $currentPage = [int]$property.Value; break }
        }
        foreach ($name in @('size', 'pageSize', 'page_size', 'limit')) {
            $property = $pagination.PSObject.Properties[$name]
            if ($property -and $null -ne $property.Value) { $pageSize = [int]$property.Value; break }
        }
    }
    [pscustomobject]@{
        Items = $items; NextPath = $next; Total = $total
        CurrentPage = $currentPage; PageSize = $pageSize
    }
}
