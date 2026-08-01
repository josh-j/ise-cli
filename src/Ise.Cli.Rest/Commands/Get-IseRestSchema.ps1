function Get-IseRestSchema {
    [CmdletBinding(DefaultParameterSetName = 'Ers')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Ers')] [switch] $Ers,
        [Parameter(Mandatory, ParameterSetName = 'OpenApi')] [switch] $OpenApi,
        [Parameter(Mandatory, ParameterSetName = 'Mnt')] [switch] $Mnt,
        [Parameter(Position = 0)] [string[]] $Resource,
        [switch] $Refresh
    )

    $correlation = New-IseCorrelationContext -Command $MyInvocation.MyCommand.Name
    try { $null = Assert-IseConnected -Correlation $correlation }
    catch { $PSCmdlet.ThrowTerminatingError((ConvertTo-IseErrorRecord -Exception $_.Exception -ErrorId 'Ise.Connection.NotConnected')) }
    $api = $PSCmdlet.ParameterSetName
    try {
        $catalog = @(Get-IseResourceCatalog -Api $api -Refresh:$Refresh -Correlation $correlation)
        if (-not $Resource) { $catalog; return }
        foreach ($pattern in $Resource) {
            $matches = @($catalog | Where-Object Name -Like $pattern)
            if (-not $matches) {
                $record = [System.Management.Automation.ErrorRecord]::new(
                    [System.Management.Automation.ItemNotFoundException]::new(
                        "No $api REST resource matches '$pattern'."
                    ),
                    'Ise.Rest.Schema.ResourceNotFound',
                    [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                    $pattern
                )
                $PSCmdlet.WriteError($record)
                continue
            }
            $matches
        }
    }
    catch [System.Management.Automation.PipelineStoppedException] { throw }
    catch { $PSCmdlet.ThrowTerminatingError((ConvertTo-IseErrorRecord -Exception $_.Exception `
        -Correlation $correlation)) }
}
