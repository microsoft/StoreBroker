# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

Add-Type -TypeDefinition @"
    public enum StoreBrokerMigrationType
    {
        None,
        AppConfig,
        IapConfig
    }
"@

function ConvertTo-LatestStoreBroker
{
<#
    .SYNOPSIS
        Top-level function for converting StoreBroker v1 files to the latest v2-compatible version.

    .DESCRIPTION
        Currently, this function migrates v1 app config files to the latest v2 app config schema.
        In-order to migrate the config, the function will need your app's ProductId.
        If you know the ProductId, you can provide it when calling this function
        otherwise, provide your AppId or IapId and the function will do a reverse-lookup
        of the ProductId.  If AppId and IapId are also not provided, the function will check
        the config to see if either value is there. If the function can't determine
        a ProductId, the migration will fail.

        The migrated config will appear in the output path with a suffix of "-v2" on the filename.
        The function will not overwrite an existing file, unless the -Force switch is specified.
        The default outpath is the current working directory.

        The Git repo for this module can be found here: https://aka.ms/StoreBroker

    .PARAMETER ConfigPath
        The path to the config to be migrated.

    .PARAMETER ProductId
        The unique id for your product, as assigned by v2 of the Windows Store Submission API.
        This is NOT the same as the AppId or IapId, which was used in StoreBroker v1.
        If not provided, the function will attempt to look up the ProductId using the provided
        AppId or IapId. If those values are also not provided, the config will be searched for
        any of those values to perform the reverse lookup.

    .PARAMETER AppId
        The unique id for your app, as assigned by v1 of the Windows Store Submission API.
        This is NOT the same as the ProductID. The AppId is only necessary if a ProductId
        is not provided. This value is used to perform a reverse-lookup of the ProductId.

    .PARAMETER IapId
        The unique id for your in-app product, as assigned by v1 of the Windows Store Submission API.
        This is NOT the same as the ProductID. The IapId is only necessary if a ProductId
        is not provided. This value is used to perform a reverse-lookup of the ProductId.

    .PARAMETER OutFilePath
        The filepath where the migrated config will be placed. By default, this is the ConfigPath.
        If the file already exists, it will not be overwritten unless -Force is also specified.

    .PARAMETER Force
        If present, the function will clobber an existing file when writing the final migrated
        config.

    .EXAMPLE
        ConvertTo-LatestStoreBroker -ProductId 00009001234567898765 -ConfigPath ".\config.json" -OutPath "C:\migrated\" -Verbose

        Adds the ProductId of 00009001234567898765 to the config, updates v1 config properties,
        and writes 'C:\migrated\config-v2.json'. Verbose output from the function is written to the
        verbose output stream.

    .EXAMPLE
        ConvertTo-LatestStoreBroker -AppId 0ABCDEF12345 -ConfigPath ".\config.json" -OutPath "C:\migrated\" -Verbose

        Uses the AppId of 0ABCDEF12345 to reverse-lookup a ProductId for the config, updates v1
        config properties, and writes 'C:\migrated\config-v2.json'. Verbose output from the
        function is written to the verbose output stream.

    .EXAMPLE
        ConvertTo-LatestStoreBroker -ConfigPath ".\config.json" -OutPath "C:\migrated" -Force -Verbose

        Finds an AppId in the provided config, performs a reverse-lookup to find a ProductId,
        updates v1 config properties, and writes 'C:\migrated\config-v2.json'. If the output
        file already exists, it is overwritten. Verbose output from the function is written to the
        verbose output stream.
#>
    [CmdletBinding(DefaultParameterSetName = "AppConfigMigration")]
    param(
        [Parameter(
            ParameterSetName = "AppConfigMigration",
            Mandatory)]
        [Parameter(
            ParameterSetName = "IapConfigMigration",
            Mandatory)]
        [ValidateScript({
            if (Test-Path -PathType Leaf -Path $_ -ErrorAction Ignore) { return $true }
            else { throw "ConfigPath does not exist: [$_]." } })]
        [string] $ConfigPath,

        [Parameter(ParameterSetName = "AppConfigMigration")]
        [Parameter(ParameterSetName = "IapConfigMigration")]
        [ValidateScript({
            if ($_.Length -gt 12) { return $true }
            else { throw "A ProductId is greater than 12 characters. The provided ProductId is invalid: [$_]." } })]
        [string] $ProductId,

        [Parameter(ParameterSetName = "AppConfigMigration")]
        [ValidateScript({
            if ($_ -match '\w{12}') { return $true }
            else { throw "An AppId is 12 alphanumeric characters. The provided AppId is invalid: [$_]." } })]
        [string] $AppId,

        [Parameter(ParameterSetName = "IapConfigMigration")]
        [ValidateScript({
            if ($_ -match '\w{12}') { return $true }
            else { throw "An IapId is 12 alphanumeric characters. The provided IapId is invalid: [$_]." } })]
        [string] $IapId,

        [ValidateNotNullOrEmpty()]
        [ValidateScript({
            if (Test-Path -IsValid -PathType Leaf -Path $_ -ErrorAction Ignore) { return $true }
            else { throw "OutFilePath is not a valid filepath: [$_]." } })]
        [string] $OutFilePath = $ConfigPath,

        [switch] $Force
    )

    try
    {
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

        # Convert the config JSON into a manipulatable object.
        Write-Log -Message "Updating config: [$ConfigPath]." -Level Verbose

        $telemetryProperties = @{}
        $convertParams = @{
            ProductId = $ProductId
            AppId = $AppId
            IapId = $IapId
            TelemetryTable = [ref] $telemetryProperties
        }

        # Get the config object and update to the latest schema version.
        $config = Get-Content -Path $ConfigPath -Encoding UTF8 |
            Remove-Comments |
            Out-String |
            ConvertFrom-Json |
            ConvertTo-LatestConfig @convertParams

        # Get the template that determines the order the JSON is written.
        # Write the final migrated config to the requested OutFilePath.
        $configType = if ($null -ne $config.appSubmission) { 'App' }
                      else { 'Iap' }
        $template = Get-OrderedConfigTemplate -Type $configType

        $config |
            ConvertTo-OrderedJson -Template $template |
            Out-File -FilePath $OutFilePath -Encoding utf8 -NoClobber:$(-not $Force)

        Write-Log -Message "Migrated config to: [$OutFilePath]." -Level Verbose

        # Record the telemetry for this event.
        $stopwatch.Stop()
        $telemetryMetrics = @{ [StoreBrokerTelemetryMetric]::Duration = $stopwatch.Elapsed.TotalSeconds }
        Set-TelemetryEvent -EventName ConvertTo-LatestStoreBroker -Properties $telemetryProperties -Metrics $telemetryMetrics
    }
    catch
    {
        Set-TelemetryException -Exception $_.Exception -ErrorBucket ConvertTo-LatestStoreBroker
        Write-Log -Exception $_ -Level Error

        throw
    }
}
