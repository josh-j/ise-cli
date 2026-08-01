function New-IseHttpClient {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [pscredential] $Credential,
        [switch] $SkipCertificateCheck,
        [ValidateRange(1, 86400)] [int] $TimeoutSec = 100
    )

    $handler = [System.Net.Http.HttpClientHandler]::new()
    $handler.Credentials = $Credential.GetNetworkCredential()
    $handler.PreAuthenticate = $true
    if ($SkipCertificateCheck) {
        $handler.ServerCertificateCustomValidationCallback =
            [System.Net.Http.HttpClientHandler]::DangerousAcceptAnyServerCertificateValidator
    }
    $client = [System.Net.Http.HttpClient]::new($handler, $true)
    $client.Timeout = [timespan]::FromSeconds($TimeoutSec)
    $client.DefaultRequestHeaders.UserAgent.ParseAdd('ise-cli/0.1.0')
    $client
}
