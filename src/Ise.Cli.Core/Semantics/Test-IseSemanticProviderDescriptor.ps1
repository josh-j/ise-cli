function Test-IseSemanticProviderDescriptor {
    [CmdletBinding()]
    param([Parameter(Mandatory)] $Descriptor)

    foreach ($property in @('Name', 'Capability', 'Source', 'Invoke')) {
        if ($Descriptor.PSObject.Properties.Name -notcontains $property -or
            [string]::IsNullOrWhiteSpace([string]$Descriptor.$property)) {
            throw [System.ArgumentException]::new("Semantic provider is missing '$property'.")
        }
    }
    if (-not (Get-IseDataSource -Name $Descriptor.Source)) {
        throw [System.ArgumentException]::new(
            "Semantic provider '$($Descriptor.Name)' references unknown datasource '$($Descriptor.Source)'."
        )
    }
    foreach ($commandName in @($Descriptor.Invoke, $Descriptor.Test | Where-Object { $_ })) {
        if (-not (Get-Command -Name $commandName -CommandType Function, Cmdlet -ErrorAction SilentlyContinue)) {
            throw [System.ArgumentException]::new(
                "Semantic provider '$($Descriptor.Name)' command '$commandName' does not resolve."
            )
        }
    }
    $true
}
