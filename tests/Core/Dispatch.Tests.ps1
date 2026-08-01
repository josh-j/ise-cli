BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '../../src/Ise.Cli/Ise.Cli.psd1'
    if (-not (Get-Module Ise.Cli)) { Import-Module $modulePath -Force }
    . (Join-Path $PSScriptRoot '../TestSupport/Open-TestIseSession.ps1')
}

Describe 'Operation dispatcher' {
    It 'requires an active connection' {
        Disconnect-Ise -InformationAction SilentlyContinue
        { Get-IseRestSchema -Ers -ErrorAction Stop } |
            Should -Throw -ErrorId 'Ise.Connection.NotConnected,Get-IseRestSchema'
    }

    It 'rejects an unsupported datasource capability' {
        $credential = [pscredential]::new('u', (ConvertTo-SecureString 'p' -AsPlainText -Force))
        Open-TestIseSession -Credential $credential
        $module = Get-Module Ise.Cli
        { & $module { Invoke-IseSourceOperation -Source Rest.Ers -Operation Subscribe } } |
            Should -Throw '*does not support*'
        Disconnect-Ise -InformationAction SilentlyContinue
    }
}
