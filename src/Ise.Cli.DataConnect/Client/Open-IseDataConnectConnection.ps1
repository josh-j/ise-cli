function Open-IseDataConnectConnection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [IseSession] $Session,
        $Correlation
    )

    if ($Session.DatasourceState.ContainsKey('DataConnect.Connection')) {
        $existing = $Session.DatasourceState['DataConnect.Connection']
        if ($existing.State -eq [System.Data.ConnectionState]::Open) { return $existing }
        $existing.Dispose()
        $Session.DatasourceState.Remove('DataConnect.Connection')
    }
    if (-not $Session.DatasourceState.ContainsKey('DataConnect.Config')) {
        throw [IseDataConnectException]::new(
            'Data Connect is not configured. Pass -DataConnectConnectionString to Connect-Ise.',
            @{ Datasource = 'DataConnect'; Operation = 'Connect' }
        )
    }
    $config = $Session.DatasourceState['DataConnect.Config']
    try {
        if ($config.AssemblyPath) { Add-Type -Path $config.AssemblyPath -ErrorAction Stop }
        $factory = $null
        try { $factory = [System.Data.Common.DbProviderFactories]::GetFactory($config.Provider) }
        catch {
            $providerType = [type]::GetType(
                'Oracle.ManagedDataAccess.Client.OracleClientFactory, Oracle.ManagedDataAccess',
                $false
            )
            if ($providerType) {
                $instanceProperty = $providerType.GetProperty('Instance')
                $instanceField = $providerType.GetField('Instance')
                if ($instanceProperty) { $factory = $instanceProperty.GetValue($null) }
                elseif ($instanceField) { $factory = $instanceField.GetValue($null) }
                else { throw "Provider type '$($providerType.FullName)' exposes no Instance member." }
            }
            else { throw }
        }
        $connection = $factory.CreateConnection()
        if ($null -eq $connection) { throw "Provider '$($config.Provider)' returned no connection." }
        $builder = [System.Data.Common.DbConnectionStringBuilder]::new()
        $builder.ConnectionString = $config.ConnectionString
        if ($config.Credential) {
            $network = $config.Credential.GetNetworkCredential()
            $builder['User Id'] = $network.UserName
            $builder['Password'] = $network.Password
        }
        $connection.ConnectionString = $builder.ConnectionString
        $connection.Open()
        $Session.DatasourceState['DataConnect.Connection'] = $connection
        $Session.Capabilities['DataConnect'] = $true
        $null = Write-IseLogEvent -Level Information -EventId 'dataconnect.connection.opened' `
            -Message 'Data Connect connection opened.' -Correlation $Correlation `
            -Datasource DataConnect -Operation Connect
        $connection
    }
    catch {
        throw [IseDataConnectException]::new(
            "Could not open Data Connect: $($_.Exception.Message)",
            @{ Datasource = 'DataConnect'; Operation = 'Connect'; Provider = $config.Provider },
            $_.Exception
        )
    }
}
