function ConvertFrom-IseRestResponse {
    [CmdletBinding()]
    param(
        [string] $Body,
        [string] $ContentType,
        [hashtable] $Context
    )

    if ([string]::IsNullOrEmpty($Body)) { return $null }
    $trimmed = $Body.TrimStart()
    $isJson = $ContentType -match '(?i)(application|text)/(.+\+)?json' -or
        $trimmed.StartsWith('{') -or $trimmed.StartsWith('[')
    if ($isJson) {
        try { return $Body | ConvertFrom-Json -Depth 100 }
        catch {
            throw [IseSerializationException]::new(
                'ISE returned invalid JSON.',
                $Context,
                $_.Exception
            )
        }
    }
    $isXml = $ContentType -match '(?i)(application|text)/(.+\+)?xml' -or
        $trimmed.StartsWith('<')
    if ($isXml) {
        try { return [xml]$Body }
        catch {
            throw [IseSerializationException]::new(
                'ISE returned invalid XML.',
                $Context,
                $_.Exception
            )
        }
    }
    $Body
}
