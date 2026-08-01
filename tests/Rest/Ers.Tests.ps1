BeforeAll {
    $manifestPath = Join-Path $PSScriptRoot '../../schemas/rest/ers/manifest.json'
}

Describe 'Bundled ERS catalog' {
    It 'contains valid, unique enumerable resources' {
        $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
        $manifest.resources.Count | Should -BeGreaterThan 5
        @($manifest.resources.name | Sort-Object -Unique).Count |
            Should -Be $manifest.resources.Count
        @($manifest.resources | Where-Object { -not $_.collectionPath.StartsWith('/ers/') }) |
            Should -BeNullOrEmpty
    }
}
