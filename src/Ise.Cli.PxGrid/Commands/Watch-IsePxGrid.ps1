function Watch-IsePxGrid {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)] [string] $Service,
        [string] $Topic,
        [ValidateRange(1, [int]::MaxValue)] [int] $First,
        [switch] $Reconnect,
        [ValidateRange(0, 300)] [int] $ReconnectDelaySec = 2
    )

    $correlation = New-IseCorrelationContext -Command $MyInvocation.MyCommand.Name
    try { $null = Assert-IseConnected -Correlation $correlation }
    catch { $PSCmdlet.ThrowTerminatingError((ConvertTo-IseErrorRecord -Exception $_.Exception -ErrorId 'Ise.Connection.NotConnected')) }
    try {
        $catalog = @(Invoke-IseSourceOperation -Source PxGrid -Operation Discover `
            -Correlation $correlation)
        $descriptor = @($catalog | Where-Object {
            $_.Name -eq $Service -or $_.Service -eq $Service
        } | Select-Object -First 1)
        if (-not $descriptor) {
            throw [System.Management.Automation.ItemNotFoundException]::new(
                "pxGrid service '$Service' was not discovered."
            )
        }
        $selectedTopic = if ($Topic) { $Topic } else { @($descriptor[0].Topics)[0] }
        if ([string]::IsNullOrWhiteSpace([string]$selectedTopic)) {
            throw [System.ArgumentException]::new(
                "pxGrid service '$Service' advertised no topic; specify -Topic."
            )
        }
        Invoke-IseSourceOperation -Source PxGrid -Operation Subscribe -Arguments @{
            Descriptor = $descriptor[0]; Topic = $selectedTopic; First = $First
            Reconnect = $Reconnect; ReconnectDelaySec = $ReconnectDelaySec
        } -Correlation $correlation
    }
    catch [System.Management.Automation.PipelineStoppedException] { throw }
    catch {
        if ($_ -is [System.Management.Automation.ErrorRecord] -and $_.FullyQualifiedErrorId -like 'Ise.*') { throw }
        $PSCmdlet.ThrowTerminatingError((ConvertTo-IseErrorRecord -Exception $_.Exception `
            -Correlation $correlation))
    }
}
