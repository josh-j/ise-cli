function Resolve-IseErrorCategory {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [System.Exception] $Exception)

    if ($Exception -is [IseAuthenticationException]) { return [System.Management.Automation.ErrorCategory]::AuthenticationError }
    if ($Exception -is [IseCertificateException]) { return [System.Management.Automation.ErrorCategory]::SecurityError }
    if ($Exception -is [IseConnectionException]) {
        if ($Exception.Context.ContainsKey('FailureKind') -and
            $Exception.Context['FailureKind'] -eq 'Timeout') {
            return [System.Management.Automation.ErrorCategory]::OperationTimeout
        }
        return [System.Management.Automation.ErrorCategory]::ConnectionError
    }
    if ($Exception -is [IseSerializationException]) { return [System.Management.Automation.ErrorCategory]::ParserError }
    if ($Exception -is [IsePaginationException]) { return [System.Management.Automation.ErrorCategory]::InvalidData }
    if ($Exception -is [IseDataConnectException]) { return [System.Management.Automation.ErrorCategory]::InvalidOperation }
    if ($Exception -is [IsePxGridException]) { return [System.Management.Automation.ErrorCategory]::InvalidOperation }
    if ($Exception -is [System.TimeoutException] -or $Exception -is [System.Threading.Tasks.TaskCanceledException]) {
        return [System.Management.Automation.ErrorCategory]::OperationTimeout
    }
    if ($Exception -is [IseHttpException] -and $Exception.Context.ContainsKey('StatusCode') -and
        $Exception.Context['StatusCode']) {
        switch ([int]$Exception.Context['StatusCode']) {
            401 { return [System.Management.Automation.ErrorCategory]::AuthenticationError }
            403 { return [System.Management.Automation.ErrorCategory]::PermissionDenied }
            404 { return [System.Management.Automation.ErrorCategory]::ObjectNotFound }
        }
    }
    [System.Management.Automation.ErrorCategory]::InvalidOperation
}
