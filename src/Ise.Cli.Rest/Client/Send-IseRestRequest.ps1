function Send-IseRestRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [IseSession] $Session,
        [Parameter(Mandatory)] [string] $Path,
        [hashtable] $Query,
        [hashtable] $Headers,
        $Correlation,
        [string] $Datasource,
        [string] $Operation = 'Get',
        [string] $Target,
        [string] $Accept = 'application/json',
        [Nullable[int]] $Page
    )

    $uri = New-IseRestUri -Session $Session -Path $Path -Query $Query
    $requestId = [guid]::NewGuid().ToString('N')
    $request = [System.Net.Http.HttpRequestMessage]::new(
        [System.Net.Http.HttpMethod]::Get,
        $uri
    )
    $credentialKey = "Credential.$Datasource"
    $requestCredential = if ($Session.DatasourceState.ContainsKey($credentialKey)) {
        [pscredential]$Session.DatasourceState[$credentialKey]
    } else { $Session.Credential }
    $credential = $requestCredential.GetNetworkCredential()
    $token = [Convert]::ToBase64String(
        [Text.Encoding]::UTF8.GetBytes("$($credential.UserName):$($credential.Password)")
    )
    $request.Headers.Authorization = [System.Net.Http.Headers.AuthenticationHeaderValue]::new(
        'Basic', $token
    )
    $callerSpecifiedAccept = $Headers -and @($Headers.Keys | Where-Object {
        [string]$_ -ieq 'Accept'
    }).Count -gt 0
    if (-not $callerSpecifiedAccept) {
        $request.Headers.Accept.Add(
            [System.Net.Http.Headers.MediaTypeWithQualityHeaderValue]::new($Accept)
        )
    }
    if ($Headers) {
        foreach ($name in @($Headers.Keys)) {
            if ($name -ieq 'Authorization') { continue }
            $null = $request.Headers.TryAddWithoutValidation([string]$name, @($Headers[$name]))
        }
    }

    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    $response = $null
    $null = Write-IseLogEvent -Level Debug -EventId 'rest.request.started' `
        -Message "GET $uri" -Correlation $Correlation -RequestId $requestId `
        -Datasource $Datasource -Operation $Operation -Target $Target `
        -Uri $uri.AbsoluteUri -Page $Page
    try {
        $response = $Session.HttpClient.SendAsync($request).GetAwaiter().GetResult()
        $bodyBytes = $response.Content.ReadAsByteArrayAsync().GetAwaiter().GetResult()
        $contentTypeHeader = $response.Content.Headers.ContentType
        $charset = if ($contentTypeHeader) { [string]$contentTypeHeader.CharSet } else { $null }
        $encoding = if ($charset) {
            try { [System.Text.Encoding]::GetEncoding($charset.Trim('"')) }
            catch { [System.Text.Encoding]::UTF8 }
        } else { [System.Text.Encoding]::UTF8 }
        $body = $encoding.GetString($bodyBytes)
        $timer.Stop()
        $responseHeaders = @{}
        foreach ($header in $response.Headers) { $responseHeaders[$header.Key] = @($header.Value) }
        foreach ($header in $response.Content.Headers) { $responseHeaders[$header.Key] = @($header.Value) }
        $contentType = [string]$contentTypeHeader
        $context = @{
            Datasource    = $Datasource
            Operation     = $Operation
            Target        = $Target
            Uri           = $uri.AbsoluteUri
            StatusCode    = [int]$response.StatusCode
            ResponseHeaders = $responseHeaders
            ResponseBody  = $body
            CorrelationId = $Correlation.CorrelationId
            RequestId     = $requestId
            Page          = $Page
        }
        if (-not $response.IsSuccessStatusCode) {
            $null = Write-IseLogEvent -Level Error -EventId 'rest.request.failed' `
                -Message "GET $uri returned HTTP $([int]$response.StatusCode)." `
                -Correlation $Correlation -RequestId $requestId -Datasource $Datasource `
                -Operation $Operation -Target $Target -Uri $uri.AbsoluteUri -Page $Page `
                -StatusCode ([int]$response.StatusCode) `
                -DurationMilliseconds $timer.Elapsed.TotalMilliseconds
            throw (New-IseHttpException -StatusCode ([int]$response.StatusCode) `
                -Uri $uri -ResponseBody $body -Context $context)
        }
        $parsed = ConvertFrom-IseRestResponse -Body $body -ContentType $contentType -Context $context
        $null = Write-IseLogEvent -Level Debug -EventId 'rest.request.completed' `
            -Message "GET $uri completed with HTTP $([int]$response.StatusCode)." `
            -Correlation $Correlation -RequestId $requestId -Datasource $Datasource `
            -Operation $Operation -Target $Target -Uri $uri.AbsoluteUri -Page $Page `
            -StatusCode ([int]$response.StatusCode) `
            -DurationMilliseconds $timer.Elapsed.TotalMilliseconds
        [pscustomobject]@{
            PSTypeName           = 'Ise.Rest.TransportResponse'
            RequestUri           = $uri
            StatusCode           = [int]$response.StatusCode
            Headers              = $responseHeaders
            ContentType          = $contentType
            BodyText             = $body
            BodyBytes            = $bodyBytes
            BodyObject           = $parsed
            DurationMilliseconds = $timer.Elapsed.TotalMilliseconds
            RequestId            = $requestId
        }
    }
    catch [IseException] { throw }
    catch [System.Threading.Tasks.TaskCanceledException] {
        $timer.Stop()
        throw [IseConnectionException]::new(
            "ISE request timed out for $uri.",
            @{ Datasource = $Datasource; Operation = $Operation; Target = $Target
               Uri = $uri.AbsoluteUri; CorrelationId = $Correlation.CorrelationId
               RequestId = $requestId; Page = $Page; FailureKind = 'Timeout' },
            $_.Exception
        )
    }
    catch [System.Net.Http.HttpRequestException] {
        $timer.Stop()
        $inner = $_.Exception
        $certificateFailure = $false
        while ($inner) {
            if ($inner -is [System.Security.Authentication.AuthenticationException]) {
                $certificateFailure = $true
                break
            }
            $inner = $inner.InnerException
        }
        $context = @{ Datasource = $Datasource; Operation = $Operation; Target = $Target
                      Uri = $uri.AbsoluteUri; CorrelationId = $Correlation.CorrelationId
                      RequestId = $requestId; Page = $Page }
        if ($certificateFailure) {
            throw [IseCertificateException]::new(
                "Certificate validation failed for $uri.", $context, $_.Exception)
        }
        throw [IseConnectionException]::new(
            "Could not reach ISE at ${uri}: $($_.Exception.Message)",
            $context,
            $_.Exception
        )
    }
    finally {
        $request.Dispose()
        if ($response) { $response.Dispose() }
    }
}
