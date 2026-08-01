function Get-IsePxGridCatalog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [IseSession] $Session,
        [switch] $Refresh,
        $Correlation
    )

    $cacheKey = 'PxGrid.Catalog'
    if (-not $Refresh -and $Session.DatasourceState.ContainsKey($cacheKey)) {
        return $Session.DatasourceState[$cacheKey]
    }
    Initialize-IsePxGridConnection -Session $Session -Correlation $Correlation
    $manifestPath = Join-Path $script:IseProjectRoot 'schemas/pxgrid/services.json'
    $candidates = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json -Depth 20
    $catalog = [System.Collections.Generic.List[object]]::new()
    foreach ($candidate in @($candidates)) {
        $uri = Get-IsePxGridControlUri -Session $Session -Operation ServiceLookup
        try {
            $response = Invoke-IsePxGridRequest -Session $Session -Operation ServiceLookup `
                -Uri $uri -Body @{ name = $candidate.service } -Target $candidate.service `
                -Correlation $Correlation
            foreach ($service in @($response.services)) {
                if ($null -eq $service) { continue }
                $properties = [ordered]@{}
                foreach ($property in $service.properties.PSObject.Properties) {
                    $properties[$property.Name] = $property.Value
                }
                $topics = [System.Collections.Generic.List[string]]::new()
                foreach ($name in @($candidate.topicProperties)) {
                    if ($properties.Contains($name) -and $properties[$name]) {
                        $topics.Add([string]$properties[$name])
                    }
                }
                $catalog.Add([pscustomobject]@{
                    PSTypeName     = 'Ise.PxGrid.ServiceDescriptor'
                    Name           = [string]$candidate.name
                    Service        = [string]$candidate.service
                    NodeName       = [string]$service.nodeName
                    RestBaseUrl    = [string]$properties.restBaseUrl
                    WebSocketUrl   = [string]$properties.wsPubsubService
                    SnapshotPaths  = @($candidate.snapshotPaths)
                    Topics         = @($topics)
                    Properties     = [pscustomobject]$properties
                    SchemaSource   = 'Live+Bundled'
                })
            }
        }
        catch [System.Management.Automation.PipelineStoppedException] { throw }
        catch {
            $null = Write-IseLogEvent -Level Debug -EventId 'pxgrid.service.unavailable' `
                -Message "pxGrid service '$($candidate.service)' is unavailable." `
                -Correlation $Correlation -Datasource PxGrid -Operation Discover `
                -Target $candidate.service -Exception $_.Exception
        }
    }
    $Session.DatasourceState[$cacheKey] = @($catalog)
    $null = Write-IseLogEvent -Level Information -EventId 'pxgrid.discovery.completed' `
        -Message "pxGrid discovery found $($catalog.Count) service instances." `
        -Correlation $Correlation -Datasource PxGrid -Operation Discover `
        -RecordCount $catalog.Count
    @($catalog)
}
