Describe 'Staged module' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '../TestSupport/Start-FakeIseServer.ps1')
        . (Join-Path $PSScriptRoot '../TestSupport/Stop-FakeIseServer.ps1')
        $credential = [pscredential]::new(
            'staged-test',
            (ConvertTo-SecureString 'staged-test' -AsPlainText -Force)
        )
    }

    BeforeEach { $server = $null }

    AfterEach {
        Disconnect-Ise -InformationAction SilentlyContinue -ErrorAction SilentlyContinue
        if ($server) { Stop-FakeIseServer $server; $server = $null }
    }

    It 'imports from the built artifact' {
        $env:ISE_CLI_BUILT_MODULE | Should -Not -BeNullOrEmpty
        Test-Path $env:ISE_CLI_BUILT_MODULE | Should -BeTrue
        Remove-Module Ise.Cli -Force -ErrorAction SilentlyContinue
        { Import-Module $env:ISE_CLI_BUILT_MODULE -Force -ErrorAction Stop } |
            Should -Not -Throw
        Get-Command Get-IseRest -Module Ise.Cli | Should -Not -BeNullOrEmpty
    }

    It 'imports the staged type definitions in a fresh PowerShell process' {
        $powerShell = (Get-Process -Id $PID).Path
        $escapedPath = $env:ISE_CLI_BUILT_MODULE.Replace("'", "''")
        $output = & $powerShell -NoLogo -NoProfile -Command `
            "Import-Module '$escapedPath' -Force -ErrorAction Stop; (Get-Command Get-IseRest).Name"
        $LASTEXITCODE | Should -Be 0
        $output | Should -Contain Get-IseRest
    }

    It 'meets the Core completion gate from the staged package' {
        Remove-Module Ise.Cli -Force -ErrorAction SilentlyContinue
        Import-Module $env:ISE_CLI_BUILT_MODULE -Force -ErrorAction Stop
        @(Get-Command -Module Ise.Cli).Count | Should -Be 13
        $server = Start-FakeIseServer -Routes @{
            '/ers/config/endpoint?size=1' = @{ Body = '{"SearchResult":{"total":0,"resources":[]}}' }
            '/api/swagger-resources' = @{ Body = '[]' }
            '/admin/API/mnt/Version' = @{
                ContentType = 'application/xml'; Body = '<versionInfo><version>3.3</version></versionInfo>'
            }
        }
        $trace = Join-Path $TestDrive 'staged.jsonl'
        Start-IseTrace $trace -Level Debug | Out-Null
        $connection = Connect-Ise $server.Uri $credential -InformationAction SilentlyContinue
        $connection.ServerVersion | Should -Be '3.3'
        Get-IseRestSchema -Ers -InformationAction SilentlyContinue | Out-Null
        Disconnect-Ise -InformationAction SilentlyContinue
        $events = @(Get-Content $trace | ForEach-Object { $_ | ConvertFrom-Json })
        @($events | Where-Object eventId -eq connection.opened).Count | Should -Be 1
        @($events | Where-Object correlationId).Count | Should -BeGreaterThan 0
        try { Get-IseRestSchema -Ers -ErrorAction Stop }
        catch { $failure = $_ }
        $failure.FullyQualifiedErrorId | Should -Be 'Ise.Connection.NotConnected,Get-IseRestSchema'
        $failure.TargetObject.Operation | Should -Be Connect
    }
}
