BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '../../src/Ise.Cli/Ise.Cli.psd1'
    if (-not (Get-Module Ise.Cli)) { Import-Module $modulePath -Force }
    . (Join-Path $PSScriptRoot '../TestSupport/Open-TestIseSession.ps1')
    $credential = [pscredential]::new('u', (ConvertTo-SecureString 'p' -AsPlainText -Force))
}

Describe 'Semantic providers and context visibility' {
    BeforeEach {
        Open-TestIseSession -Credential $credential
        $module = Get-Module Ise.Cli
        & $module {
            $script:IseSession.DatasourceState['Semantic.DisabledSources'] = @('Rest.Ers', 'Rest.Mnt')
        }
    }

    AfterEach {
        $module = Get-Module Ise.Cli
        & $module {
            foreach ($key in @($script:IseSemanticProviders.Keys | Where-Object { $_ -like 'Fixture.*' })) {
                $script:IseSemanticProviders.Remove($key)
            }
        }
        Disconnect-Ise -InformationAction SilentlyContinue
    }

    It 'registers valid providers from independent adapters' {
        $module = Get-Module Ise.Cli
        $providers = @(& $module { Get-IseSemanticProvider })
        $providers.Count | Should -Be 8
        @(& $module {
            Get-IseSemanticProvider | ForEach-Object {
                Test-IseSemanticProviderDescriptor -Descriptor $_
            }
        } | Where-Object { -not $_ }).Count | Should -Be 0
        @($providers.Capability | Sort-Object -Unique) | Should -Be @(
            'ActiveSessions', 'AuthenticationHistory', 'EndpointInventory', 'ProfilingAttributes'
        )
    }

    It 'composes normalized fields and retains native provider evidence' {
        $module = Get-Module Ise.Cli
        & $module {
            function script:Test-IseFixtureProvider { param($Session, $Provider) $true }
            function script:Invoke-IseFixtureProvider {
                param($Session, $Filter, $Correlation, $Provider)
                switch ($Provider.Capability) {
                    EndpointInventory {
                        [pscustomobject]@{ nativeEndpointName = 'phone-1'; mac = $Filter.MacAddress }
                    }
                    AuthenticationHistory {
                        [pscustomobject]@{ USERNAME = 'alice'; timestamp = '2026-08-01T09:00:00Z' }
                    }
                    ActiveSessions { [pscustomobject]@{ state = 'STARTED'; userName = 'alice' } }
                    ProfilingAttributes { [pscustomobject]@{ endpointPolicy = 'Cisco-IP-Phone' } }
                }
            }
            foreach ($capability in @(
                'EndpointInventory', 'AuthenticationHistory', 'ActiveSessions', 'ProfilingAttributes'
            )) {
                Register-IseSemanticProvider -Descriptor ([pscustomobject]@{
                    Name = "Fixture.$capability"; Capability = $capability
                    Source = 'Rest.Ers'; Invoke = 'Invoke-IseFixtureProvider'
                    Test = 'Test-IseFixtureProvider'; Priority = 1; Metadata = @{}
                })
            }
        }
        $result = Get-IseContextVisibility -MacAddress AA:BB -InformationAction SilentlyContinue
        $result.Endpoint.nativeEndpointName | Should -Be phone-1
        $result.LastAuthentication.USERNAME | Should -Be alice
        $result.CurrentSessions[0].state | Should -Be STARTED
        $result.ProfilingAttributes[0].endpointPolicy | Should -Be Cisco-IP-Phone
        $result.SourceData.EndpointInventory[0].mac | Should -Be AA:BB
        @($result.Evidence | Where-Object Provider -Like 'Fixture.*').Count | Should -Be 4
        $result.CorrelationId | Should -Not -BeNullOrEmpty
    }

    It 'reports unconfigured capabilities without throwing away partial output' {
        $result = Get-IseContextVisibility -MacAddress AA:BB -InformationAction SilentlyContinue
        $result.PSObject.TypeNames[0] | Should -Be 'Ise.Feature.ContextVisibility'
        $result.MissingCapabilities | Should -Contain AuthenticationHistory
        @($result.Requests | Where-Object { -not $_.Succeeded }).Count | Should -BeGreaterThan 0
    }
}
