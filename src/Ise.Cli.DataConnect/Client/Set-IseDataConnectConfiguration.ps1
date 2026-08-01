function Set-IseDataConnectConfiguration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [IseSession] $Session,
        [Parameter(Mandatory)] [hashtable] $Arguments,
        $Correlation
    )

    if (-not $Arguments.ContainsKey('DataConnectConnectionString') -or
        [string]::IsNullOrWhiteSpace([string]$Arguments.DataConnectConnectionString)) {
        throw [System.ArgumentException]::new(
            '-DataConnectConnectionString is required when configuring Data Connect.'
        )
    }
    $Session.DatasourceState['DataConnect.Config'] = @{
        ConnectionString = [string]$Arguments.DataConnectConnectionString
        Credential = if ($Arguments.ContainsKey('DataConnectCredential')) {
            $Arguments.DataConnectCredential
        } else { $null }
        Provider = if ($Arguments.ContainsKey('DataConnectProvider') -and
            $Arguments.DataConnectProvider) {
            [string]$Arguments.DataConnectProvider
        } else { 'Oracle.ManagedDataAccess.Client' }
        AssemblyPath = if ($Arguments.ContainsKey('DataConnectAssemblyPath')) {
            [string]$Arguments.DataConnectAssemblyPath
        } else { $null }
    }
}
