function Set-IsePxGridConfiguration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [IseSession] $Session,
        [Parameter(Mandatory)] [hashtable] $Arguments,
        $Correlation
    )

    if (-not $Arguments.ContainsKey('PxGridClientName') -or
        [string]::IsNullOrWhiteSpace([string]$Arguments.PxGridClientName)) {
        throw [System.ArgumentException]::new(
            '-PxGridClientName is required when configuring pxGrid.'
        )
    }
    $Session.DatasourceState['PxGrid.Config'] = @{
        ControlUri = if ($Arguments.ContainsKey('PxGridControlUri')) {
            $Arguments.PxGridControlUri
        } else { $null }
        ClientName = [string]$Arguments.PxGridClientName
        CertificatePath = if ($Arguments.ContainsKey('PxGridCertificatePath')) {
            [string]$Arguments.PxGridCertificatePath
        } else { $null }
        CertificatePassword = if ($Arguments.ContainsKey('PxGridCertificatePassword')) {
            $Arguments.PxGridCertificatePassword
        } else { $null }
    }
}
