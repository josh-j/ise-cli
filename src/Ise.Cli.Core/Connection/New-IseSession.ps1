function New-IseSession {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [uri] $Server,
        [Parameter(Mandatory)] [pscredential] $Credential,
        [switch] $SkipCertificateCheck,
        [ValidateRange(1, 86400)] [int] $TimeoutSec = 100
    )

    $absoluteServer = if ($Server.IsAbsoluteUri) {
        $Server
    } else {
        [uri]::new("https://$($Server.OriginalString.Trim('/'))")
    }
    $builder = [System.UriBuilder]::new($absoluteServer)
    $loopback = $builder.Host -in @('localhost', '127.0.0.1', '::1')
    if ($builder.Scheme -ne 'https' -and -not ($builder.Scheme -eq 'http' -and $loopback)) {
        throw [System.ArgumentException]::new('Server must use HTTPS.')
    }
    $builder.Path = $builder.Path.TrimEnd('/')
    $normalized = $builder.Uri
    $client = New-IseHttpClient -Credential $Credential `
        -SkipCertificateCheck:$SkipCertificateCheck -TimeoutSec $TimeoutSec
    [IseSession]::new($normalized, $Credential, $SkipCertificateCheck, $client)
}
