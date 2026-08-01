BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '../../src/Ise.Cli/Ise.Cli.psd1'
    if (-not (Get-Module Ise.Cli)) { Import-Module $modulePath -Force }
    . (Join-Path $PSScriptRoot '../TestSupport/Start-FakeIseServer.ps1')
    . (Join-Path $PSScriptRoot '../TestSupport/Stop-FakeIseServer.ps1')
    $credential = [pscredential]::new('u', (ConvertTo-SecureString 'p' -AsPlainText -Force))
}

Describe 'Structured logging' {
    BeforeEach { $server = $null }

    AfterEach {
        Disconnect-Ise -InformationAction SilentlyContinue
        Stop-IseTrace -ErrorAction SilentlyContinue
        if ($server) { Stop-FakeIseServer $server; $server = $null }
    }

    It 'writes independently parseable correlated JSON Lines events' {
        $path = Join-Path $TestDrive 'ise-cli.jsonl'
        Start-IseTrace -Path $path -Level Debug | Out-Null
        $server = Start-FakeIseServer -Routes @{
            '/ers/config/endpoint?size=1' = @{ Body = '{"SearchResult":{"total":0,"resources":[]}}' }
            '/api/swagger-resources' = @{ Body = '[]' }
            '/admin/API/mnt/Version' = @{
                ContentType = 'application/xml'; Body = '<versionInfo><version>3.3</version></versionInfo>'
            }
        }
        Connect-Ise $server.Uri $credential -InformationAction SilentlyContinue | Out-Null
        Get-IseRestSchema -Ers -InformationAction SilentlyContinue | Out-Null
        Disconnect-Ise -InformationAction SilentlyContinue

        $events = @(Get-Content $path | ForEach-Object { $_ | ConvertFrom-Json })
        $events.Count | Should -BeGreaterThan 2
        $events.eventId | Should -Contain 'connection.opened'
        $events.eventId | Should -Contain 'source.operation.completed'
        $events.command | Should -Contain Start-IseTrace
        $events.command | Should -Contain Connect-Ise
        $events.command | Should -Contain Get-IseConnection
        $events.command | Should -Contain Get-IseRestSchema
        $events.command | Should -Contain Disconnect-Ise
        $events.command | Should -Contain Stop-IseTrace
        @($events | Where-Object eventId -eq 'source.operation.completed')[0].correlationId |
            Should -Not -BeNullOrEmpty
    }

    It 'supports an internal custom sink registration seam' {
        $module = Get-Module Ise.Cli
        $events = & $module {
            function script:Write-IseFixtureSink {
                param([IseLogEvent] $Event, $Sink)
                $Sink.State.Add($Event)
            }
            $state = [System.Collections.Generic.List[object]]::new()
            $null = Register-IseTraceSink -Name Fixture -WriteCommand Write-IseFixtureSink `
                -Level Debug -State $state
            $correlation = New-IseCorrelationContext -Command Test
            $null = Write-IseLogEvent -Level Information -EventId command.started `
                -Message test -Correlation $correlation
            @($state)
        }
        $events.Count | Should -Be 1
        $events[0].EventId | Should -Be command.started
    }

    It 'retains the complete structured event contract' {
        $module = Get-Module Ise.Cli
        $event = & $module {
            $correlation = New-IseCorrelationContext -Command Test-EventContract `
                -CorrelationId correlation-1
            Write-IseLogEvent -Level Information -EventId rest.page.completed `
                -Message complete -Correlation $correlation -RequestId request-1 `
                -Datasource Rest.Ers -Operation Enumerate -Target Endpoint `
                -Uri https://ise.example.test/ers/config/endpoint -Page 2 `
                -StatusCode 200 -DurationMilliseconds 12.5 -RecordCount 10 `
                -Properties @{ fixture = $true } -InformationAction SilentlyContinue
        }
        foreach ($name in @(
            'Timestamp', 'Level', 'EventId', 'CorrelationId', 'RequestId', 'Command',
            'Datasource', 'Operation', 'Target', 'Uri', 'Page', 'StatusCode',
            'DurationMilliseconds', 'RecordCount', 'Message', 'Exception', 'Properties'
        )) { $event.PSObject.Properties.Name | Should -Contain $name }
        $event.CorrelationId | Should -Be correlation-1
        $event.RequestId | Should -Be request-1
        $event.Properties.fixture | Should -BeTrue
    }
}
