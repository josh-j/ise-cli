function Get-IseOpenApiCatalog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [IseSession] $Session,
        [switch] $Refresh,
        $Correlation
    )

    $cacheKey = 'Rest.OpenApi.Catalog'
    if (-not $Refresh -and $Session.DatasourceState.ContainsKey($cacheKey)) {
        return @($Session.DatasourceState[$cacheKey])
    }
    $bundledPath = Join-Path $script:IseProjectRoot 'schemas/rest/openapi/manifest.json'
    $bundled = @()
    if (Test-Path -LiteralPath $bundledPath) {
        $manifest = Get-Content -LiteralPath $bundledPath -Raw | ConvertFrom-Json -Depth 20
        $bundled = foreach ($resource in @($manifest.resources)) {
            New-IseResourceDescriptor -Api OpenApi -Name $resource.name `
                -CollectionPath $resource.collectionPath `
                -DetailPathTemplate $resource.detailPathTemplate `
                -CanEnumerate ([bool]$resource.canEnumerate) `
                -CanGetById ([bool]$resource.canGetById) `
                -PaginationStrategy ([string]$resource.paginationStrategy) `
                -ItemTypeName ([string]$resource.itemTypeName) -SchemaSource Bundled
        }
    }
    $live = @()
    $canDiscover = $Session.Capabilities.ContainsKey('Rest.OpenApi') -and
        [bool]$Session.Capabilities['Rest.OpenApi']
    if ($canDiscover) { try {
        $documents = @(Get-IseSwaggerDocuments -Session $Session -Refresh:$Refresh `
            -Correlation $Correlation -Datasource 'Rest.OpenApi')
        foreach ($swagger in $documents) {
            foreach ($property in $swagger.Document.paths.PSObject.Properties) {
                $path = [string]$property.Name
                $getProperty = $property.Value.PSObject.Properties['get']
                $get = if ($getProperty) { $getProperty.Value } else { $null }
                if ($null -eq $get) { continue }
                $absolutePath = Resolve-IseSwaggerPath -Path $path -Document $swagger.Document
                if ($absolutePath.StartsWith('/ers/')) { continue }
                $operationId = [string]$get.operationId
                $name = if ($operationId) { $operationId } else {
                    ($path.Trim('/') -replace '[^A-Za-z0-9]+', '_')
                }
                $pathParameters = @([regex]::Matches($absolutePath, '\{([^}]+)\}') |
                    ForEach-Object { $_.Groups[1].Value })
                $parameterized = $pathParameters.Count -gt 0
                $live += New-IseResourceDescriptor -Api OpenApi -Name $name `
                    -CollectionPath $absolutePath `
                    -DetailPathTemplate $(if ($parameterized) { $absolutePath } else { $null }) `
                    -CanEnumerate (-not $parameterized) `
                    -CanGetById ($pathParameters.Count -eq 1) -PaginationStrategy OpenApi `
                    -ItemTypeName "Ise.Rest.OpenApi.$name" -SchemaSource Live `
                    -RequiredParameters $pathParameters
            }
        }
    }
    catch {
        $null = Write-IseLogEvent -Level Warning -EventId 'schema.discovery.failed' `
            -Message "Open API live discovery failed; using bundled descriptors: $($_.Exception.Message)" `
            -Correlation $Correlation -Datasource 'Rest.OpenApi' -Operation Discover `
            -Exception $_.Exception
    } }
    $catalog = @(Merge-IseResourceCatalog -Live $live -Bundled $bundled)
    $Session.DatasourceState[$cacheKey] = $catalog
    $Session.Capabilities['Rest.OpenApi'] = [bool]$live.Count
    $catalog
}
