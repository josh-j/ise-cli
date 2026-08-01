class IseException : System.Exception {
    [hashtable] $Context

    IseException([string] $message, [hashtable] $context) : base($message) {
        $this.Context = if ($null -eq $context) { @{} } else { $context }
    }

    IseException(
        [string] $message,
        [hashtable] $context,
        [System.Exception] $innerException
    ) : base($message, $innerException) {
        $this.Context = if ($null -eq $context) { @{} } else { $context }
    }
}

class IseConnectionException : IseException {
    IseConnectionException([string] $message, [hashtable] $context) : base($message, $context) {}
    IseConnectionException([string] $message, [hashtable] $context, [System.Exception] $innerException) : base($message, $context, $innerException) {}
}

class IseAuthenticationException : IseException {
    IseAuthenticationException([string] $message, [hashtable] $context) : base($message, $context) {}
    IseAuthenticationException([string] $message, [hashtable] $context, [System.Exception] $innerException) : base($message, $context, $innerException) {}
}

class IseCertificateException : IseException {
    IseCertificateException([string] $message, [hashtable] $context) : base($message, $context) {}
    IseCertificateException([string] $message, [hashtable] $context, [System.Exception] $innerException) : base($message, $context, $innerException) {}
}

class IseHttpException : IseException {
    IseHttpException([string] $message, [hashtable] $context) : base($message, $context) {}
    IseHttpException([string] $message, [hashtable] $context, [System.Exception] $innerException) : base($message, $context, $innerException) {}
}

class IseDiscoveryException : IseException {
    IseDiscoveryException([string] $message, [hashtable] $context) : base($message, $context) {}
    IseDiscoveryException([string] $message, [hashtable] $context, [System.Exception] $innerException) : base($message, $context, $innerException) {}
}

class IsePaginationException : IseException {
    IsePaginationException([string] $message, [hashtable] $context) : base($message, $context) {}
    IsePaginationException([string] $message, [hashtable] $context, [System.Exception] $innerException) : base($message, $context, $innerException) {}
}

class IseSerializationException : IseException {
    IseSerializationException([string] $message, [hashtable] $context) : base($message, $context) {}
    IseSerializationException([string] $message, [hashtable] $context, [System.Exception] $innerException) : base($message, $context, $innerException) {}
}

class IseDataConnectException : IseException {
    IseDataConnectException([string] $message, [hashtable] $context) : base($message, $context) {}
    IseDataConnectException([string] $message, [hashtable] $context, [System.Exception] $innerException) : base($message, $context, $innerException) {}
}

class IsePxGridException : IseException {
    IsePxGridException([string] $message, [hashtable] $context) : base($message, $context) {}
    IsePxGridException([string] $message, [hashtable] $context, [System.Exception] $innerException) : base($message, $context, $innerException) {}
}
