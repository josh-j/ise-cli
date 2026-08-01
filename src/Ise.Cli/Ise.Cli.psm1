Set-StrictMode -Version Latest

$script:IseSession = $null
$script:IseDataSources = [System.Collections.Generic.Dictionary[string, object]]::new(
    [System.StringComparer]::OrdinalIgnoreCase
)
$script:IseSemanticProviders = [System.Collections.Generic.Dictionary[string, object]]::new(
    [System.StringComparer]::OrdinalIgnoreCase
)
$script:IseTraceSinks = [System.Collections.Generic.List[object]]::new()
$sourceProjectRoot = Join-Path $PSScriptRoot '../..'
$script:IseProjectRoot = if (Test-Path (Join-Path $sourceProjectRoot 'schemas')) {
    (Resolve-Path $sourceProjectRoot).Path
} else { $PSScriptRoot }

$sourceCoreRoot = Join-Path $PSScriptRoot '../Ise.Cli.Core'
$coreRoot = if (Test-Path $sourceCoreRoot) { $sourceCoreRoot } else { Join-Path $PSScriptRoot 'Core' }
$coreFiles = @(
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
foreach ($file in $coreFiles) { . (Join-Path $coreRoot $file) }

$sourceRestRoot = Join-Path $PSScriptRoot '../Ise.Cli.Rest'
$restRoot = if (Test-Path $sourceRestRoot) { $sourceRestRoot } else { Join-Path $PSScriptRoot 'Rest' }
$restFiles = @(
    'Client/ConvertTo-IseQueryString.ps1'
    'Client/New-IseRestUri.ps1'
    'Client/ConvertFrom-IseRestResponse.ps1'
    'Client/Send-IseRestRequest.ps1'
    'Output/Add-IseRestTypeName.ps1'
    'Output/Add-IseMetadata.ps1'
    'Discovery/New-IseResourceDescriptor.ps1'
    'Discovery/Merge-IseResourceCatalog.ps1'
    'Discovery/Get-IseSwaggerDocuments.ps1'
    'Connection/Get-IseVersionFromProbe.ps1'
    'Connection/Invoke-IseRestConnectionProbe.ps1'
    'Connection/Open-IseErsConnection.ps1'
    'Connection/Open-IseOpenApiConnection.ps1'
    'Connection/Open-IseMntConnection.ps1'
    'Adapters/Ers/Resolve-IseErsPage.ps1'
    'Adapters/Ers/Get-IseErsCatalog.ps1'
    'Adapters/Ers/Read-IseErsResource.ps1'
    'Adapters/Ers/Register-IseErsAdapter.ps1'
    'Adapters/OpenApi/Resolve-IseOpenApiPage.ps1'
    'Adapters/OpenApi/Get-IseOpenApiCatalog.ps1'
    'Adapters/OpenApi/Read-IseOpenApiResource.ps1'
    'Adapters/OpenApi/Register-IseOpenApiAdapter.ps1'
    'Adapters/Mnt/Resolve-IseMntPage.ps1'
    'Adapters/Mnt/Get-IseMntCatalog.ps1'
    'Adapters/Mnt/Read-IseMntResource.ps1'
    'Adapters/Mnt/Register-IseMntAdapter.ps1'
    'Discovery/Get-IseResourceCatalog.ps1'
    'Commands/Get-IseRest.ps1'
    'Commands/Get-IseRestSchema.ps1'
    'Semantics/Test-IseRestSemanticProvider.ps1'
    'Semantics/Invoke-IseRestEndpointProvider.ps1'
    'Semantics/Invoke-IseRestActiveSessionProvider.ps1'
    'Semantics/Register-IseRestSemanticProviders.ps1'
)
foreach ($file in $restFiles) { . (Join-Path $restRoot $file) }

Register-IseErsAdapter
Register-IseOpenApiAdapter
Register-IseMntAdapter

$sourceDataConnectRoot = Join-Path $PSScriptRoot '../Ise.Cli.DataConnect'
$dataConnectRoot = if (Test-Path $sourceDataConnectRoot) {
    $sourceDataConnectRoot
} else { Join-Path $PSScriptRoot 'DataConnect' }
$dataConnectFiles = @(
    'Client/Set-IseDataConnectConfiguration.ps1'
    'Client/Open-IseDataConnectConnection.ps1'
    'Client/Close-IseDataConnectConnection.ps1'
    'Client/Invoke-IseDataConnectCommand.ps1'
    'Output/Add-IseDataConnectTypeName.ps1'
    'Discovery/Get-IseDataConnectCatalog.ps1'
    'Register-IseDataConnectAdapter.ps1'
    'Commands/Get-IseDataConnect.ps1'
    'Commands/Get-IseDataConnectSchema.ps1'
    'Semantics/Test-IseDataConnectSemanticProvider.ps1'
    'Semantics/Invoke-IseDataConnectSemanticProvider.ps1'
    'Semantics/Register-IseDataConnectSemanticProviders.ps1'
)
foreach ($file in $dataConnectFiles) { . (Join-Path $dataConnectRoot $file) }
Register-IseDataConnectAdapter

$sourcePxGridRoot = Join-Path $PSScriptRoot '../Ise.Cli.PxGrid'
$pxGridRoot = if (Test-Path $sourcePxGridRoot) {
    $sourcePxGridRoot
} else { Join-Path $PSScriptRoot 'PxGrid' }
$pxGridFiles = @(
    'Client/Set-IsePxGridConfiguration.ps1'
    'Client/New-IsePxGridClient.ps1'
    'Control/Get-IsePxGridControlUri.ps1'
    'Client/Invoke-IsePxGridRequest.ps1'
    'Control/Get-IsePxGridAccessSecret.ps1'
    'Control/Initialize-IsePxGridConnection.ps1'
    'Discovery/Get-IsePxGridCatalog.ps1'
    'Output/Add-IsePxGridMetadata.ps1'
    'Client/Read-IsePxGridSnapshot.ps1'
    'Subscription/ConvertFrom-IseStompFrame.ps1'
    'Subscription/Send-IseWebSocketText.ps1'
    'Subscription/Receive-IseWebSocketText.ps1'
    'Subscription/Watch-IsePxGridSubscription.ps1'
    'Client/Close-IsePxGridConnection.ps1'
    'Register-IsePxGridAdapter.ps1'
    'Commands/Get-IsePxGrid.ps1'
    'Commands/Watch-IsePxGrid.ps1'
    'Semantics/Test-IsePxGridSemanticProvider.ps1'
    'Semantics/Invoke-IsePxGridSemanticProvider.ps1'
    'Semantics/Register-IsePxGridSemanticProviders.ps1'
)
foreach ($file in $pxGridFiles) { . (Join-Path $pxGridRoot $file) }
Register-IsePxGridAdapter

Register-IseRestSemanticProviders
Register-IseDataConnectSemanticProviders
Register-IsePxGridSemanticProviders

$sourceFeaturesRoot = Join-Path $PSScriptRoot '../Ise.Cli.Features'
$featuresRoot = if (Test-Path $sourceFeaturesRoot) {
    $sourceFeaturesRoot
} else { Join-Path $PSScriptRoot 'Features' }
$featureFiles = @(
    'Composition/Select-IseMostRecentRecord.ps1'
    'Commands/Get-IseContextVisibility.ps1'
)
foreach ($file in $featureFiles) { . (Join-Path $featuresRoot $file) }

if ($env:ISE_CLI_LOG_PATH) {
    $environmentLevel = if ($env:ISE_CLI_LOG_LEVEL) { $env:ISE_CLI_LOG_LEVEL } else { 'Information' }
    if ($env:ISE_CLI_LOG_FORMAT -and $env:ISE_CLI_LOG_FORMAT -ne 'JsonLines') {
        throw "ISE_CLI_LOG_FORMAT supports only 'JsonLines'."
    }
    $null = Start-IseTrace -Path $env:ISE_CLI_LOG_PATH -Level $environmentLevel
}

$ExecutionContext.SessionState.Module.OnRemove = {
    try { Disconnect-Ise -ErrorAction SilentlyContinue }
    finally { Stop-IseTrace -ErrorAction SilentlyContinue }
}

Export-ModuleMember -Function @(
    'Connect-Ise'
    'Get-IseConnection'
    'Disconnect-Ise'
    'Get-IseRest'
    'Get-IseRestSchema'
    'Get-IseDataConnect'
    'Get-IseDataConnectSchema'
    'Get-IsePxGrid'
    'Watch-IsePxGrid'
    'Get-IseContextVisibility'
    'Start-IseTrace'
    'Stop-IseTrace'
    'Get-IseTrace'
)
