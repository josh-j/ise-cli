function New-IsePxGridClient {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [IseSession] $Session)

    if ($Session.DatasourceState.ContainsKey('PxGrid.HttpClient')) {
        return $Session.DatasourceState['PxGrid.HttpClient']
    }
    if (-not $Session.DatasourceState.ContainsKey('PxGrid.Config')) {
        throw [IsePxGridException]::new(
            'pxGrid is not configured. Pass -PxGridClientName and certificate settings to Connect-Ise.',
            @{ Datasource = 'PxGrid'; Operation = 'Connect' }
        )
    }
    $config = $Session.DatasourceState['PxGrid.Config']
    try {
        $handler = [System.Net.Http.HttpClientHandler]::new()
        if ($config.CertificatePath) {
            $certificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new(
                $config.CertificatePath,
                $config.CertificatePassword,
                [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::EphemeralKeySet
            )
            $null = $handler.ClientCertificates.Add($certificate)
            $Session.DatasourceState['PxGrid.Certificate'] = $certificate
        }
        if ($Session.SkipCertificateCheck) {
            $handler.ServerCertificateCustomValidationCallback = {
                param($message, $certificate, $chain, $errors)
                $true
            }
        }
        $client = [System.Net.Http.HttpClient]::new($handler, $true)
        $client.Timeout = $Session.HttpClient.Timeout
        $Session.DatasourceState['PxGrid.HttpClient'] = $client
        $client
    }
    catch {
        throw [IsePxGridException]::new(
            "Could not create the pxGrid client: $($_.Exception.Message)",
            @{ Datasource = 'PxGrid'; Operation = 'Connect' },
            $_.Exception
        )
    }
}
