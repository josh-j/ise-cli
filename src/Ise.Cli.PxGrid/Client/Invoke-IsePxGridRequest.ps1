function Invoke-IsePxGridRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [IseSession] $Session,
        [Parameter(Mandatory)] [ValidateSet('AccountActivate', 'ServiceLookup', 'AccessSecret', 'Snapshot')] [string] $Operation,
        [Parameter(Mandatory)] [uri] $Uri,
        [hashtable] $Body,
        [string] $PeerNodeName,
        [string] $Target,
        $Correlation
    )

    $requestId = [guid]::NewGuid().ToString('N')
    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    $null = Write-IseLogEvent -Level Debug -EventId 'pxgrid.request.started' `
        -Message "pxGrid $Operation request started." -Correlation $Correlation `
        -RequestId $requestId -Datasource PxGrid -Operation $Operation -Target $Target -Uri $Uri
    try {
        if ($Session.DatasourceState.ContainsKey('PxGrid.Executor')) {
            $executor = $Session.DatasourceState['PxGrid.Executor']
            return & $executor -Operation $Operation -Uri $Uri -Body $Body `
                -PeerNodeName $PeerNodeName -Target $Target
        }
        $client = New-IsePxGridClient -Session $Session
        $request = [System.Net.Http.HttpRequestMessage]::new(
            [System.Net.Http.HttpMethod]::Post,
            $Uri
        )
        try {
            $json = if ($Body) { $Body | ConvertTo-Json -Depth 20 -Compress } else { '{}' }
            $request.Content = [System.Net.Http.StringContent]::new(
                $json,
                [System.Text.Encoding]::UTF8,
                'application/json'
            )
            if ($Operation -eq 'Snapshot') {
                $secret = Get-IsePxGridAccessSecret -Session $Session `
                    -PeerNodeName $PeerNodeName -Correlation $Correlation
                $config = $Session.DatasourceState['PxGrid.Config']
                $token = [Convert]::ToBase64String(
                    [System.Text.Encoding]::UTF8.GetBytes("$($config.ClientName):$secret")
                )
                $request.Headers.Authorization = [System.Net.Http.Headers.AuthenticationHeaderValue]::new(
                    'Basic', $token
                )
            }
            $response = $client.Send($request)
            $content = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
            if (-not $response.IsSuccessStatusCode) {
                throw [IsePxGridException]::new(
                    "pxGrid $Operation returned HTTP $([int]$response.StatusCode).",
                    @{ Datasource = 'PxGrid'; Operation = $Operation; Target = $Target
                       Uri = $Uri.AbsoluteUri; StatusCode = [int]$response.StatusCode
                       ResponseBody = $content; CorrelationId = $Correlation.CorrelationId
                       RequestId = $requestId }
                )
            }
            if ([string]::IsNullOrWhiteSpace($content)) { return $null }
            try { $content | ConvertFrom-Json -Depth 100 }
            catch {
                throw [IsePxGridException]::new(
                    "pxGrid $Operation returned invalid JSON.",
                    @{ Datasource = 'PxGrid'; Operation = $Operation; Target = $Target
                       Uri = $Uri.AbsoluteUri; ResponseBody = $content
                       CorrelationId = $Correlation.CorrelationId; RequestId = $requestId },
                    $_.Exception
                )
            }
        }
        finally {
            if ($request) { $request.Dispose() }
        }
    }
    catch [System.Management.Automation.PipelineStoppedException] { throw }
    catch [IsePxGridException] { throw }
    catch {
        throw [IsePxGridException]::new(
            "pxGrid $Operation failed: $($_.Exception.Message)",
            @{ Datasource = 'PxGrid'; Operation = $Operation; Target = $Target
               Uri = $Uri.AbsoluteUri; CorrelationId = $Correlation.CorrelationId
               RequestId = $requestId },
            $_.Exception
        )
    }
    finally {
        $timer.Stop()
        $null = Write-IseLogEvent -Level Debug -EventId 'pxgrid.request.completed' `
            -Message "pxGrid $Operation request completed." -Correlation $Correlation `
            -RequestId $requestId -Datasource PxGrid -Operation $Operation -Target $Target `
            -Uri $Uri -DurationMilliseconds $timer.Elapsed.TotalMilliseconds
    }
}
