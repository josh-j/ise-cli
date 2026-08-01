function Get-IseErsCatalog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [IseSession] $Session,
        [switch] $Refresh,
        $Correlation
    )

    $cacheKey = 'Rest.Ers.Catalog'
    if (-not $Refresh -and $Session.DatasourceState.ContainsKey($cacheKey)) {
        return @($Session.DatasourceState[$cacheKey])
    }
    $manifestPath = Join-Path $script:IseProjectRoot 'schemas/rest/ers/manifest.json'
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json -Depth 20
    $bundled = foreach ($resource in @($manifest.resources)) {
        New-IseResourceDescriptor -Api Ers -Name $resource.name `
            -CollectionPath $resource.collectionPath `
            -DetailPathTemplate $resource.detailPathTemplate `
            -CanEnumerate ([bool]$resource.canEnumerate) `
            -CanGetById ([bool]$resource.canGetById) `
            -PaginationStrategy ([string]$resource.paginationStrategy) `
            -CollectionEnvelope ([string]$resource.collectionEnvelope) `
            -ItemTypeName ([string]$resource.itemTypeName) `
            -SchemaSource Bundled
    }
    $live = @()
    $canDiscover = $Session.Capabilities.ContainsKey('Rest.OpenApi') -and
        [bool]$Session.Capabilities['Rest.OpenApi']
    if ($canDiscover) { try {
        $documents = @(Get-IseSwaggerDocuments -Session $Session -Refresh:$Refresh `
            -Correlation $Correlation -Datasource 'Rest.Ers')
        foreach ($swagger in $documents) {
            $paths = @($swagger.Document.paths.PSObject.Properties)
            foreach ($property in $paths) {
                $getProperty = $property.Value.PSObject.Properties['get']
                if (-not $getProperty) { continue }
                $absolutePath = Resolve-IseSwaggerPath -Path ([string]$property.Name) `
                    -Document $swagger.Document
                $match = [regex]::Match($absolutePath, '^/ers/config/([^/{]+)$', 'IgnoreCase')
                if (-not $match.Success) { continue }
                $resourceToken = $match.Groups[1].Value
                $known = @($bundled | Where-Object CollectionPath -EQ $absolutePath | Select-Object -First 1)
                $name = if ($known) { $known[0].Name } else {
                    ConvertTo-IseResourceName -Token $resourceToken
                }
                $detail = @($paths | ForEach-Object {
                    Resolve-IseSwaggerPath -Path ([string]$_.Name) -Document $swagger.Document
                } | Where-Object { $_ -match "^$([regex]::Escape($absolutePath))/\{[^/]+\}$" } |
                    Select-Object -First 1)
                $detailTemplate = if ($detail) {
                    [regex]::Replace($detail[0], '\{[^/]+\}', '{id}')
                } else { $null }
                $live += New-IseResourceDescriptor -Api Ers -Name $name `
                    -CollectionPath $absolutePath -DetailPathTemplate $detailTemplate `
                    -CanEnumerate $true -CanGetById ([bool]$detailTemplate) `
                    -PaginationStrategy ErsSearchResult `
                    -CollectionEnvelope 'SearchResult.resources' `
                    -ItemTypeName "Ise.Rest.Ers.$name" -SchemaSource Live
            }
        }
    }
    catch {
        $null = Write-IseLogEvent -Level Warning -EventId 'schema.discovery.failed' `
            -Message "ERS live discovery failed; using bundled descriptors: $($_.Exception.Message)" `
            -Correlation $Correlation -Datasource 'Rest.Ers' -Operation Discover `
            -Exception $_.Exception
    } }
    $catalog = @(Merge-IseResourceCatalog -Live $live -Bundled $bundled)
    $Session.DatasourceState[$cacheKey] = @($catalog)
    $Session.Capabilities['Rest.Ers'] = $true
    @($catalog)
}
