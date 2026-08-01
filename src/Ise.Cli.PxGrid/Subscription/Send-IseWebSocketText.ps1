function Send-IseWebSocketText {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [System.Net.WebSockets.ClientWebSocket] $Socket,
        [Parameter(Mandatory)] [string] $Text,
        [System.Threading.CancellationToken] $CancellationToken = [System.Threading.CancellationToken]::None
    )
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    $segment = [ArraySegment[byte]]::new($bytes)
    $Socket.SendAsync(
        $segment,
        [System.Net.WebSockets.WebSocketMessageType]::Text,
        $true,
        $CancellationToken
    ).GetAwaiter().GetResult()
}
