BeforeAll {
    . (Join-Path $PSScriptRoot '../TestSupport/Start-FakeIseServer.ps1')
    . (Join-Path $PSScriptRoot '../TestSupport/Stop-FakeIseServer.ps1')
    . (Join-Path $PSScriptRoot '../TestSupport/New-TestCredential.ps1')
    $modulePath = Join-Path $PSScriptRoot '../../src/Ise.Cli/Ise.Cli.psd1'
    if (-not (Get-Module Ise.Cli)) { Import-Module $modulePath -Force }
}

Describe 'Get-IseRest' {
    AfterEach {
        Disconnect-Ise -InformationAction SilentlyContinue
        if ($server) { Stop-FakeIseServer $server; $server = $null }
    }

    It 'streams every ERS page in order and preserves source fields' {
        $fixtureRoot = Join-Path $PSScriptRoot '../Fixtures/ers'
        $routes = @{
            '/ers/config/endpoint' = @{
                Body = Get-Content (Join-Path $fixtureRoot 'endpoints-page-1.json') -Raw
            }
            '/ers/config/endpoint?page=2' = @{
                Body = Get-Content (Join-Path $fixtureRoot 'endpoints-page-2.json') -Raw
            }
        }
        $server = Start-FakeIseServer -Routes $routes
        Connect-Ise $server.Uri (New-TestCredential) -InformationAction SilentlyContinue | Out-Null
        $rows = @(Get-IseRest -Ers Endpoint -InformationAction SilentlyContinue)
        $rows.id | Should -Be @('endpoint-1', 'endpoint-2')
        $rows[0].unknownField | Should -Be 'preserved'
        $rows[0].PSObject.TypeNames[0] | Should -Be 'Ise.Rest.Ers.Endpoint'
        $rows[0].IseMetadata.Datasource | Should -Be 'Rest.Ers'
    }

    It 'returns one raw envelope per page' {
        $routes = @{
            '/ers/config/endpoint' = @{ Body = @{
                SearchResult = @{ total = 1; resources = @(@{ id = '1' }) }
            } | ConvertTo-Json -Depth 6 -Compress }
        }
        $server = Start-FakeIseServer -Routes $routes
        Connect-Ise $server.Uri (New-TestCredential) -InformationAction SilentlyContinue | Out-Null
        $raw = @(Get-IseRest -Ers Endpoint -Raw -InformationAction SilentlyContinue)
        $raw.Count | Should -Be 1
        $raw[0].SearchResult.total | Should -Be 1
    }

    It 'encodes repeated query values' {
        $routes = @{
            '/ers/config/endpoint?filter=a&filter=b' = @{ Body = @{
                SearchResult = @{ total = 0; resources = @() }
            } | ConvertTo-Json -Depth 6 -Compress }
        }
        $server = Start-FakeIseServer -Routes $routes
        Connect-Ise $server.Uri (New-TestCredential) -InformationAction SilentlyContinue | Out-Null
        { Get-IseRest -Ers Endpoint -Query @{ filter = @('a', 'b') } `
            -InformationAction SilentlyContinue } | Should -Not -Throw
    }

    It 'detects a repeated next link' {
        $routes = @{
            '/ers/config/endpoint' = @{ Body = @{
                SearchResult = @{ total = 2; resources = @(@{ id = '1' })
                    nextPage = @{ href = '/ers/config/endpoint?page=2' } }
            } | ConvertTo-Json -Depth 8 -Compress }
            '/ers/config/endpoint?page=2' = @{ Body = @{
                SearchResult = @{ total = 2; resources = @(@{ id = '2' })
                    nextPage = @{ href = '/ers/config/endpoint?page=2' } }
            } | ConvertTo-Json -Depth 8 -Compress }
        }
        $server = Start-FakeIseServer -Routes $routes
        Connect-Ise $server.Uri (New-TestCredential) -InformationAction SilentlyContinue | Out-Null
        { Get-IseRest -Ers Endpoint -InformationAction SilentlyContinue -ErrorAction Stop } |
            Should -Throw -ErrorId 'Ise.Rest.Pagination.Cycle,Get-IseRest'
    }

    It 'does not request another page after downstream cancellation' {
        $routes = @{
            '/ers/config/endpoint' = @{ Body = @{
                SearchResult = @{ total = 2; resources = @(@{ id = '1' })
                    nextPage = @{ href = '/ers/config/endpoint?page=2' } }
            } | ConvertTo-Json -Depth 8 -Compress }
            '/ers/config/endpoint?page=2' = @{ StatusCode = 500; Body = '{"error":"should_not_be_requested"}' }
        }
        $server = Start-FakeIseServer -Routes $routes
        Connect-Ise $server.Uri (New-TestCredential) -InformationAction SilentlyContinue | Out-Null
        $errors = @()
        $row = Get-IseRest -Ers Endpoint -InformationAction SilentlyContinue `
            -ErrorVariable errors |
            Select-Object -First 1
        $row.id | Should -Be '1'
        $errors | Should -BeNullOrEmpty
    }

    It 'continues a full crawl after a resource-local failure' {
        $routes = @{
            '/ers/config/endpoint' = @{ StatusCode = 500; Body = '{"error":"failed"}' }
            '/ers/config/networkdevice' = @{ Body = @{
                SearchResult = @{ total = 1; resources = @(@{ id = 'nad-1'; name = 'switch-1' }) }
            } | ConvertTo-Json -Depth 6 -Compress }
        }
        $server = Start-FakeIseServer -Routes $routes
        Connect-Ise $server.Uri (New-TestCredential) -InformationAction SilentlyContinue | Out-Null
        $errors = @()
        $rows = @(Get-IseRest -Ers -ErrorAction Continue -ErrorVariable errors `
            -InformationAction SilentlyContinue 2>$null)
        $rows.name | Should -Contain 'switch-1'
        $errors.Count | Should -BeGreaterThan 0
    }

    It 'correlates page events while assigning unique request ids' {
        $routes = @{
            '/ers/config/endpoint' = @{ Body = @{
                SearchResult = @{ total = 2; resources = @(@{ id = '1' })
                    nextPage = @{ href = '/ers/config/endpoint?page=2' } }
            } | ConvertTo-Json -Depth 8 -Compress }
            '/ers/config/endpoint?page=2' = @{ Body = @{
                SearchResult = @{ total = 2; resources = @(@{ id = '2' }) }
            } | ConvertTo-Json -Depth 8 -Compress }
        }
        $server = Start-FakeIseServer -Routes $routes
        $trace = Join-Path $TestDrive 'pages.jsonl'
        Start-IseTrace -Path $trace -Level Debug | Out-Null
        Connect-Ise $server.Uri (New-TestCredential) -InformationAction SilentlyContinue | Out-Null
        Get-IseRest -Ers Endpoint -InformationAction SilentlyContinue | Out-Null
        Disconnect-Ise -InformationAction SilentlyContinue
        $events = @(Get-Content $trace | ForEach-Object { $_ | ConvertFrom-Json })
        $pages = @($events | Where-Object eventId -eq 'rest.page.completed')
        $pages.Count | Should -Be 2
        @($pages.correlationId | Sort-Object -Unique).Count | Should -Be 1
        @($pages.requestId | Sort-Object -Unique).Count | Should -Be 2
        $source = @($events | Where-Object eventId -eq 'source.operation.completed')[0]
        $source.correlationId | Should -Be $pages[0].correlationId
    }

    It 'does not let a logging sink failure replace an HTTP failure' {
        $routes = @{
            '/ers/config/endpoint' = @{ StatusCode = 500; Body = '{"error":"http_failure"}' }
        }
        $server = Start-FakeIseServer -Routes $routes
        Start-IseTrace -Path (Join-Path $TestDrive 'broken.jsonl') -Level Debug | Out-Null
        Connect-Ise $server.Uri (New-TestCredential) -InformationAction SilentlyContinue | Out-Null
        $module = Get-Module Ise.Cli
        & $module { $script:IseTraceSinks[0].Writer.Dispose() }
        try {
            Get-IseRest -Ers Endpoint -ErrorAction Stop -InformationAction SilentlyContinue
        }
        catch { $failure = $_ }
        $failure.FullyQualifiedErrorId | Should -Be 'Ise.Rest.Http.500,Get-IseRest'
        (& $module { $script:IseTraceSinks[0].Disabled }) | Should -BeTrue
    }

    It 'honors ErrorAction Stop during an otherwise broad crawl' {
        $routes = @{
            '/ers/config/endpoint' = @{ StatusCode = 500; Body = '{"error":"failed"}' }
            '/ers/config/networkdevice' = @{ Body = '{"SearchResult":{"total":0,"resources":[]}}' }
        }
        $server = Start-FakeIseServer -Routes $routes
        Connect-Ise $server.Uri (New-TestCredential) -InformationAction SilentlyContinue | Out-Null
        { Get-IseRest -Ers -ErrorAction Stop -InformationAction SilentlyContinue } |
            Should -Throw -ErrorId 'Ise.Rest.ResourceFailed,Get-IseRest'
    }

    It 'preserves earlier output when a later resource fails' {
        $routes = @{
            '/ers/config/endpoint' = @{ Body = '{"SearchResult":{"total":1,"resources":[{"id":"kept"}]}}' }
            '/ers/config/networkdevice' = @{ StatusCode = 500; Body = '{"error":"later"}' }
        }
        $server = Start-FakeIseServer -Routes $routes
        Connect-Ise $server.Uri (New-TestCredential) -InformationAction SilentlyContinue | Out-Null
        $errors = @()
        $rows = @(Get-IseRest -Ers -ErrorAction Continue -ErrorVariable errors `
            -InformationAction SilentlyContinue 2>$null)
        $rows.id | Should -Contain kept
        $errors.Count | Should -BeGreaterThan 0
    }

    It 'preserves raw bytes for non-JSON transport responses' {
        $routes = @{
            '/binary' = @{ ContentType = 'application/octet-stream'; Body = 'binary-value' }
        }
        $server = Start-FakeIseServer -Routes $routes
        Connect-Ise $server.Uri (New-TestCredential) -InformationAction SilentlyContinue | Out-Null
        $module = Get-Module Ise.Cli
        $response = & $module {
            $correlation = New-IseCorrelationContext -Command Test
            Send-IseRestRequest -Session $script:IseSession -Path /binary `
                -Correlation $correlation -Datasource Rest.Ers -Operation GetPath
        }
        $response.BodyObject | Should -Be binary-value
        [Text.Encoding]::UTF8.GetString($response.BodyBytes) | Should -Be binary-value
    }
}
