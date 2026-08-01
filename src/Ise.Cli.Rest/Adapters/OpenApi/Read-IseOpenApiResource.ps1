function Read-IseOpenApiResource {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [IseSession] $Session,
        [Parameter(Mandatory)] $Descriptor,
        [string] $Id,
        [string] $Path,
        [hashtable] $Query,
        [hashtable] $Headers,
        [int] $PageSize,
        [int] $First,
        [switch] $Raw,
        $Correlation
    )

    $requestPath = if ($Path) {
        if ($Path.StartsWith('/api/')) { $Path } else { '/api/v1/' + $Path.TrimStart('/') }
    } elseif ($Id -and $Descriptor.DetailPathTemplate) {
        $placeholders = @([regex]::Matches($Descriptor.DetailPathTemplate, '\{[^}]+\}'))
        if ($placeholders.Count -ne 1) {
            throw [System.ArgumentException]::new(
                "Open API resource '$($Descriptor.Name)' does not have exactly one identifier parameter."
            )
        }
        $Descriptor.DetailPathTemplate.Replace(
            $placeholders[0].Value,
            [uri]::EscapeDataString($Id)
        )
    } else { $Descriptor.CollectionPath }
    $baseQuery = if ($Query) { $Query.Clone() } else { @{} }
    $effectiveQuery = $baseQuery.Clone()
    if ($PageSize -gt 0) { $effectiveQuery.size = $PageSize }
    $page, $emitted, $fetched = 1, 0, 0
    $visited = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    while ($requestPath) {
        $response = Send-IseRestRequest -Session $Session -Path $requestPath `
            -Query $effectiveQuery -Headers $Headers -Correlation $Correlation `
            -Datasource 'Rest.OpenApi' -Operation 'Enumerate' -Target $Descriptor.Name -Page $page
        $requestQuery = $effectiveQuery
        $effectiveQuery = @{}
        $pageResult = Resolve-IseOpenApiPage -Response $response -Descriptor $Descriptor -Page $page
        $fetched += @($pageResult.Items).Count
        if ($Raw) {
            $response.BodyObject
            $emitted++
            if ($First -gt 0 -and $emitted -ge $First) { return }
        }
        else {
            foreach ($item in @($pageResult.Items)) {
                if ($null -eq $item) { continue }
                $typed = Add-IseRestTypeName -InputObject $item -TypeName $Descriptor.ItemTypeName
                Add-IseMetadata -InputObject $typed -Metadata @{
                    Datasource = 'Rest.OpenApi'; Resource = $Descriptor.Name
                    RequestUri = $response.RequestUri.AbsoluteUri; RetrievedAt = [datetime]::UtcNow
                    CorrelationId = $Correlation.CorrelationId
                }
                $emitted++
                if ($First -gt 0 -and $emitted -ge $First) { return }
            }
        }
        $null = Write-IseLogEvent -Level Information -EventId 'rest.page.completed' `
            -Message "Open API $($Descriptor.Name) page $page returned $(@($pageResult.Items).Count) records." `
            -Correlation $Correlation -RequestId $response.RequestId -Datasource 'Rest.OpenApi' `
            -Operation 'Enumerate' -Target $Descriptor.Name -Uri $response.RequestUri.AbsoluteUri `
            -Page $page -StatusCode $response.StatusCode -DurationMilliseconds $response.DurationMilliseconds `
            -RecordCount @($pageResult.Items).Count
        $requestPath = $pageResult.NextPath
        if (-not $requestPath -and $null -ne $pageResult.Total -and
            $fetched -lt [long]$pageResult.Total) {
            if (-not @($pageResult.Items).Count) {
                throw [IsePaginationException]::new(
                    'Open API pagination reported remaining records but returned an empty page.',
                    @{ Datasource = 'Rest.OpenApi'; Operation = 'Enumerate'
                       Target = $Descriptor.Name; CorrelationId = $Correlation.CorrelationId
                       Page = $page; Total = $pageResult.Total; Fetched = $fetched }
                )
            }
            $currentPage = if ($null -ne $pageResult.CurrentPage) {
                [int]$pageResult.CurrentPage
            } elseif ($requestQuery.ContainsKey('page')) {
                [int]$requestQuery.page
            } else { $page }
            $nativePageSize = if ($null -ne $pageResult.PageSize) {
                [int]$pageResult.PageSize
            } elseif ($requestQuery.ContainsKey('size')) {
                [int]$requestQuery.size
            } else { @($pageResult.Items).Count }
            $effectiveQuery = $baseQuery.Clone()
            $effectiveQuery.page = $currentPage + 1
            $effectiveQuery.size = $nativePageSize
            $requestPath = $Descriptor.CollectionPath
        }
        $nextKey = if ($requestPath) {
            (New-IseRestUri -Session $Session -Path $requestPath -Query $effectiveQuery).AbsoluteUri
        } else { $null }
        if ($nextKey -and -not $visited.Add($nextKey)) {
            throw [IsePaginationException]::new(
                "Open API pagination repeated '$nextKey'.",
                @{ Datasource = 'Rest.OpenApi'; Operation = 'Enumerate'; Target = $Descriptor.Name
                   Uri = $nextKey; CorrelationId = $Correlation.CorrelationId; Page = $page }
            )
        }
        $page++
        if ($Id) { break }
    }
}
