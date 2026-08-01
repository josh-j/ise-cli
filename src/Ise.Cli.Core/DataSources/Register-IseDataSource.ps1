function Register-IseDataSource {
    [CmdletBinding()]
    param([Parameter(Mandatory)] $Descriptor)

    $null = Test-IseDataSourceDescriptor -Descriptor $Descriptor
    if ($script:IseDataSources.ContainsKey([string]$Descriptor.Name)) {
        throw [System.InvalidOperationException]::new(
            "Datasource '$($Descriptor.Name)' is already registered."
        )
    }
    $reserved = @('Server', 'Credential', 'SkipCertificateCheck', 'TimeoutSec')
    $existingParameters = @(
        foreach ($existing in @($script:IseDataSources.Values)) {
            if (-not $existing.Metadata) { continue }
            $hasDefinitions = if ($existing.Metadata -is [System.Collections.IDictionary]) {
                $existing.Metadata.Contains('ConnectionParameters')
            } else {
                $existing.Metadata.PSObject.Properties.Name -contains 'ConnectionParameters'
            }
            if ($hasDefinitions) { @($existing.Metadata.ConnectionParameters).Name }
        }
    )
    if ($Descriptor.PSObject.Properties.Name -contains 'Metadata' -and $Descriptor.Metadata) {
        $hasDefinitions = if ($Descriptor.Metadata -is [System.Collections.IDictionary]) {
            $Descriptor.Metadata.Contains('ConnectionParameters')
        } else {
            $Descriptor.Metadata.PSObject.Properties.Name -contains 'ConnectionParameters'
        }
        if ($hasDefinitions) {
            foreach ($name in @($Descriptor.Metadata.ConnectionParameters).Name) {
                if ($name -in $reserved -or $name -in $existingParameters) {
                    throw [System.InvalidOperationException]::new(
                        "Datasource connection parameter '$name' conflicts with an existing parameter."
                    )
                }
            }
        }
    }
    $script:IseDataSources.Add([string]$Descriptor.Name, $Descriptor)
}
