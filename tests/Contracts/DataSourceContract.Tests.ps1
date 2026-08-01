BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '../../src/Ise.Cli/Ise.Cli.psd1'
    if (-not (Get-Module Ise.Cli)) { Import-Module $modulePath -Force }
}

Describe 'Datasource adapter contract' {
    It 'has a resolvable operation for every advertised capability' {
        $module = Get-Module Ise.Cli
        $results = & $module {
            foreach ($source in Get-IseDataSource) {
                [pscustomobject]@{
                    Name  = $source.Name
                    Valid = Test-IseDataSourceDescriptor -Descriptor $source
                }
            }
        }
        @($results).Count | Should -Be 5
        @($results | Where-Object { -not $_.Valid }) | Should -BeNullOrEmpty
    }

    It 'does not expose a mutating REST method or transport switch' {
        (Get-Command Get-IseRest).Parameters.Keys | Should -Not -Contain Method
        $transportPath = Join-Path $PSScriptRoot '../../src/Ise.Cli.Rest/Client/Send-IseRestRequest.ps1'
        $source = Get-Content -LiteralPath $transportPath -Raw
        $source | Should -Match '\[System\.Net\.Http\.HttpMethod\]::Get'
        $source | Should -Not -Match '\[System\.Net\.Http\.HttpMethod\]::(Post|Put|Patch|Delete)'
    }

    It 'assembles datasource connection parameters from adapter metadata' {
        $module = Get-Module Ise.Cli
        $parameters = @(& $module { (New-IseConnectionDynamicParameters).Values })
        $parameters.Name | Should -Contain DataConnectConnectionString
        $parameters.Name | Should -Contain PxGridClientName
        ($parameters | Where-Object Name -EQ DataConnectCredential).ParameterType |
            Should -Be ([pscredential])
        ($parameters | Where-Object Name -EQ PxGridCertificatePassword).ParameterType |
            Should -Be ([securestring])
        $coreConnect = Get-Content `
            (Join-Path $PSScriptRoot '../../src/Ise.Cli.Core/Commands/Connect-Ise.ps1') -Raw
        $coreConnect | Should -Not -Match 'DataConnect|PxGrid|Oracle|STOMP|WebSocket'
    }
}
