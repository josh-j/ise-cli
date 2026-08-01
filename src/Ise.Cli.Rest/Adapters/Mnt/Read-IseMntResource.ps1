function Read-IseMntResource {
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
        if ($Path.StartsWith('/admin/API/mnt/')) { $Path } else { '/admin/API/mnt/' + $Path.TrimStart('/') }
    } elseif ($Id -and $Descriptor.DetailPathTemplate) {
        $Descriptor.DetailPathTemplate.Replace('{id}', [uri]::EscapeDataString($Id))
    } else { $Descriptor.CollectionPath }
    $response = Send-IseRestRequest -Session $Session -Path $requestPath -Query $Query `
        -Headers $Headers -Correlation $Correlation -Datasource 'Rest.Mnt' `
        -Operation 'Enumerate' -Target $Descriptor.Name -Page 1
    if ($Raw) { $response.BodyObject; return }
    $pageResult = Resolve-IseMntPage -Response $response -Descriptor $Descriptor -Page 1
    $emitted = 0
    foreach ($item in @($pageResult.Items)) {
        if ($null -eq $item) { continue }
        $typed = Add-IseRestTypeName -InputObject $item -TypeName $Descriptor.ItemTypeName
        Add-IseMetadata -InputObject $typed -Metadata @{
            Datasource = 'Rest.Mnt'; Resource = $Descriptor.Name
            RequestUri = $response.RequestUri.AbsoluteUri; RetrievedAt = [datetime]::UtcNow
            CorrelationId = $Correlation.CorrelationId
        }
        $emitted++
        if ($First -gt 0 -and $emitted -ge $First) { return }
    }
    $null = Write-IseLogEvent -Level Information -EventId 'rest.page.completed' `
        -Message "MnT $($Descriptor.Name) returned $(@($pageResult.Items).Count) records." `
        -Correlation $Correlation -RequestId $response.RequestId -Datasource 'Rest.Mnt' `
        -Operation 'Enumerate' -Target $Descriptor.Name -Uri $response.RequestUri.AbsoluteUri `
        -Page 1 -StatusCode $response.StatusCode -DurationMilliseconds $response.DurationMilliseconds `
        -RecordCount @($pageResult.Items).Count
}
