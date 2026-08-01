function ConvertTo-IseErrorRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [System.Exception] $Exception,
        [string] $ErrorId,
        $TargetObject,
        $Correlation
    )

    $context = if ($Exception -is [IseException]) { $Exception.Context } else { @{} }
    if ($Correlation -and -not $context.ContainsKey('CorrelationId')) {
        $context['CorrelationId'] = $Correlation.CorrelationId
    }
    if (-not $ErrorId) {
        $ErrorId = switch ($Exception.GetType().Name) {
            'IseConnectionException' {
                if ($context.ContainsKey('FailureKind') -and $context['FailureKind'] -eq 'Timeout') {
                    'Ise.Rest.RequestTimeout'
                } else { 'Ise.Connection.Unavailable' }
            }
            'IseAuthenticationException' { 'Ise.Rest.AuthenticationFailed' }
            'IseCertificateException' { 'Ise.Rest.CertificateValidationFailed' }
            'IsePaginationException' {
                if ($Exception.Message -match '(?i)repeat|cycle') { 'Ise.Rest.Pagination.Cycle' }
                else { 'Ise.Rest.Pagination.Invalid' }
            }
            'IseSerializationException' { 'Ise.Rest.Response.InvalidJson' }
            'IseDataConnectException' { 'Ise.DataConnect.OperationFailed' }
            'IsePxGridException' { 'Ise.PxGrid.OperationFailed' }
            default {
                if ($context.ContainsKey('StatusCode') -and $context['StatusCode']) {
                    if ([int]$context['StatusCode'] -eq 404) { 'Ise.Rest.ResourceNotFound' }
                    else { "Ise.Rest.Http.$($context['StatusCode'])" }
                }
                else { 'Ise.Operation.Failed' }
            }
        }
    }
    if ($null -eq $TargetObject) {
        $TargetObject = [pscustomobject]$context
        $TargetObject.PSObject.TypeNames.Insert(0, 'Ise.ErrorContext')
    }
    [System.Management.Automation.ErrorRecord]::new(
        $Exception,
        $ErrorId,
        (Resolve-IseErrorCategory -Exception $Exception),
        $TargetObject
    )
}
