function Get-IseMntCatalog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [IseSession] $Session,
        [switch] $Refresh,
        $Correlation
    )
    $cacheKey = 'Rest.Mnt.Catalog'
    if (-not $Refresh -and $Session.DatasourceState.ContainsKey($cacheKey)) {
        return @($Session.DatasourceState[$cacheKey])
    }
    $manifestPath = Join-Path $script:IseProjectRoot 'schemas/rest/mnt/manifest.json'
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json -Depth 20
    $catalog = foreach ($resource in @($manifest.resources)) {
        New-IseResourceDescriptor -Api Mnt -Name $resource.name `
            -CollectionPath $resource.collectionPath `
            -DetailPathTemplate $resource.detailPathTemplate `
            -CanEnumerate ([bool]$resource.canEnumerate) `
            -CanGetById ([bool]$resource.canGetById) `
            -PaginationStrategy ([string]$resource.paginationStrategy) `
            -ItemTypeName ([string]$resource.itemTypeName) -SchemaSource Bundled `
            -RequiredParameters @($resource.requiredParameters)
    }
    $Session.DatasourceState[$cacheKey] = @($catalog)
    $Session.Capabilities['Rest.Mnt'] = $true
    @($catalog)
}
