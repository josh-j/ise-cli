function Get-IseDataConnect {
    [CmdletBinding(DefaultParameterSetName = 'View')]
    param(
        [Parameter(Position = 0, ParameterSetName = 'View')] [string[]] $View,
        [Parameter(Mandatory, ParameterSetName = 'Sql')] [string] $Sql,
        [Parameter(ParameterSetName = 'Sql')] [hashtable] $Parameter,
        [Parameter(ParameterSetName = 'View')] [string[]] $Column,
        [ValidateRange(1, [int]::MaxValue)] [int] $First
    )
    $correlation = New-IseCorrelationContext -Command $MyInvocation.MyCommand.Name
    try { $session = Assert-IseConnected -Correlation $correlation }
    catch { $PSCmdlet.ThrowTerminatingError((ConvertTo-IseErrorRecord -Exception $_.Exception -ErrorId 'Ise.Connection.NotConnected')) }
    if ($PSCmdlet.ParameterSetName -eq 'Sql') {
        $normalized = $Sql.TrimStart()
        if ($normalized -notmatch '^(?is)(SELECT|WITH)\b' -or $normalized -match ';\s*\S') {
            $PSCmdlet.ThrowTerminatingError([System.Management.Automation.ErrorRecord]::new(
                [System.ArgumentException]::new('Only one SELECT or WITH query is supported.'),
                'Ise.DataConnect.ReadOnlySqlRequired',
                [System.Management.Automation.ErrorCategory]::InvalidArgument,
                $Sql
            ))
        }
        try {
            Invoke-IseDataConnectCommand -Session $session -Sql $Sql -Parameters $Parameter `
                -Operation Query -Target AdHoc -First $First -Correlation $correlation |
                Add-IseDataConnectTypeName -View Query -Correlation $correlation
        }
        catch { $PSCmdlet.ThrowTerminatingError((ConvertTo-IseErrorRecord -Exception $_.Exception `
            -Correlation $correlation)) }
        return
    }

    try { $catalog = @(Get-IseDataConnectCatalog -Session $session -Correlation $correlation) }
    catch { $PSCmdlet.ThrowTerminatingError((ConvertTo-IseErrorRecord -Exception $_.Exception `
        -Correlation $correlation)) }
    $selected = if ($View) {
        @($catalog | Where-Object { $name = $_.Name; @($View | Where-Object { $name -like $_ }).Count })
    } else { $catalog }
    if (-not $selected) {
        $PSCmdlet.ThrowTerminatingError([System.Management.Automation.ErrorRecord]::new(
            [System.Management.Automation.ItemNotFoundException]::new('No Data Connect view matched.'),
            'Ise.DataConnect.ViewNotFound',
            [System.Management.Automation.ErrorCategory]::ObjectNotFound,
            $View
        ))
    }
    $emitted = 0
    foreach ($descriptor in $selected) {
        if ($descriptor.Owner -notmatch '^[A-Za-z][A-Za-z0-9_$#]*$' -or
            $descriptor.Name -notmatch '^[A-Za-z][A-Za-z0-9_$#]*$') {
            throw [IseDataConnectException]::new('Catalog returned an invalid view identifier.',
                @{ Datasource = 'DataConnect'; Operation = 'Enumerate'; Target = $descriptor.Name })
        }
        $projection = '*'
        if ($Column) {
            $known = @($descriptor.Columns.Name)
            foreach ($name in $Column) {
                if ($name -notin $known) { throw "Column '$name' is not present on $($descriptor.Name)." }
            }
            $projection = $Column -join ', '
        }
        $query = "SELECT $projection FROM $($descriptor.Owner).$($descriptor.Name)"
        $remaining = if ($First -gt 0) { $First - $emitted } else { 0 }
        try {
            Invoke-IseDataConnectCommand -Session $session -Sql $query -Operation Query `
                -Target $descriptor.Name -First $remaining -Correlation $correlation |
                Add-IseDataConnectTypeName -View $descriptor.Name -Correlation $correlation |
                ForEach-Object { $_; $emitted++ }
            if ($First -gt 0 -and $emitted -ge $First) { return }
        }
        catch [System.Management.Automation.PipelineStoppedException] { throw }
        catch {
            $record = ConvertTo-IseErrorRecord -Exception $_.Exception -Correlation $correlation
            if ($View) { $PSCmdlet.ThrowTerminatingError($record) }
            $PSCmdlet.WriteError($record)
        }
    }
}
