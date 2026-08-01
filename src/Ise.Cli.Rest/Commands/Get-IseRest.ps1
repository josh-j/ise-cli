function Get-IseRest {
    [CmdletBinding(DefaultParameterSetName = 'Ers')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Ers')] [switch] $Ers,
        [Parameter(Mandatory, ParameterSetName = 'OpenApi')] [switch] $OpenApi,
        [Parameter(Mandatory, ParameterSetName = 'Mnt')] [switch] $Mnt,
        [Parameter(Position = 0)] [string[]] $Resource,
        [string] $Id,
        [string] $Path,
        [hashtable] $Query,
        [hashtable] $Headers,
        [ValidateRange(1, [int]::MaxValue)] [int] $PageSize,
        [ValidateRange(1, [int]::MaxValue)] [int] $First,
        [switch] $Raw
    )

    $correlation = New-IseCorrelationContext -Command $MyInvocation.MyCommand.Name
    try { $null = Assert-IseConnected -Correlation $correlation }
    catch { $PSCmdlet.ThrowTerminatingError((ConvertTo-IseErrorRecord -Exception $_.Exception -ErrorId 'Ise.Connection.NotConnected')) }
    if ($Id -and (($Resource.Count -ne 1) -or $Path)) {
        $PSCmdlet.ThrowTerminatingError([System.Management.Automation.ErrorRecord]::new(
            [System.ArgumentException]::new('-Id requires exactly one -Resource and cannot be combined with -Path.'),
            'Ise.Rest.InvalidIdSelection',
            [System.Management.Automation.ErrorCategory]::InvalidArgument,
            $Id
        ))
    }
    $api = $PSCmdlet.ParameterSetName
    $source = "Rest.$api"
    $null = Write-IseLogEvent -Level Information -EventId 'command.started' `
        -Message "Get-IseRest started for $api." -Correlation $correlation `
        -Datasource $source -Operation 'Read'
    $emitted = 0
    try {
        if ($Path) {
            $descriptor = New-IseResourceDescriptor -Api $api -Name Unknown `
                -CollectionPath $Path -CanEnumerate $true -PaginationStrategy Single `
                -ItemTypeName 'Ise.Rest.Unknown' -SchemaSource Caller
            $arguments = @{
                Descriptor = $descriptor; Path = $Path; Query = $Query; Headers = $Headers
                PageSize = $PageSize; First = $First; Raw = $Raw
            }
            Invoke-IseSourceOperation -Source $source -Operation GetPath `
                -Arguments $arguments -Correlation $correlation
            return
        }

        $catalog = @(Get-IseResourceCatalog -Api $api -Correlation $correlation)
        $selected = [System.Collections.Generic.List[object]]::new()
        if ($Resource) {
            foreach ($pattern in $Resource) {
                foreach ($match in @($catalog | Where-Object Name -Like $pattern)) {
                    if (-not $selected.Contains($match)) { $selected.Add($match) }
                }
            }
            if (-not $selected.Count) {
                throw [System.Management.Automation.ItemNotFoundException]::new(
                    "No $api REST resource matches '$($Resource -join ', ')'."
                )
            }
        } else {
            foreach ($descriptor in @($catalog | Where-Object CanEnumerate)) { $selected.Add($descriptor) }
        }

        foreach ($descriptor in $selected) {
            $operation = if ($Id) { 'GetById' } else { 'Enumerate' }
            $remaining = if ($First -gt 0) { $First - $emitted } else { 0 }
            if ($First -gt 0 -and $remaining -le 0) { break }
            $arguments = @{
                Descriptor = $descriptor; Id = $Id; Query = $Query; Headers = $Headers
                PageSize = $PageSize; First = $remaining; Raw = $Raw
            }
            try {
                Invoke-IseSourceOperation -Source $source -Operation $operation `
                    -Arguments $arguments -Correlation $correlation | ForEach-Object {
                    $_
                    $emitted++
                }
                if ($First -gt 0 -and $emitted -ge $First) { return }
            }
            catch [System.Management.Automation.PipelineStoppedException] { throw }
            catch {
                $record = if ($Resource -or $Id) {
                    ConvertTo-IseErrorRecord -Exception $_.Exception -Correlation $correlation
                } else {
                    ConvertTo-IseErrorRecord -Exception $_.Exception `
                        -ErrorId 'Ise.Rest.ResourceFailed' -Correlation $correlation
                }
                if ($Resource -or $Id) { $PSCmdlet.ThrowTerminatingError($record) }
                $PSCmdlet.WriteError($record)
            }
        }
    }
    catch [System.Management.Automation.PipelineStoppedException] { throw }
    catch {
        if ($_ -is [System.Management.Automation.ErrorRecord] -and $_.FullyQualifiedErrorId -like 'Ise.*') { throw }
        $PSCmdlet.ThrowTerminatingError((ConvertTo-IseErrorRecord -Exception $_.Exception `
            -Correlation $correlation))
    }
    finally {
        $null = Write-IseLogEvent -Level Information -EventId 'command.completed' `
            -Message "Get-IseRest completed for $api after emitting $emitted records." `
            -Correlation $correlation -Datasource $source -Operation 'Read' `
            -RecordCount $emitted
    }
}
