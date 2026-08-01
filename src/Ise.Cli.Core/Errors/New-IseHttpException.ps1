function New-IseHttpException {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [int] $StatusCode,
        [Parameter(Mandatory)] [uri] $Uri,
        [string] $ResponseBody,
        [hashtable] $Context,
        [System.Exception] $InnerException
    )

    $details = if ($Context) { $Context.Clone() } else { @{} }
    $details.StatusCode = $StatusCode
    $details.Uri = $Uri.AbsoluteUri
    $details.ResponseBody = $ResponseBody
    $message = "ISE returned HTTP $StatusCode for $($Uri.AbsoluteUri)."
    switch ($StatusCode) {
        401 { return [IseAuthenticationException]::new($message, $details, $InnerException) }
        403 { return [IseHttpException]::new($message, $details, $InnerException) }
        default { return [IseHttpException]::new($message, $details, $InnerException) }
    }
}
