BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '../../src/Ise.Cli/Ise.Cli.psd1'
    if (-not (Get-Module Ise.Cli)) { Import-Module $modulePath -Force }
}

Describe 'REST URI construction' {
    It 'sorts keys, repeats arrays, and escapes values independently' {
        $module = Get-Module Ise.Cli
        $result = & $module {
            ConvertTo-IseQueryString @{ z = 'space here'; a = @('one', 'two') }
        }
        $result | Should -Be 'a=one&a=two&z=space%20here'
    }
}
