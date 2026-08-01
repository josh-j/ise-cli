function Close-IseSession {
    [CmdletBinding()]
    param([IseSession] $Session = $script:IseSession)

    if ($null -eq $Session -or $Session.Disposed) { return }
    foreach ($descriptor in @($script:IseDataSources.Values)) {
        if (-not $descriptor.Close) { continue }
        try { & $descriptor.Close -Session $Session }
        catch {
            Write-Error -ErrorId 'Ise.DataSource.CloseFailed' -Category CloseError `
                -TargetObject $descriptor -Message $_.Exception.Message
        }
    }
    $Session.Dispose()
}
