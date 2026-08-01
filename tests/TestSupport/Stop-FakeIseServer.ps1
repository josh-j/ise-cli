function Stop-FakeIseServer {
    [CmdletBinding()]
    param([Parameter(Mandatory, ValueFromPipeline)] $Server)
    process {
        try {
            $client = [System.Net.Http.HttpClient]::new()
            $null = $client.GetAsync([uri]::new($Server.Uri, '/__stop')).GetAwaiter().GetResult()
            $client.Dispose()
        }
        catch { Write-Verbose "Fake ISE stop request failed: $($_.Exception.Message)" }
        Wait-Job -Job $Server.Job -Timeout 5 | Out-Null
        Receive-Job -Job $Server.Job -ErrorAction SilentlyContinue | Out-Null
        Remove-Job -Job $Server.Job -Force -ErrorAction SilentlyContinue
    }
}
