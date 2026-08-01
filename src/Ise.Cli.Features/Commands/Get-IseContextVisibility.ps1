function Get-IseContextVisibility {
    [CmdletBinding()]
    param(
        [string] $MacAddress,
        [string] $UserName,
        [string] $EndpointId
    )

    $correlation = New-IseCorrelationContext -Command $MyInvocation.MyCommand.Name
    try { $null = Assert-IseConnected -Correlation $correlation }
    catch { $PSCmdlet.ThrowTerminatingError((ConvertTo-IseErrorRecord -Exception $_.Exception -ErrorId 'Ise.Connection.NotConnected')) }
    $filter = @{ MacAddress = $MacAddress; UserName = $UserName; EndpointId = $EndpointId }
    $capabilities = @(
        'EndpointInventory', 'AuthenticationHistory', 'ActiveSessions', 'ProfilingAttributes'
    )
    $null = Write-IseLogEvent -Level Information -EventId 'feature.context.started' `
        -Message 'Context visibility composition started.' -Correlation $correlation `
        -Operation Compose -Target ContextVisibility
    try {
        $evidence = @(
            foreach ($capability in $capabilities) {
                Invoke-IseSemanticCapability -Capability $capability -Filter $filter `
                    -Correlation $correlation
            }
        )
        $successful = @($evidence | Where-Object Succeeded)
        $sourceData = [ordered]@{}
        foreach ($capability in $capabilities) {
            $sourceData[$capability] = @(
                $successful | Where-Object Capability -EQ $capability |
                    ForEach-Object Records
            )
        }
        $missing = @(
            foreach ($capability in $capabilities) {
                if (-not @($successful | Where-Object Capability -EQ $capability)) { $capability }
            }
        )
        $requests = @($evidence | ForEach-Object {
            [pscustomobject]@{
                Capability = $_.Capability; Provider = $_.Provider; Source = $_.Source
                Available = $_.Available; Succeeded = $_.Succeeded
                RecordCount = @($_.Records).Count; DurationMilliseconds = $_.DurationMilliseconds
                Error = $_.Reason
            }
        })
        $endpoint = @($sourceData.EndpointInventory | Select-Object -First 1)
        $result = [pscustomobject]@{
            PSTypeName            = 'Ise.Feature.ContextVisibility'
            Identity              = [pscustomobject]$filter
            Endpoint              = if ($endpoint.Count) { $endpoint[0] } else { $null }
            LastAuthentication    = Select-IseMostRecentRecord -InputObject @($sourceData.AuthenticationHistory)
            CurrentSessions       = @($sourceData.ActiveSessions)
            ProfilingAttributes   = @($sourceData.ProfilingAttributes)
            Sources               = @($successful | ForEach-Object Source | Sort-Object -Unique)
            MissingCapabilities   = $missing
            Requests              = $requests
            SourceData            = [pscustomobject]$sourceData
            Evidence              = $evidence
            CorrelationId         = $correlation.CorrelationId
        }
        $result
    }
    catch [System.Management.Automation.PipelineStoppedException] { throw }
    catch { $PSCmdlet.ThrowTerminatingError((ConvertTo-IseErrorRecord -Exception $_.Exception `
        -Correlation $correlation)) }
    finally {
        $null = Write-IseLogEvent -Level Information -EventId 'feature.context.completed' `
            -Message 'Context visibility composition completed.' -Correlation $correlation `
            -Operation Compose -Target ContextVisibility
    }
}
