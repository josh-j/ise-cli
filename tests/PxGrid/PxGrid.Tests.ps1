BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '../../src/Ise.Cli/Ise.Cli.psd1'
    if (-not (Get-Module Ise.Cli)) { Import-Module $modulePath -Force }
    . (Join-Path $PSScriptRoot '../TestSupport/Open-TestIseSession.ps1')
    $credential = [pscredential]::new('u', (ConvertTo-SecureString 'p' -AsPlainText -Force))
}

Describe 'pxGrid adapter' {
    BeforeEach {
        Open-TestIseSession -Credential $credential
        $module = Get-Module Ise.Cli
        & $module {
            $script:IseSession.DatasourceState['PxGrid.Config'] = @{
                ControlUri = [uri]'https://ise.example.test:8910/pxgrid/control/'
                ClientName = 'ise-cli-test'; CertificatePath = $null
                CertificatePassword = $null
            }
            $script:IseSession.DatasourceState['PxGrid.Executor'] = {
                param($Operation, $Uri, $Body, $PeerNodeName, $Target)
                switch ($Operation) {
                    AccountActivate { [pscustomobject]@{ accountState = 'ENABLED'; version = '2.0' } }
                    ServiceLookup {
                        if ($Body.name -eq 'com.cisco.ise.session') {
                            [pscustomobject]@{ services = @([pscustomobject]@{
                                name = $Body.name; nodeName = 'ise-psn-1'
                                properties = [pscustomobject]@{
                                    restBaseUrl = 'https://ise-psn-1:8910/pxgrid/session'
                                    wsPubsubService = 'wss://ise-psn-1:8910/pxgrid/pubsub'
                                    sessionTopic = '/topic/com.cisco.ise.session'
                                }
                            }) }
                        } else { [pscustomobject]@{ services = @() } }
                    }
                    AccessSecret { [pscustomobject]@{ secret = 'test-secret' } }
                    Snapshot {
                        [pscustomobject]@{ sessions = @(
                            [pscustomobject]@{ macAddress = 'AA:BB'; userName = 'alice' }
                            [pscustomobject]@{ macAddress = 'CC:DD'; userName = 'bob' }
                        ) }
                    }
                    Subscribe {
                        [pscustomobject]@{ macAddress = 'AA:BB'; state = 'STARTED' }
                        [pscustomobject]@{ macAddress = 'AA:BB'; state = 'STOPPED' }
                    }
                }
            }
        }
    }

    AfterEach { Disconnect-Ise -InformationAction SilentlyContinue }

    It 'discovers advertised service endpoints and topics' {
        $module = Get-Module Ise.Cli
        $catalog = @(& $module {
            $correlation = New-IseCorrelationContext -Command Test
            Get-IsePxGridCatalog -Session $script:IseSession -Correlation $correlation
        })
        $catalog.Count | Should -Be 1
        $catalog[0].Name | Should -Be Session
        $catalog[0].Topics | Should -Contain '/topic/com.cisco.ise.session'
        $catalog[0].SchemaSource | Should -Be 'Live+Bundled'
    }

    It 'streams typed snapshot records and honors First' {
        $rows = @(Get-IsePxGrid Session -First 1)
        $rows.Count | Should -Be 1
        $rows[0].userName | Should -Be alice
        $rows[0].PSObject.TypeNames[0] | Should -Be 'Ise.PxGrid.Session.getSessions'
        $rows[0].IseMetadata.NodeName | Should -Be 'ise-psn-1'
    }

    It 'streams subscription messages and honors First' {
        $events = @(Watch-IsePxGrid Session -First 1)
        $events.Count | Should -Be 1
        $events[0].state | Should -Be STARTED
        $events[0].PSObject.TypeNames[0] | Should -Be 'Ise.PxGrid.Session.Subscribe'
    }

    It 'cleans account, discovery, secrets, and clients on disconnect' {
        $null = Get-IsePxGrid Session -First 1
        $module = Get-Module Ise.Cli
        $session = & $module { $script:IseSession }
        $session.DatasourceState['PxGrid.Secret.extra'] = 'secret'
        Disconnect-Ise -InformationAction SilentlyContinue
        $session.DatasourceState.ContainsKey('PxGrid.Account') | Should -BeFalse
        @($session.DatasourceState.Keys | Where-Object { $_ -like 'PxGrid.Secret.*' }).Count |
            Should -Be 0
    }

    It 'parses STOMP frames without losing headers or JSON bodies' {
        $module = Get-Module Ise.Cli
        $frame = & $module {
            ConvertFrom-IseStompFrame -Frame "MESSAGE`ndestination:/topic/test`n`n{`"value`":1}$([char]0)"
        }
        $frame.Command | Should -Be MESSAGE
        $frame.Headers.destination | Should -Be '/topic/test'
        ($frame.Body | ConvertFrom-Json).value | Should -Be 1
    }
}
