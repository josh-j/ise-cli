function Add-IseDataConnectTypeName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)] $InputObject,
        [Parameter(Mandatory)] [string] $View,
        $Correlation
    )
    process {
        $words = @($View -split '[^A-Za-z0-9]+' | Where-Object { $_ })
        $suffix = ($words | ForEach-Object {
            $_.Substring(0, 1).ToUpperInvariant() + $_.Substring(1).ToLowerInvariant()
        }) -join ''
        $InputObject.PSObject.TypeNames.Insert(0, "Ise.DataConnect.$suffix")
        Add-IseMetadata -InputObject $InputObject -Metadata @{
            Datasource = 'DataConnect'; Resource = $View
            RetrievedAt = [datetime]::UtcNow; CorrelationId = $Correlation.CorrelationId
        }
    }
}
