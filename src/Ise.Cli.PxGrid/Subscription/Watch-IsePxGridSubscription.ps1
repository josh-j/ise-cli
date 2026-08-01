function Watch-IsePxGridSubscription {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [IseSession] $Session,
        [Parameter(Mandatory)] $Descriptor,
        [Parameter(Mandatory)] [string] $Topic,
        [int] $First,
        [switch] $Reconnect,
        [ValidateRange(0, 300)] [int] $ReconnectDelaySec = 2,
        $Correlation
    )

    if ($Session.DatasourceState.ContainsKey('PxGrid.Executor')) {
        $requestId = [guid]::NewGuid().ToString('N')
        $executor = $Session.DatasourceState['PxGrid.Executor']
        $count = 0
        $null = Write-IseLogEvent -Level Information -EventId 'pxgrid.subscription.started' `
            -Message "pxGrid subscription '$Topic' started." -Correlation $Correlation `
            -RequestId $requestId -Datasource PxGrid -Operation Subscribe -Target $Topic
        try {
            & $executor -Operation Subscribe -Uri $Descriptor.WebSocketUrl -Body @{ topic = $Topic } `
                -PeerNodeName $Descriptor.NodeName -Target $Descriptor.Service | ForEach-Object {
                if ($First -le 0 -or $count -lt $First) {
                    $_ | Add-IsePxGridMetadata -Descriptor $Descriptor -Operation Subscribe `
                        -Correlation $Correlation
                    $count++
                }
            }
        }
        finally {
            $null = Write-IseLogEvent -Level Information -EventId 'pxgrid.subscription.completed' `
                -Message "pxGrid subscription '$Topic' completed with $count records." `
                -Correlation $Correlation -RequestId $requestId -Datasource PxGrid `
                -Operation Subscribe -Target $Topic -RecordCount $count
        }
        return
    }

    $emitted = 0
    do {
        $requestId = [guid]::NewGuid().ToString('N')
        $attemptSucceeded = $false
        $null = Write-IseLogEvent -Level Information -EventId 'pxgrid.subscription.started' `
            -Message "pxGrid subscription '$Topic' connection started." `
            -Correlation $Correlation -RequestId $requestId -Datasource PxGrid `
            -Operation Subscribe -Target $Topic -Uri $Descriptor.WebSocketUrl
        $socket = [System.Net.WebSockets.ClientWebSocket]::new()
        $sockets = if ($Session.DatasourceState.ContainsKey('PxGrid.WebSockets')) {
            $Session.DatasourceState['PxGrid.WebSockets']
        } else {
            $newSockets = [System.Collections.Generic.List[object]]::new()
            $Session.DatasourceState['PxGrid.WebSockets'] = $newSockets
            $newSockets
        }
        $sockets.Add($socket)
        try {
            if ($Session.DatasourceState.ContainsKey('PxGrid.Certificate')) {
                $null = $socket.Options.ClientCertificates.Add(
                    $Session.DatasourceState['PxGrid.Certificate']
                )
            }
            if ($Session.SkipCertificateCheck) {
                $socket.Options.RemoteCertificateValidationCallback = {
                    param($sender, $certificate, $chain, $errors)
                    $true
                }
            }
            $socket.ConnectAsync(
                [uri]$Descriptor.WebSocketUrl,
                [System.Threading.CancellationToken]::None
            ).GetAwaiter().GetResult()
            $secret = Get-IsePxGridAccessSecret -Session $Session `
                -PeerNodeName $Descriptor.NodeName -Correlation $Correlation
            $config = $Session.DatasourceState['PxGrid.Config']
            $connectFrame = "CONNECT`naccept-version:1.2`nhost:$($Session.ServerUri.DnsSafeHost)`nlogin:$($config.ClientName)`npasscode:$secret`nheart-beat:10000,10000`n`n$([char]0)"
            Send-IseWebSocketText -Socket $socket -Text $connectFrame
            $connectedText = Receive-IseWebSocketText -Socket $socket -TimeoutMilliseconds 10000
            if ([string]::IsNullOrWhiteSpace($connectedText)) {
                throw 'Timed out waiting for the STOMP CONNECTED frame.'
            }
            $connected = ConvertFrom-IseStompFrame -Frame $connectedText
            if ($connected.Command -ne 'CONNECTED') {
                throw "Expected STOMP CONNECTED but received '$($connected.Command)'."
            }
            $null = Write-IseLogEvent -Level Information -EventId 'pxgrid.subscription.connected' `
                -Message "pxGrid subscription '$Topic' connected." -Correlation $Correlation `
                -RequestId $requestId -Datasource PxGrid -Operation Subscribe `
                -Target $Topic -Uri $Descriptor.WebSocketUrl
            $subscriptionId = [guid]::NewGuid().ToString('N')
            $subscribeFrame = "SUBSCRIBE`nid:$subscriptionId`ndestination:$Topic`nack:auto`n`n$([char]0)"
            Send-IseWebSocketText -Socket $socket -Text $subscribeFrame
            while ($socket.State -eq [System.Net.WebSockets.WebSocketState]::Open) {
                $text = Receive-IseWebSocketText -Socket $socket -TimeoutMilliseconds 1000
                if ($null -eq $text) { break }
                if ([string]::IsNullOrWhiteSpace($text)) { continue }
                $frame = ConvertFrom-IseStompFrame -Frame $text
                if ($frame.Command -eq 'ERROR') { throw "STOMP error: $($frame.Body)" }
                if ($frame.Command -ne 'MESSAGE') { continue }
                $value = try { $frame.Body | ConvertFrom-Json -Depth 100 } catch { $frame.Body }
                $value | Add-IsePxGridMetadata -Descriptor $Descriptor -Operation Subscribe `
                    -Correlation $Correlation
                $emitted++
                if ($First -gt 0 -and $emitted -ge $First) {
                    $attemptSucceeded = $true
                    return
                }
            }
            $attemptSucceeded = $true
        }
        catch [System.Management.Automation.PipelineStoppedException] { throw }
        catch {
            $null = Write-IseLogEvent -Level Error -EventId 'pxgrid.subscription.failed' `
                -Message "pxGrid subscription '$Topic' failed: $($_.Exception.Message)" `
                -Correlation $Correlation -RequestId $requestId -Datasource PxGrid `
                -Operation Subscribe -Target $Topic -Uri $Descriptor.WebSocketUrl `
                -Exception $_.Exception
            if (-not $Reconnect) {
                throw [IsePxGridException]::new(
                    "pxGrid subscription failed: $($_.Exception.Message)",
                    @{ Datasource = 'PxGrid'; Operation = 'Subscribe'; Target = $Topic
                       CorrelationId = $Correlation.CorrelationId; RequestId = $requestId
                       Uri = $Descriptor.WebSocketUrl },
                    $_.Exception
                )
            }
            $null = Write-IseLogEvent -Level Warning -EventId 'pxgrid.subscription.reconnecting' `
                -Message "pxGrid subscription '$Topic' is reconnecting." `
                -Correlation $Correlation -RequestId $requestId -Datasource PxGrid -Operation Subscribe `
                -Target $Topic -Exception $_.Exception
            if ($ReconnectDelaySec -gt 0) { Start-Sleep -Seconds $ReconnectDelaySec }
        }
        finally {
            $null = $sockets.Remove($socket)
            if ($socket.State -eq [System.Net.WebSockets.WebSocketState]::Open) {
                try {
                    $disconnect = "DISCONNECT`nreceipt:close`n`n$([char]0)"
                    Send-IseWebSocketText -Socket $socket -Text $disconnect
                } catch { Write-Debug "Could not send STOMP disconnect: $($_.Exception.Message)" }
            }
            $socket.Dispose()
            $null = Write-IseLogEvent -Level Information -EventId 'pxgrid.subscription.completed' `
                -Message "pxGrid subscription '$Topic' connection ended." `
                -Correlation $Correlation -RequestId $requestId -Datasource PxGrid `
                -Operation Subscribe -Target $Topic -Uri $Descriptor.WebSocketUrl `
                -RecordCount $emitted -Properties @{ Succeeded = $attemptSucceeded }
        }
    } while ($Reconnect)
}
