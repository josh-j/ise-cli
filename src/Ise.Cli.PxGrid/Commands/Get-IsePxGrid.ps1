function Get-IsePxGrid {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)] [string[]] $Service,
        [string] $Path,
        [hashtable] $Body,
        [ValidateRange(1, [int]::MaxValue)] [int] $First,
        [switch] $Raw,
        [switch] $Refresh
    )

    $correlation = New-IseCorrelationContext -Command $MyInvocation.MyCommand.Name
    try { $null = Assert-IseConnected -Correlation $correlation }
    catch { $PSCmdlet.ThrowTerminatingError((ConvertTo-IseErrorRecord -Exception $_.Exception -ErrorId 'Ise.Connection.NotConnected')) }
    if ($Path -and $Service.Count -ne 1) {
        $PSCmdlet.ThrowTerminatingError([System.Management.Automation.ErrorRecord]::new(
            [System.ArgumentException]::new('-Path requires exactly one -Service.'),
            'Ise.PxGrid.InvalidPathSelection',
            [System.Management.Automation.ErrorCategory]::InvalidArgument,
            $Path
        ))
    }
    try {
        $catalog = @(Invoke-IseSourceOperation -Source PxGrid -Operation Discover `
            -Arguments @{ Refresh = $Refresh } -Correlation $correlation)
        $selected = if ($Service) {
            @($catalog | Where-Object {
                foreach ($pattern in $Service) {
                    if ($_.Name -like $pattern -or $_.Service -like $pattern) { return $true }
                }
                $false
            })
        } else { $catalog }
        if ($Service -and -not $selected) {
            throw [System.Management.Automation.ItemNotFoundException]::new(
                "No pxGrid service matches '$($Service -join ', ')'."
            )
        }
        $emitted = 0
        foreach ($descriptor in $selected) {
            $paths = if ($Path) { @($Path) } else { @($descriptor.SnapshotPaths) }
            foreach ($snapshotPath in $paths) {
                $remaining = if ($First -gt 0) { $First - $emitted } else { 0 }
                if ($First -gt 0 -and $remaining -le 0) { return }
                try {
                    Invoke-IseSourceOperation -Source PxGrid -Operation Snapshot -Arguments @{
                        Descriptor = $descriptor; Path = $snapshotPath; Body = $Body
                        First = $remaining; Raw = $Raw
                    } -Correlation $correlation | ForEach-Object { $_; $emitted++ }
                }
                catch [System.Management.Automation.PipelineStoppedException] { throw }
                catch {
                    $record = ConvertTo-IseErrorRecord -Exception $_.Exception `
                        -ErrorId 'Ise.PxGrid.SnapshotFailed' -Correlation $correlation
                    if ($Service -or $Path) { $PSCmdlet.ThrowTerminatingError($record) }
                    $PSCmdlet.WriteError($record)
                }
            }
        }
    }
    catch [System.Management.Automation.PipelineStoppedException] { throw }
    catch {
        if ($_ -is [System.Management.Automation.ErrorRecord] -and $_.FullyQualifiedErrorId -like 'Ise.*') { throw }
        $PSCmdlet.ThrowTerminatingError((ConvertTo-IseErrorRecord -Exception $_.Exception `
            -Correlation $correlation))
    }
}
