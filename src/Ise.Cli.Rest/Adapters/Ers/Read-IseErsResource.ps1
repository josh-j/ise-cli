function Read-IseErsResource {
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
        if ($Path.StartsWith('/ers/')) { $Path } else { '/ers/' + $Path.TrimStart('/') }
    } elseif ($Id) {
        if (-not $Descriptor.CanGetById -or -not $Descriptor.DetailPathTemplate) {
            throw [System.ArgumentException]::new("ERS resource '$($Descriptor.Name)' has no detail operation.")
        }
        $Descriptor.DetailPathTemplate.Replace('{id}', [uri]::EscapeDataString($Id))
    } else { $Descriptor.CollectionPath }
    $effectiveQuery = if ($Query) { $Query.Clone() } else { @{} }
    if ($PageSize -gt 0) { $effectiveQuery.size = $PageSize }
    $page = 1
    $emitted = 0
    $visited = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )
    while ($requestPath) {
        $response = Send-IseRestRequest -Session $Session -Path $requestPath `
            -Query $effectiveQuery -Headers $Headers -Correlation $Correlation `
            -Datasource 'Rest.Ers' -Operation $(if ($Id) { 'GetById' } else { 'Enumerate' }) `
            -Target $Descriptor.Name -Page $page
        $effectiveQuery = @{}
        if ($Raw) {
            $response.BodyObject
            $pageResult = Resolve-IseErsPage -Response $response -Descriptor $Descriptor -Page $page
        } else {
            $pageResult = Resolve-IseErsPage -Response $response -Descriptor $Descriptor -Page $page
            foreach ($item in @($pageResult.Items)) {
                if ($null -eq $item) { continue }
                $typed = Add-IseRestTypeName -InputObject $item -TypeName $Descriptor.ItemTypeName
                Add-IseMetadata -InputObject $typed -Metadata @{
                    Datasource    = 'Rest.Ers'
                    Resource      = $Descriptor.Name
                    RequestUri    = $response.RequestUri.AbsoluteUri
                    RetrievedAt   = [datetime]::UtcNow
                    CorrelationId = $Correlation.CorrelationId
                }
                $emitted++
                if ($First -gt 0 -and $emitted -ge $First) { return }
            }
        }
        $null = Write-IseLogEvent -Level Information -EventId 'rest.page.completed' `
            -Message "ERS $($Descriptor.Name) page $page returned $(@($pageResult.Items).Count) records." `
            -Correlation $Correlation -RequestId $response.RequestId -Datasource 'Rest.Ers' `
            -Operation 'Enumerate' -Target $Descriptor.Name -Uri $response.RequestUri.AbsoluteUri `
            -Page $page -StatusCode $response.StatusCode `
            -DurationMilliseconds $response.DurationMilliseconds `
            -RecordCount @($pageResult.Items).Count
        $requestPath = $pageResult.NextPath
        if ($requestPath -and -not $visited.Add($requestPath)) {
            throw [IsePaginationException]::new(
                "ERS pagination repeated '$requestPath'.",
                @{ Datasource = 'Rest.Ers'; Operation = 'Enumerate'; Target = $Descriptor.Name
                   Uri = $requestPath; CorrelationId = $Correlation.CorrelationId; Page = $page }
            )
        }
        $page++
        if ($Id) { break }
    }
}
