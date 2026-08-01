function Start-FakeIseServer {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [hashtable] $Routes,
        [int] $Port
    )

    if ($Port -le 0) {
        $portReservation = [System.Net.Sockets.TcpListener]::new(
            [System.Net.IPAddress]::Loopback,
            0
        )
        try {
            $portReservation.Start()
            $Port = ([System.Net.IPEndPoint]$portReservation.LocalEndpoint).Port
        }
        finally { $portReservation.Stop() }
    }
    $prefix = "http://127.0.0.1:$Port/"
    $job = Start-ThreadJob -ArgumentList $prefix, $Routes -ScriptBlock {
        param($Prefix, $Routes)
        $listener = [System.Net.HttpListener]::new()
        $listener.Prefixes.Add($Prefix)
        try {
            $listener.Start()
            'READY'
            while ($listener.IsListening) {
                $context = $listener.GetContext()
                $request = $context.Request
                $response = $context.Response
                if ($request.Url.AbsolutePath -eq '/__stop') {
                    $response.StatusCode = 204
                    $response.Close()
                    break
                }
                $key = $request.Url.PathAndQuery
                $route = $Routes[$key]
                if ($null -eq $route) { $route = $Routes[$request.Url.AbsolutePath] }
                if ($null -eq $route) {
                    $response.StatusCode = 404
                    $response.ContentType = 'application/json'
                    $body = '{"error":"not_found"}'
                } elseif ($route.ExpectedAccept -and
                    $request.AcceptTypes -notcontains [string]$route.ExpectedAccept) {
                    $response.StatusCode = 406
                    $response.ContentType = 'application/json'
                    $body = '{"error":"unsupported_accept"}'
                } else {
                    $response.StatusCode = if ($route.StatusCode) { $route.StatusCode } else { 200 }
                    if (-not $route.OmitContentType) {
                        $response.ContentType = if ($route.ContentType) {
                            $route.ContentType
                        } else { 'application/json' }
                    }
                    $body = [string]$route.Body
                }
                $bytes = [Text.Encoding]::UTF8.GetBytes($body)
                $response.ContentLength64 = $bytes.Length
                $response.OutputStream.Write($bytes, 0, $bytes.Length)
                $response.Close()
            }
        }
        finally {
            if ($listener.IsListening) { $listener.Stop() }
            $listener.Close()
        }
    }

    $ready = $false
    for ($attempt = 0; $attempt -lt 250; $attempt++) {
        if ($job.State -in @('Failed', 'Completed', 'Stopped')) { break }
        $output = @(Receive-Job -Job $job -Keep)
        if ($output -contains 'READY') { $ready = $true; break }
        Start-Sleep -Milliseconds 20
    }
    if (-not $ready) {
        $reason = @(Receive-Job -Job $job -Keep -ErrorAction SilentlyContinue) -join [Environment]::NewLine
        Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
        throw "Fake ISE server failed to start at $prefix. $reason"
    }
    [pscustomobject]@{
        PSTypeName = 'Ise.TestServer'
        Uri        = [uri]$prefix
        Port       = $Port
        Job        = $job
    }
}
