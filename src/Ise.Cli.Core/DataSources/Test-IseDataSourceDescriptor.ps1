function Test-IseDataSourceDescriptor {
    [CmdletBinding()]
    param([Parameter(Mandatory)] $Descriptor)

    foreach ($property in @('Name', 'DisplayName', 'Capabilities', 'Operations')) {
        if ($Descriptor.PSObject.Properties.Name -notcontains $property) {
            throw [System.ArgumentException]::new("Datasource descriptor is missing '$property'.")
        }
    }
    if ([string]::IsNullOrWhiteSpace([string]$Descriptor.Name)) {
        throw [System.ArgumentException]::new('Datasource descriptor Name cannot be empty.')
    }
    if ($Descriptor.Operations -isnot [System.Collections.IDictionary]) {
        throw [System.ArgumentException]::new('Datasource descriptor Operations must be a dictionary.')
    }
    foreach ($capability in @($Descriptor.Capabilities)) {
        if (-not $Descriptor.Operations.Contains($capability)) {
            throw [System.ArgumentException]::new(
                "Datasource '$($Descriptor.Name)' advertises '$capability' without an operation."
            )
        }
        $commandName = [string]$Descriptor.Operations[$capability]
        if (-not (Get-Command -Name $commandName -CommandType Function, Cmdlet -ErrorAction SilentlyContinue)) {
            throw [System.ArgumentException]::new(
                "Datasource '$($Descriptor.Name)' operation '$commandName' does not resolve."
            )
        }
    }
    foreach ($hook in @('Configure', 'Open', 'Close')) {
        if ($Descriptor.PSObject.Properties.Name -notcontains $hook -or -not $Descriptor.$hook) {
            continue
        }
        if (-not (Get-Command -Name ([string]$Descriptor.$hook) `
                -CommandType Function, Cmdlet -ErrorAction SilentlyContinue)) {
            throw [System.ArgumentException]::new(
                "Datasource '$($Descriptor.Name)' lifecycle hook '$($Descriptor.$hook)' does not resolve."
            )
        }
    }
    $metadata = if ($Descriptor.PSObject.Properties.Name -contains 'Metadata') {
        $Descriptor.Metadata
    } else { $null }
    $hasConnectionParameters = $metadata -and $(
        if ($metadata -is [System.Collections.IDictionary]) {
            $metadata.Contains('ConnectionParameters')
        } else {
            $metadata.PSObject.Properties.Name -contains 'ConnectionParameters'
        }
    )
    if ($hasConnectionParameters) {
        $hasConfigure = $Descriptor.PSObject.Properties.Name -contains 'Configure' -and
            $Descriptor.Configure
        $names = [System.Collections.Generic.HashSet[string]]::new(
            [System.StringComparer]::OrdinalIgnoreCase
        )
        foreach ($definition in @($metadata.ConnectionParameters)) {
            if (-not $definition.Name -or -not $definition.ParameterType) {
                throw [System.ArgumentException]::new(
                    "Datasource '$($Descriptor.Name)' has an invalid connection parameter definition."
                )
            }
            if ([string]$definition.Name -notmatch '^[A-Za-z][A-Za-z0-9]*$') {
                throw [System.ArgumentException]::new(
                    "Datasource connection parameter '$($definition.Name)' is not a valid PowerShell name."
                )
            }
            if (-not $names.Add([string]$definition.Name)) {
                throw [System.ArgumentException]::new(
                    "Datasource '$($Descriptor.Name)' repeats connection parameter '$($definition.Name)'."
                )
            }
            $hasSessionStateKey = if ($definition -is [System.Collections.IDictionary]) {
                $definition.Contains('SessionStateKey') -and $definition['SessionStateKey']
            } else {
                $definition.PSObject.Properties.Name -contains 'SessionStateKey' -and
                    $definition.SessionStateKey
            }
            if (-not $hasConfigure -and -not $hasSessionStateKey) {
                throw [System.ArgumentException]::new(
                    "Datasource '$($Descriptor.Name)' connection parameter '$($definition.Name)' " +
                    'has neither a Configure hook nor a SessionStateKey.'
                )
            }
        }
    }
    $true
}
