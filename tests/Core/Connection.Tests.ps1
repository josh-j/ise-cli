BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '../../src/Ise.Cli/Ise.Cli.psd1'
    if (-not (Get-Module Ise.Cli)) { Import-Module $modulePath -Force }
    . (Join-Path $PSScriptRoot '../TestSupport/Start-FakeIseServer.ps1')
    . (Join-Path $PSScriptRoot '../TestSupport/Stop-FakeIseServer.ps1')
    $credential = [pscredential]::new(
        'test-user',
        (ConvertTo-SecureString 'test-password' -AsPlainText -Force)
    )
}

Describe 'ISE connection lifecycle' {
    BeforeEach {
        $routes = @{
            '/ers/config/endpoint?size=1' = @{
                Body = '{"SearchResult":{"total":0,"resources":[]}}'
            }
            '/api/swagger-resources' = @{ Body = '[]' }
            '/admin/API/mnt/Version' = @{
                ContentType = 'application/xml'
                Body = '<versionInfo><version>3.3.0</version></versionInfo>'
            }
        }
        $server = Start-FakeIseServer -Routes $routes
    }

    AfterEach {
        Disconnect-Ise -InformationAction SilentlyContinue
        if ($server) { Stop-FakeIseServer $server; $server = $null }
    }

    It 'returns no connection before Connect-Ise' {
        Get-IseConnection | Should -BeNullOrEmpty
    }

    It 'creates one active typed connection view' {
        $connection = Connect-Ise -Server $server.Uri `
            -Credential $credential -InformationAction SilentlyContinue
        $connection.Server.AbsoluteUri | Should -Be $server.Uri.AbsoluteUri
        $connection.ConnectionId | Should -Not -BeNullOrEmpty
        $connection.PSObject.TypeNames | Should -Contain 'Ise.Connection'
        $connection.ServerVersion | Should -Be '3.3.0'
        $connection.Capabilities['Rest.Ers'] | Should -BeTrue
        $connection.Capabilities['Rest.OpenApi'] | Should -BeTrue
        $connection.Capabilities['Rest.Mnt'] | Should -BeTrue
    }

    It 'disposes the previous session when connecting twice' {
        $one = [uri]::new($server.Uri, 'one')
        $two = [uri]::new($server.Uri, 'two')
        Connect-Ise -Server $one -Credential $credential `
            -InformationAction SilentlyContinue | Out-Null
        $module = Get-Module Ise.Cli
        $first = & $module { $script:IseSession }
        Connect-Ise -Server $two -Credential $credential `
            -InformationAction SilentlyContinue | Out-Null
        $first.Disposed | Should -BeTrue
        (Get-IseConnection).Server.AbsolutePath | Should -Be '/two'
    }

    It 'allows Disconnect-Ise to be called twice' {
        Connect-Ise -Server $server.Uri -Credential $credential `
            -InformationAction SilentlyContinue | Out-Null
        { Disconnect-Ise -InformationAction SilentlyContinue } | Should -Not -Throw
        { Disconnect-Ise -InformationAction SilentlyContinue } | Should -Not -Throw
        Get-IseConnection | Should -BeNullOrEmpty
    }

    It 'scopes certificate bypass to the active session' {
        $one = [uri]::new($server.Uri, 'one')
        $two = [uri]::new($server.Uri, 'two')
        Connect-Ise -Server $one -Credential $credential `
            -SkipCertificateCheck -InformationAction SilentlyContinue | Out-Null
        (Get-IseConnection).SkipCertificateCheck | Should -BeTrue
        Connect-Ise -Server $two -Credential $credential `
            -InformationAction SilentlyContinue | Out-Null
        (Get-IseConnection).SkipCertificateCheck | Should -BeFalse
    }

    It 'returns a structured authentication error when a connection probe is rejected' {
        Stop-FakeIseServer $server
        $server = Start-FakeIseServer -Routes @{
            '/ers/config/endpoint?size=1' = @{ StatusCode = 401; Body = '{"error":"unauthorized"}' }
            '/api/swagger-resources' = @{ StatusCode = 401; Body = '{"error":"unauthorized"}' }
            '/admin/API/mnt/Version' = @{ StatusCode = 401; Body = '{"error":"unauthorized"}' }
        }
        { Connect-Ise $server.Uri $credential -ErrorAction Stop -InformationAction SilentlyContinue } |
            Should -Throw -ErrorId 'Ise.Rest.AuthenticationFailed,Connect-Ise'
        Get-IseConnection | Should -BeNullOrEmpty
    }

    It 'returns a structured transport error when the server is unreachable' {
        $unusedEndpoint = [System.Net.Sockets.Socket]::new(
            [System.Net.Sockets.AddressFamily]::InterNetwork,
            [System.Net.Sockets.SocketType]::Stream,
            [System.Net.Sockets.ProtocolType]::Tcp
        )
        try {
            $unusedEndpoint.Bind(
                [System.Net.IPEndPoint]::new([System.Net.IPAddress]::Loopback, 0)
            )
            $port = ([System.Net.IPEndPoint]$unusedEndpoint.LocalEndPoint).Port
            $unreachable = [uri]"http://127.0.0.1:$port/"
            $transportError = try {
                Connect-Ise $unreachable $credential -TimeoutSec 1 -ErrorAction Stop `
                    -InformationAction SilentlyContinue
            }
            catch { $_ }
            $transportError | Should -Not -BeNullOrEmpty
            $transportError.FullyQualifiedErrorId | Should -BeIn @(
                'Ise.Connection.Unavailable,Connect-Ise',
                'Ise.Rest.RequestTimeout,Connect-Ise'
            )
            Get-IseConnection | Should -BeNullOrEmpty
        }
        finally { $unusedEndpoint.Dispose() }
    }

    It 'routes adapter-declared connection parameters without Core protocol branches' {
        Connect-Ise $server.Uri $credential `
            -DataConnectConnectionString 'Data Source=ise-reporting' `
            -InformationAction SilentlyContinue | Out-Null
        $module = Get-Module Ise.Cli
        $config = & $module { $script:IseSession.DatasourceState['DataConnect.Config'] }
        $config.ConnectionString | Should -Be 'Data Source=ise-reporting'
        $config.Provider | Should -Be 'Oracle.ManagedDataAccess.Client'
    }
}
