BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '../../src/Ise.Cli/Ise.Cli.psd1'
    if (-not (Get-Module Ise.Cli)) { Import-Module $modulePath -Force }
    . (Join-Path $PSScriptRoot '../TestSupport/Open-TestIseSession.ps1')
    $credential = [pscredential]::new('u', (ConvertTo-SecureString 'p' -AsPlainText -Force))
}

Describe 'Data Connect adapter' {
    BeforeEach {
        Open-TestIseSession -Credential $credential
        $module = Get-Module Ise.Cli
        & $module {
            $script:IseSession.DatasourceState['DataConnect.Executor'] = {
                param($Operation, $Sql, $Parameters, $Target, $First)
                if ($Operation -eq 'Catalog') {
                    [pscustomobject]@{ OWNER = 'REPORTING'; VIEW_NAME = 'ENDPOINTS_DATA'
                        COLUMN_NAME = 'MAC_ADDRESS'; DATA_TYPE = 'VARCHAR2'; COLUMN_ID = 1 }
                    [pscustomobject]@{ OWNER = 'REPORTING'; VIEW_NAME = 'ENDPOINTS_DATA'
                        COLUMN_NAME = 'ENDPOINT_POLICY'; DATA_TYPE = 'VARCHAR2'; COLUMN_ID = 2 }
                    [pscustomobject]@{ OWNER = 'REPORTING'; VIEW_NAME = 'RADIUS_AUTHENTICATIONS'
                        COLUMN_NAME = 'USERNAME'; DATA_TYPE = 'VARCHAR2'; COLUMN_ID = 1 }
                    return
                }
                if ($Target -eq 'ENDPOINTS_DATA') {
                    [pscustomobject]@{ MAC_ADDRESS = 'AA:BB'; ENDPOINT_POLICY = 'Phone' }
                    [pscustomobject]@{ MAC_ADDRESS = 'CC:DD'; ENDPOINT_POLICY = 'Workstation' }
                    return
                }
                $username = if ($Parameters -and $Parameters.ContainsKey('user')) {
                    $Parameters['user']
                } else { 'alice' }
                [pscustomobject]@{ USERNAME = $username }
            }
        }
    }

    AfterEach { Disconnect-Ise -InformationAction SilentlyContinue }

    It 'discovers live views and ordered columns' {
        $schema = @(Get-IseDataConnectSchema)
        $schema.Name | Should -Contain 'ENDPOINTS_DATA'
        ($schema | Where-Object Name -eq ENDPOINTS_DATA).Columns.Name |
            Should -Be @('MAC_ADDRESS', 'ENDPOINT_POLICY')
    }

    It 'streams a named view as typed source-native rows' {
        $rows = @(Get-IseDataConnect ENDPOINTS_DATA)
        $rows.Count | Should -Be 2
        $rows[0].MAC_ADDRESS | Should -Be 'AA:BB'
        $rows[0].PSObject.TypeNames[0] | Should -Be 'Ise.DataConnect.EndpointsData'
        $rows[0].IseMetadata.Datasource | Should -Be 'DataConnect'
    }

    It 'supports an explicit parameterized SELECT' {
        $row = Get-IseDataConnect -Sql 'SELECT USERNAME FROM RADIUS_AUTHENTICATIONS WHERE USERNAME = :user' `
            -Parameter @{ user = 'bob' }
        $row.USERNAME | Should -Be 'bob'
    }

    It 'rejects mutating SQL' {
        { Get-IseDataConnect -Sql 'DELETE FROM ENDPOINTS_DATA' -ErrorAction Stop } |
            Should -Throw -ErrorId 'Ise.DataConnect.ReadOnlySqlRequired,Get-IseDataConnect'
    }

    It 'honors First across view output' {
        @(Get-IseDataConnect ENDPOINTS_DATA -First 1).Count | Should -Be 1
    }
}
