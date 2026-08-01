class IseSession : System.IDisposable {
    [uri] $ServerUri
    [pscredential] $Credential
    [bool] $SkipCertificateCheck
    [System.Net.Http.HttpClient] $HttpClient
    [datetime] $ConnectedAt
    [string] $ConnectionId
    [string] $ServerVersion
    [hashtable] $Capabilities
    [hashtable] $DatasourceState
    [bool] $Disposed

    IseSession(
        [uri] $serverUri,
        [pscredential] $credential,
        [bool] $skipCertificateCheck,
        [System.Net.Http.HttpClient] $httpClient
    ) {
        $this.ServerUri = $serverUri
        $this.Credential = $credential
        $this.SkipCertificateCheck = $skipCertificateCheck
        $this.HttpClient = $httpClient
        $this.ConnectedAt = [datetime]::UtcNow
        $this.ConnectionId = [guid]::NewGuid().ToString('N')
        $this.Capabilities = @{}
        $this.DatasourceState = @{}
        $this.Disposed = $false
    }

    [void] Dispose() {
        if ($this.Disposed) { return }
        if ($null -ne $this.HttpClient) { $this.HttpClient.Dispose() }
        $this.Credential = $null
        $this.Disposed = $true
    }
}
