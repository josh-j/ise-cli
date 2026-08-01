Describe 'Source module import' {
    It 'exports only the approved public commands' {
        $path = Join-Path $PSScriptRoot '../../src/Ise.Cli/Ise.Cli.psd1'
        Remove-Module Ise.Cli -Force -ErrorAction SilentlyContinue
        Import-Module $path -Force
        $expected = @(
            'Connect-Ise', 'Disconnect-Ise', 'Get-IseConnection', 'Get-IseRest',
            'Get-IseRestSchema', 'Get-IseDataConnect', 'Get-IseDataConnectSchema',
            'Get-IsePxGrid', 'Watch-IsePxGrid',
            'Get-IseContextVisibility',
            'Get-IseTrace', 'Start-IseTrace', 'Stop-IseTrace'
        ) | Sort-Object
        @(Get-Command -Module Ise.Cli).Name | Sort-Object | Should -Be $expected
    }
}
