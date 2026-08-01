BeforeAll {
    . (Join-Path $PSScriptRoot '../TestSupport/Start-FakeIseServer.ps1')
    . (Join-Path $PSScriptRoot '../TestSupport/Stop-FakeIseServer.ps1')
    $modulePath = Join-Path $PSScriptRoot '../../src/Ise.Cli/Ise.Cli.psd1'
    if (-not (Get-Module Ise.Cli)) { Import-Module $modulePath -Force }
    . (Join-Path $PSScriptRoot '../TestSupport/Open-TestIseSession.ps1')
    $credential = [pscredential]::new('u', (ConvertTo-SecureString 'p' -AsPlainText -Force))
}

Describe 'REST resource discovery' {
    AfterEach {
        Disconnect-Ise -InformationAction SilentlyContinue
        if ($server) { Stop-FakeIseServer $server; $server = $null }
    }

    It 'loads bundled ERS descriptors with provenance' {
        Open-TestIseSession -Credential $credential
        $schema = @(Get-IseRestSchema -Ers Endpoint -InformationAction SilentlyContinue)
        $schema.Count | Should -Be 1
        $schema[0].CollectionPath | Should -Be '/ers/config/endpoint'
        $schema[0].SchemaSource | Should -Be 'Bundled'
    }

    It 'supports wildcard schema selection' {
        Open-TestIseSession -Credential $credential
        @(Get-IseRestSchema -Ers '*Group' -InformationAction SilentlyContinue).Count |
            Should -BeGreaterThan 1
    }

    It 'discovers the complete ERS collection surface from live Swagger' {
        $routes = @{
            '/ers/config/endpoint' = @{ Body = '{"SearchResult":{"total":0,"resources":[]}}' }
            '/api/swagger-resources' = @{ Body = @(
                @{ name = 'ERS'; location = '/ers/openapi.json' }
            ) | ConvertTo-Json -Compress }
            '/ers/openapi.json' = @{ Body = @{
                openapi = '3.0.0'
                paths = [ordered]@{
                    '/ers/config/endpoint' = @{ get = @{ operationId = 'getEndpoints' } }
                    '/ers/config/endpoint/{id}' = @{ get = @{ operationId = 'getEndpointById' } }
                    '/ers/config/custom-widget' = @{ get = @{ operationId = 'getWidgets' } }
                }
            } | ConvertTo-Json -Depth 8 -Compress }
        }
        $server = Start-FakeIseServer -Routes $routes
        Connect-Ise $server.Uri $credential -InformationAction SilentlyContinue | Out-Null

        $schema = @(Get-IseRestSchema -Ers Endpoint, CustomWidget -Refresh `
            -InformationAction SilentlyContinue)
        $schema.Count | Should -Be 2
        @($schema | Where-Object SchemaSource -EQ Live).Count | Should -Be 2
        ($schema | Where-Object Name -EQ Endpoint).CanGetById | Should -BeTrue
        ($schema | Where-Object Name -EQ CustomWidget).CollectionPath |
            Should -Be '/ers/config/custom-widget'
    }
}
