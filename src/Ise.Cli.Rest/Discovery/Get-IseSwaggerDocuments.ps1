function Get-IseSwaggerDocuments {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [IseSession] $Session,
        [switch] $Refresh,
        $Correlation,
        [string] $Datasource = 'Rest.OpenApi'
    )

    $cacheKey = 'Rest.Swagger.Documents'
    if ($Refresh) { $Session.DatasourceState.Remove($cacheKey) }
    if ($Session.DatasourceState.ContainsKey($cacheKey)) {
        return @($Session.DatasourceState[$cacheKey])
    }

    $index = Send-IseRestRequest -Session $Session -Path '/api/swagger-resources' `
        -Correlation $Correlation -Datasource $Datasource -Operation Discover `
        -Target 'SwaggerResources'
    $documents = foreach ($group in @($index.BodyObject)) {
        if (-not $group.location) { continue }
        try {
            $response = Send-IseRestRequest -Session $Session -Path ([string]$group.location) `
                -Correlation $Correlation -Datasource $Datasource -Operation Discover `
                -Target ([string]$group.name)
            if ($null -eq $response.BodyObject.paths) { continue }
            [pscustomobject]@{
                Name     = [string]$group.name
                Location = [string]$group.location
                Document = $response.BodyObject
            }
        }
        catch {
            $null = Write-IseLogEvent -Level Warning -EventId 'schema.discovery.failed' `
                -Message "Swagger group '$($group.name)' could not be loaded: $($_.Exception.Message)" `
                -Correlation $Correlation -Datasource $Datasource -Operation Discover `
                -Target ([string]$group.name) -Exception $_.Exception
        }
    }
    $Session.DatasourceState[$cacheKey] = @($documents)
    @($documents)
}

function Resolve-IseSwaggerPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] $Document
    )

    if ($Path.StartsWith('/ers/') -or $Path.StartsWith('/api/')) { return $Path }
    $basePathProperty = $Document.PSObject.Properties['basePath']
    $basePath = if ($basePathProperty) { [string]$basePathProperty.Value } else { $null }
    if ($basePath) { return $basePath.TrimEnd('/') + '/' + $Path.TrimStart('/') }
    '/api/v1/' + $Path.TrimStart('/')
}

function ConvertTo-IseResourceName {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [string] $Token)

    $parts = @($Token -split '[^A-Za-z0-9]+' | Where-Object { $_ })
    ($parts | ForEach-Object {
        if ($_.Length -eq 1) { $_.ToUpperInvariant() }
        else { $_.Substring(0, 1).ToUpperInvariant() + $_.Substring(1) }
    }) -join ''
}
