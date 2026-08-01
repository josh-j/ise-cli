function Get-IseDataConnectCatalog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [IseSession] $Session,
        [switch] $Refresh,
        $Correlation
    )

    $cacheKey = 'DataConnect.Catalog'
    if (-not $Refresh -and $Session.DatasourceState.ContainsKey($cacheKey)) {
        return @($Session.DatasourceState[$cacheKey])
    }
    $sql = @'
SELECT c.OWNER, c.TABLE_NAME AS VIEW_NAME, c.COLUMN_NAME, c.DATA_TYPE, c.COLUMN_ID
FROM ALL_TAB_COLUMNS c
JOIN ALL_VIEWS v ON v.OWNER = c.OWNER AND v.VIEW_NAME = c.TABLE_NAME
ORDER BY c.OWNER, c.TABLE_NAME, c.COLUMN_ID
'@
    $rows = @(Invoke-IseDataConnectCommand -Session $Session -Sql $sql `
        -Operation Catalog -Target Catalog -Correlation $Correlation)
    $catalog = foreach ($group in ($rows | Group-Object OWNER, VIEW_NAME)) {
        $first = $group.Group[0]
        [pscustomobject]@{
            PSTypeName  = 'Ise.DataConnect.ViewDescriptor'
            Owner       = [string]$first.OWNER
            Name        = [string]$first.VIEW_NAME
            Columns     = @($group.Group | Sort-Object COLUMN_ID | ForEach-Object {
                [pscustomobject]@{ Name = [string]$_.COLUMN_NAME; DataType = [string]$_.DATA_TYPE
                                   Position = [int]$_.COLUMN_ID }
            })
            SchemaSource = 'Live'
        }
    }
    $Session.DatasourceState[$cacheKey] = @($catalog)
    $Session.Capabilities['DataConnect'] = $true
    @($catalog)
}
