class IseLogEvent {
    [datetime] $Timestamp
    [string] $Level
    [string] $EventId
    [string] $CorrelationId
    [string] $RequestId
    [string] $Command
    [string] $Datasource
    [string] $Operation
    [string] $Target
    [string] $Uri
    [Nullable[int]] $Page
    [Nullable[int]] $StatusCode
    [Nullable[double]] $DurationMilliseconds
    [Nullable[int]] $RecordCount
    [string] $Message
    [object] $Exception
    [hashtable] $Properties

    IseLogEvent() {
        $this.Timestamp = [datetime]::UtcNow
        $this.Properties = @{}
    }
}
