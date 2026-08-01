$configured = -not [string]::IsNullOrWhiteSpace($env:ISE_TEST_SERVER) -and
    -not [string]::IsNullOrWhiteSpace($env:ISE_TEST_USERNAME) -and
    -not [string]::IsNullOrWhiteSpace($env:ISE_TEST_PASSWORD)

Describe 'Live ISE REST APIs' -Skip:(-not $configured) {
    BeforeAll {
        $modulePath = Join-Path $PSScriptRoot '../../src/Ise.Cli/Ise.Cli.psd1'
        Import-Module $modulePath -Force
        $credential = [pscredential]::new(
            $env:ISE_TEST_USERNAME,
            (ConvertTo-SecureString $env:ISE_TEST_PASSWORD -AsPlainText -Force)
        )
        $connect = @{
            Server = $env:ISE_TEST_SERVER
            Credential = $credential
        }
        if ($env:ISE_TEST_SKIP_CERTIFICATE_CHECK -eq '1') {
            $connect.SkipCertificateCheck = $true
        }
        Connect-Ise @connect -InformationAction SilentlyContinue | Out-Null
    }

    AfterAll { Disconnect-Ise -InformationAction SilentlyContinue }

    It 'loads the ERS catalog' {
        (Get-IseConnection).Capabilities['Rest.Ers'] | Should -BeTrue
        @(Get-IseRestSchema -Ers -InformationAction SilentlyContinue).Count |
            Should -BeGreaterThan 0
    }

    It 'reads an ERS endpoint envelope through the complete command surface' {
        $response = Get-IseRest -Ers Endpoint -Raw -First 1 -InformationAction SilentlyContinue
        $response | Should -Not -BeNullOrEmpty
        $response.PSObject.Properties.Name | Should -Contain SearchResult
    }

    It 'discovers Open API metadata when available' {
        if (-not (Get-IseConnection).Capabilities['Rest.OpenApi']) {
            Set-ItResult -Skipped -Because 'Open API is unavailable on this ISE deployment.'
            return
        }
        $schema = @(Get-IseRestSchema -OpenApi -Refresh -InformationAction SilentlyContinue)
        $schema.Count | Should -BeGreaterThan 0
        $schema.SchemaSource | Should -Contain Live
    }

    It 'reads MnT through its adapter when available' {
        if (-not (Get-IseConnection).Capabilities['Rest.Mnt']) {
            Set-ItResult -Skipped -Because 'MnT is unavailable on this ISE deployment.'
            return
        }
        $schema = @(Get-IseRestSchema -Mnt -InformationAction SilentlyContinue)
        $schema.Name | Should -Contain ActiveSession
        { Get-IseRest -Mnt ActiveSession -Raw -InformationAction SilentlyContinue } |
            Should -Not -Throw
    }
}
