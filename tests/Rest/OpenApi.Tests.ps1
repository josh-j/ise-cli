BeforeAll {
    . (Join-Path $PSScriptRoot '../TestSupport/Start-FakeIseServer.ps1')
    . (Join-Path $PSScriptRoot '../TestSupport/Stop-FakeIseServer.ps1')
    . (Join-Path $PSScriptRoot '../TestSupport/New-TestCredential.ps1')
    $modulePath = Join-Path $PSScriptRoot '../../src/Ise.Cli/Ise.Cli.psd1'
    if (-not (Get-Module Ise.Cli)) { Import-Module $modulePath -Force }
}

Describe 'Open API adapter' {
    AfterEach {
        Disconnect-Ise -InformationAction SilentlyContinue
        if ($server) { Stop-FakeIseServer $server; $server = $null }
    }

    It 'contains fallback descriptors for direct crawling' {
        $path = Join-Path $PSScriptRoot '../../schemas/rest/openapi/manifest.json'
        $manifest = Get-Content $path -Raw | ConvertFrom-Json
        $manifest.api | Should -Be 'OpenApi'
        $manifest.resources.name | Should -Contain 'DeploymentNode'
    }

    It 'discovers live GET operations and follows Open API nextPage links' {
        $routes = @{
            '/api/swagger-resources' = @{ Body = @(
                @{ name = 'Deployment'; location = '/v3/api-docs?group=Deployment' }
            ) | ConvertTo-Json -Depth 5 -Compress }
            '/api/v3/api-docs?group=Deployment' = @{ Body = @{
                paths = @{
                    '/deployment/node' = @{
                        get = @{ operationId = 'ListDeploymentNodes' }
                    }
                }
            } | ConvertTo-Json -Depth 8 -Compress }
            '/api/v1/deployment/node' = @{ Body = @{
                response = @(@{ id = 'n1'; hostname = 'ise-1' })
                nextPage = @{ href = '/api/v1/deployment/node?page=2' }
            } | ConvertTo-Json -Depth 8 -Compress }
            '/api/v1/deployment/node?page=2' = @{ Body = @{
                response = @(@{ id = 'n2'; hostname = 'ise-2' })
            } | ConvertTo-Json -Depth 8 -Compress }
        }
        $server = Start-FakeIseServer -Routes $routes
        Connect-Ise $server.Uri (New-TestCredential) -InformationAction SilentlyContinue | Out-Null
        $schema = Get-IseRestSchema -OpenApi ListDeploymentNodes -InformationAction SilentlyContinue
        $schema.SchemaSource | Should -Be 'Live'
        $rows = @(Get-IseRest -OpenApi ListDeploymentNodes -InformationAction SilentlyContinue)
        $rows.hostname | Should -Be @('ise-1', 'ise-2')
        $rows[0].PSObject.TypeNames[0] | Should -Be 'Ise.Rest.OpenApi.ListDeploymentNodes'
    }

    It 'follows native page, size, and total metadata without a next link' {
        $routes = @{
            '/api/swagger-resources' = @{ Body = @(
                @{ name = 'Inventory'; location = '/api/v3/api-docs?group=Inventory' }
            ) | ConvertTo-Json -Depth 5 -Compress }
            '/api/v3/api-docs?group=Inventory' = @{ Body = @{
                paths = @{ '/inventory/items' = @{ get = @{ operationId = 'ListInventoryItems' } } }
            } | ConvertTo-Json -Depth 8 -Compress }
            '/api/v1/inventory/items?size=1' = @{ Body = @{
                response = @(@{ id = 'item-1'; nativeField = 'one' })
                page = 1; size = 1; total = 2
            } | ConvertTo-Json -Depth 8 -Compress }
            '/api/v1/inventory/items?page=2&size=1' = @{ Body = @{
                response = @(@{ id = 'item-2'; nativeField = 'two' })
                page = 2; size = 1; total = 2
            } | ConvertTo-Json -Depth 8 -Compress }
        }
        $server = Start-FakeIseServer -Routes $routes
        Connect-Ise $server.Uri (New-TestCredential) -InformationAction SilentlyContinue | Out-Null
        $rows = @(Get-IseRest -OpenApi ListInventoryItems -PageSize 1 `
            -InformationAction SilentlyContinue)
        $rows.id | Should -Be @('item-1', 'item-2')
        $rows.nativeField | Should -Be @('one', 'two')
    }

    It 'binds Id to a discovered single path parameter regardless of its name' {
        $routes = @{
            '/api/swagger-resources' = @{ Body = @(
                @{ name = 'Nodes'; location = '/api/v3/api-docs?group=Nodes' }
            ) | ConvertTo-Json -Depth 5 -Compress }
            '/api/v3/api-docs?group=Nodes' = @{ Body = @{
                paths = @{ '/nodes/{nodeId}' = @{ get = @{ operationId = 'GetNodeByName' } } }
            } | ConvertTo-Json -Depth 8 -Compress }
            '/api/v1/nodes/ise-1' = @{ Body = @{ response = @{ id = 'ise-1'; role = 'PAN' } } |
                ConvertTo-Json -Depth 6 -Compress }
        }
        $server = Start-FakeIseServer -Routes $routes
        Connect-Ise $server.Uri (New-TestCredential) -InformationAction SilentlyContinue | Out-Null
        $row = Get-IseRest -OpenApi GetNodeByName -Id ise-1 -InformationAction SilentlyContinue
        $row.id | Should -Be ise-1
        $row.role | Should -Be PAN
    }
}
