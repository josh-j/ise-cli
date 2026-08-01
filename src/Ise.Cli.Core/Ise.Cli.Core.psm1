Set-StrictMode -Version Latest

$script:IseSession = $null
$script:IseDataSources = [System.Collections.Generic.Dictionary[string, object]]::new(
    [System.StringComparer]::OrdinalIgnoreCase
)
$script:IseSemanticProviders = [System.Collections.Generic.Dictionary[string, object]]::new(
    [System.StringComparer]::OrdinalIgnoreCase
)
$script:IseTraceSinks = [System.Collections.Generic.List[object]]::new()

$files = @(
    'Types/IseException.ps1'
    'Types/IseSession.ps1'
    'Types/IseLogEvent.ps1'
    'Diagnostics/IseEventIds.ps1'
    'Diagnostics/New-IseCorrelationContext.ps1'
    'Diagnostics/Format-IseVerboseMessage.ps1'
    'Diagnostics/Sinks/Write-IseInformationSink.ps1'
    'Diagnostics/Sinks/Write-IseJsonLinesSink.ps1'
    'Diagnostics/Sinks/Write-IseMemorySink.ps1'
    'Diagnostics/Sinks/Register-IseTraceSink.ps1'
    'Diagnostics/Write-IseLogEvent.ps1'
    'Errors/Resolve-IseErrorCategory.ps1'
    'Errors/New-IseHttpException.ps1'
    'Errors/ConvertTo-IseErrorRecord.ps1'
    'DataSources/Test-IseDataSourceDescriptor.ps1'
    'DataSources/Register-IseDataSource.ps1'
    'DataSources/Get-IseDataSource.ps1'
    'DataSources/New-IseConnectionDynamicParameters.ps1'
    'DataSources/Initialize-IseDataSourceConfiguration.ps1'
    'Semantics/Test-IseSemanticProviderDescriptor.ps1'
    'Semantics/Register-IseSemanticProvider.ps1'
    'Semantics/Get-IseSemanticProvider.ps1'
    'Semantics/Invoke-IseSemanticCapability.ps1'
    'Connection/New-IseHttpClient.ps1'
    'Connection/New-IseSession.ps1'
    'Connection/Close-IseSession.ps1'
    'Connection/Assert-IseConnected.ps1'
    'Dispatch/Invoke-IseSourceOperation.ps1'
    'Diagnostics/Commands/Start-IseTrace.ps1'
    'Diagnostics/Commands/Stop-IseTrace.ps1'
    'Diagnostics/Commands/Get-IseTrace.ps1'
    'Commands/Connect-Ise.ps1'
    'Commands/Get-IseConnection.ps1'
    'Commands/Disconnect-Ise.ps1'
)

foreach ($file in $files) {
    . (Join-Path $PSScriptRoot $file)
}
