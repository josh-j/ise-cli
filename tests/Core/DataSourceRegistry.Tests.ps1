BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '../../src/Ise.Cli/Ise.Cli.psd1'
    if (-not (Get-Module Ise.Cli)) { Import-Module $modulePath -Force }
}

Describe 'Datasource registry' {
    It 'registers the three REST adapters case-insensitively' {
        $module = Get-Module Ise.Cli
        $sources = @(& $module { Get-IseDataSource })
        $sources.Name | Should -Contain 'Rest.Ers'
        $sources.Name | Should -Contain 'Rest.OpenApi'
        $sources.Name | Should -Contain 'Rest.Mnt'
        $sources.Name | Should -Contain 'DataConnect'
        $sources.Name | Should -Contain 'PxGrid'
        (& $module { Get-IseDataSource -Name 'rest.ers' }).Name | Should -Be 'Rest.Ers'
    }

    It 'rejects duplicate datasource names' {
        $module = Get-Module Ise.Cli
        {
            & $module {
                Register-IseDataSource -Descriptor ([pscustomobject]@{
                    Name = 'Rest.Ers'; DisplayName = 'duplicate'
                    Capabilities = @(); Operations = @{}; Open = $null; Close = $null
                })
            }
        } | Should -Throw '*already registered*'
    }

    It 'rejects connection parameter collisions at registration time' {
        $module = Get-Module Ise.Cli
        {
            & $module {
                Register-IseDataSource -Descriptor ([pscustomobject]@{
                    Name = 'Fixture.Collision'; DisplayName = 'collision'
                    Capabilities = @(); Operations = @{}
                    Configure = 'Set-IseDataConnectConfiguration'; Open = $null; Close = $null
                    Metadata = @{ ConnectionParameters = @(
                        @{ Name = 'DataConnectConnectionString'; ParameterType = [string] }
                    ) }
                })
            }
        } | Should -Throw '*conflicts with an existing parameter*'
    }
}
