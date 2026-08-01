BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '../../src/Ise.Cli/Ise.Cli.psd1'
    if (-not (Get-Module Ise.Cli)) { Import-Module $modulePath -Force }
}

Describe 'PowerShell error records' {
    It 'uses a stable error id and structured target when disconnected' {
        Disconnect-Ise -InformationAction SilentlyContinue
        try { Get-IseRestSchema -Ers -ErrorAction Stop }
        catch { $errorRecord = $_ }
        $errorRecord.FullyQualifiedErrorId | Should -Be 'Ise.Connection.NotConnected,Get-IseRestSchema'
        $errorRecord.CategoryInfo.Category | Should -Be 'ConnectionError'
        $errorRecord.TargetObject.Operation | Should -Be 'Connect'
        $errorRecord.TargetObject.CorrelationId | Should -Not -BeNullOrEmpty
    }

    It 'preserves inner exceptions and maps status-specific identity' {
        $module = Get-Module Ise.Cli
        $result = & $module {
            $inner = [System.InvalidOperationException]::new('transport detail')
            $exception = New-IseHttpException -StatusCode 404 `
                -Uri https://ise.example.test/missing -ResponseBody '{"error":"missing"}' `
                -Context @{ Datasource = 'Rest.Ers'; Operation = 'GetById'; Target = 'Endpoint' } `
                -InnerException $inner
            ConvertTo-IseErrorRecord -Exception $exception
        }
        $result.FullyQualifiedErrorId | Should -Be 'Ise.Rest.ResourceNotFound'
        $result.CategoryInfo.Category | Should -Be ObjectNotFound
        $result.Exception.InnerException.Message | Should -Be 'transport detail'
        $result.TargetObject.ResponseBody | Should -Be '{"error":"missing"}'
    }

    It 'maps forbidden responses to PermissionDenied' {
        $module = Get-Module Ise.Cli
        $record = & $module {
            $exception = New-IseHttpException -StatusCode 403 `
                -Uri https://ise.example.test/forbidden -Context @{}
            ConvertTo-IseErrorRecord -Exception $exception
        }
        $record.CategoryInfo.Category | Should -Be PermissionDenied
        $record.FullyQualifiedErrorId | Should -Be 'Ise.Rest.Http.403'
    }
}
