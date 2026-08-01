function Receive-IseWebSocketText {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [System.Net.WebSockets.ClientWebSocket] $Socket,
        [System.Threading.CancellationToken] $CancellationToken = [System.Threading.CancellationToken]::None,
        [ValidateRange(0, 60000)] [int] $TimeoutMilliseconds
    )
    $buffer = [byte[]]::new(8192)
    $stream = [System.IO.MemoryStream]::new()
    $timeoutSource = $null
    try {
        if ($TimeoutMilliseconds -gt 0 -and -not $CancellationToken.CanBeCanceled) {
            $timeoutSource = [System.Threading.CancellationTokenSource]::new($TimeoutMilliseconds)
            $CancellationToken = $timeoutSource.Token
        }
        do {
            $segment = [ArraySegment[byte]]::new($buffer)
            $result = $Socket.ReceiveAsync($segment, $CancellationToken).GetAwaiter().GetResult()
            if ($result.MessageType -eq [System.Net.WebSockets.WebSocketMessageType]::Close) {
                return $null
            }
            $stream.Write($buffer, 0, $result.Count)
        } until ($result.EndOfMessage)
        [System.Text.Encoding]::UTF8.GetString($stream.ToArray())
    }
    catch [System.OperationCanceledException] {
        if ($timeoutSource -and $timeoutSource.IsCancellationRequested) { return '' }
        throw
    }
    finally {
        if ($timeoutSource) { $timeoutSource.Dispose() }
        $stream.Dispose()
    }
}
