BeforeAll {
    . (Join-Path $PSScriptRoot '../TestSupport/Start-FakeIseServer.ps1')
    . (Join-Path $PSScriptRoot '../TestSupport/Stop-FakeIseServer.ps1')
    . (Join-Path $PSScriptRoot '../TestSupport/New-TestCredential.ps1')
    $modulePath = Join-Path $PSScriptRoot '../../src/Ise.Cli/Ise.Cli.psd1'
    if (-not (Get-Module Ise.Cli)) { Import-Module $modulePath -Force }
}

Describe 'MnT adapter' {
    AfterEach {
        Disconnect-Ise -InformationAction SilentlyContinue
        if ($server) { Stop-FakeIseServer $server; $server = $null }
    }

    It 'distinguishes enumerable and identifier-required resources' {
        $path = Join-Path $PSScriptRoot '../../schemas/rest/mnt/manifest.json'
        $manifest = Get-Content $path -Raw | ConvertFrom-Json
        ($manifest.resources | Where-Object name -eq ActiveSession).canEnumerate |
            Should -BeTrue
        ($manifest.resources | Where-Object name -eq SessionByMac).canGetById |
            Should -BeTrue
    }

    It 'converts an ActiveList XML response into source-native objects' {
        $xml = @'
<activeList>
  <activeSession><user_name>alice</user_name><calling_station_id>AA:BB</calling_station_id></activeSession>
  <activeSession><user_name>bob</user_name><calling_station_id>CC:DD</calling_station_id></activeSession>
</activeList>
'@
        $routes = @{
            '/admin/API/mnt/Session/ActiveList' = @{
                ContentType = 'application/xml'; Body = $xml
            }
        }
        $server = Start-FakeIseServer -Routes $routes
        Connect-Ise $server.Uri (New-TestCredential) -InformationAction SilentlyContinue | Out-Null
        $rows = @(Get-IseRest -Mnt ActiveSession -InformationAction SilentlyContinue)
        $rows.user_name | Should -Be @('alice', 'bob')
        $rows[0].PSObject.TypeNames[0] | Should -Be 'Ise.Rest.Mnt.ActiveSession'
    }
}
