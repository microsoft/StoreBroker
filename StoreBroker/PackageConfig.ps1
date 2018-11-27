# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

# Define Script-scoped, readonly, hidden variables.
@{
    # Default file name of the AppConfig and IapConfig in the module folder
    defaultConfigFileName = "AppConfigTemplate.ps1"
    defaultIapConfigFileName = "IapConfigTemplate.ps1"

    # Schema version property in the AppConfig and IapConfig
    configSchemaVersionProperty = "schemaVersion"

    # Minimum supported schema version for AppConfig and IapConfig.
    minAppConfigSchemaVersion = 1
    minIapConfigSchemaVersion = 1

    # Maximum supported schema version for AppConfig and IapConfig.
    maxAppConfigSchemaVersion = 2
    maxIapConfigSchemaVersion = 2

    # Note that we are intentionally using backslash, '\', for the uri instead of
    # forward slash, '/'. PackageTool must support v1 configs, meaning that it should
    # still parse out C-style comments. If the help uri contained a forward slash,
    # then, it would be broken when the line was filtered for comments.
    # Instead of using a complicated regular expression or parser to determine if
    # the comment delimeter was appearing in a valid uri or not, we choose to use
    # backslash for the uri, as it is interpreted correctly in modern browsers.
    configHelpUri = 'https:\\aka.ms\StoreBroker_Config'

}.GetEnumerator() | ForEach-Object {
    Set-Variable -Force -Scope Script -Option ReadOnly -Visibility Private -Name $_.Key -Value $_.Value
}

function New-StoreBrokerConfigFile
{
<#
    .SYNOPSIS
        Creates a new configuration file as a template for an app submission.

    .DESCRIPTION
        Creates a new configuration file as a template for an app submission.
        The full path to the new file can be provided by the -Path parameter.

        The Git repo for this module can be found here: https://aka.ms/StoreBroker

    .PARAMETER Path
        A full path specifying where the new config file will go and what it will be
        named.  It is recommended to use the .json file extension.

    .PARAMETER AppId
        If specified, this will pre-populate the app config portion of the
        configuration file with the values from the most recent submission for this
        AppId.

    .EXAMPLE
        New-StoreBrokerConfigFile -Path "C:\users\alias\NewAppConfig.json"

        Creates the config file template "NewAppConfig.json" under "C:\users\alias"

    .EXAMPLE
        New-StoreBrokerConfigFile -Path "C:\users\alias\NewAppConfig.json" -WhatIf

        This example is the same as Example 1 except no config file will be created.  The
        function will report on the actions it would have taken, instead.

    .EXAMPLE
        New-StoreBrokerConfigFile -Path "C:\users\alias\NewAppConfig.json" -AppId 0ABCDEF12345

        Creates the config file template "NewAppConfig.json" under "C:\users\alias", but sets
        the values for the app config portion to be those from the most recent submission for
        AppId 0ABCDEF12345.
#>
    [CmdletBinding(SupportsShouldProcess)]
    [Alias('New-PackageToolConfigFile')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="Methods called within here make use of PSShouldProcess, and the switch is passed on to them inherently.")]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({ if ((Split-Path -Leaf $_) -like "*.*") { $true } else { throw "Path must include filename." } })]
        [string] $Path,

        [string] $AppId = ""
    )

    $dir = Split-Path -Parent -Path $Path
    if (-not (Test-Path -PathType Container -Path $dir -ErrorAction Ignore))
    {
        Write-Log -Message "Creating directory: $dir" -Level Verbose
        New-Item -Force -ItemType Directory -Path $dir | Out-Null
        Write-Log -Message "Created directory." -Level Verbose
    }

    $sourcePath = Join-Path -Path $PSScriptRoot -ChildPath $script:defaultConfigFileName

    # Get-Content returns an array of lines.... using Out-String gives us back the linefeeds.
    $template = (Get-Content -Path $sourcePath -Encoding UTF8) | Out-String

    if (-not ([String]::IsNullOrEmpty($AppId)))
    {
        $template = Get-StoreBrokerConfigFileContentForAppId -ConfigContent $template -AppId $AppId
    }

    Write-Log -Message "Copying (Item: $sourcePath) to (Target: $Path)." -Level Verbose
    Set-Content -Path $Path -Value $template -Encoding UTF8 -Force
    Write-Log -Message "Copy complete." -Level Verbose

    $telemetryProperties = @{ [StoreBrokerTelemetryProperty]::AppId = $AppId }
    Set-TelemetryEvent -EventName New-StoreBrokerConfigFile -Properties $telemetryProperties
}

function Get-StoreBrokerConfigFileContentForAppId
{
<#
    .SYNOPSIS
        Updates the default configuration file template with the values from the
        indicated App's most recent published submission.

    .DESCRIPTION
        Updates the default configuration file template with the values from the
        indicated App's most recent published submission.

        The Git repo for this module can be found here: https://aka.ms/StoreBroker

    .PARAMETER ConfigContent
        The content of the config file template as a simple string.

    .PARAMETER AppId
        The AppId whose most recent submission should be retrieved and used to fill
        in the default values of the template content.

    .EXAMPLE
        Get-StoreBrokerConfigFileContentForAppId -ConfigContent $template -AppId 0ABCDEF12345

        Assuming that $template has the content of the template file read in from disk and
        merged into a single string, this then gets the most recent app submission for
        AppId 0ABCDEF12345 and replaces the default values in the template with those from
        that submission.

    .OUTPUTS
        System.String - The template content modified with the values from the
                        most recent app submission.

    .NOTES
        We use regular expression matching within the implementation rather than operating
        on the content as a JSON object, because we want to retain all of the comments that
        are part of the template content.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $ConfigContent,

        [Parameter(Mandatory)]
        [string] $AppId
    )

    $updated = $ConfigContent

    try
    {
        $app = Get-Application -AppId $AppId

        if ([String]::IsNullOrEmpty($app.lastPublishedApplicationSubmission.id))
        {
            throw "Specified AppId has no published submission to copy settings from."
        }

        $sub = Get-ApplicationSubmission -AppId $AppId -SubmissionId $($app.lastPublishedApplicationSubmission.id)

        $updated = $updated -replace '"appId": ".*",', "`"appId`": $($AppId | ConvertTo-Json),"

        # PUBLISH MODE AND VISIBILITY
        $updated = $updated -replace '"targetPublishMode": ".*",', "`"targetPublishMode`": $($sub.targetPublishMode | ConvertTo-Json),"
        $updated = $updated -replace '"targetPublishDate": .*,', "`"targetPublishDate`": $($sub.targetPublishDate | ConvertTo-Json),"
        $updated = $updated -replace '"visibility": ".*",', "`"visibility`": $($sub.visibility | ConvertTo-Json),"

        # PRICING AND AVAILABILITY
        $updated = $updated -replace '"priceId": ".*",', "`"priceId`": $($sub.pricing.priceId | ConvertTo-Json),"
        $updated = $updated -replace '"trialPeriod": ".*",', "`"trialPeriod`": $($sub.pricing.trialPeriod | ConvertTo-Json),"

        $marketSpecificPricings = $sub.pricing.marketSpecificPricings | ConvertTo-Json -Depth $script:jsonConversionDepth
        $updated = $updated -replace '(\s+)"marketSpecificPricings": {.*(\r|\n)+\s*}', "`$1`"marketSpecificPricings`": $marketSpecificPricings"

        $sales = $sub.pricing.sales | ConvertTo-Json -Depth $script:jsonConversionDepth
        if ($null -eq $sales) { $sales = "[ ]" }
        $updated = $updated -replace '(\s+)"sales": \[.*(\r|\n)+\s*\]', "`$1`"sales`": $sales"

        $families = $sub.allowTargetFutureDeviceFamilies
        foreach ($family in ("Xbox", "Team", "Holographic", "Desktop", "Mobile"))
        {
            if ($families -match $family)
            {
                $updated = $updated -replace "`"$family`": [^,\r\n]*(,)?", "`"$family`": $($families.$family | ConvertTo-Json)`$1"
            }
            else
            {
                $updated = $updated -replace "`"$family`": [^,\r\n]*(,)?", "// `"$family`": false`$1"
            }
        }

        $updated = $updated -replace '"allowMicrosoftDecideAppAvailabilityToFutureDeviceFamilies": .*,', "`"allowMicrosoftDecideAppAvailabilityToFutureDeviceFamilies`": $($sub.allowMicrosoftDecideAppAvailabilityToFutureDeviceFamilies | ConvertTo-Json),"
        $updated = $updated -replace '"enterpriseLicensing": ".*",', "`"enterpriseLicensing`": $($sub.enterpriseLicensing | ConvertTo-Json),"

        # APP PROPERTIES
        $updated = $updated -replace '"applicationCategory": ".*",', "`"applicationCategory`": $($sub.applicationCategory | ConvertTo-Json),"

        $hardwarePreferences = $sub.hardwarePreferences | ConvertTo-Json -Depth $script:jsonConversionDepth
        if ($null -eq $hardwarePreferences) { $hardwarePreferences = "[ ]" }
        $updated = $updated -replace '(\s+)"hardwarePreferences": \[.*(\r|\n)+\s*\]', "`$1`"hardwarePreferences`": $hardwarePreferences"

        $updated = $updated -replace '"hasExternalInAppProducts": .*,', "`"hasExternalInAppProducts`": $($sub.hasExternalInAppProducts | ConvertTo-Json),"
        $updated = $updated -replace '"meetAccessibilityGuidelines": .*,', "`"meetAccessibilityGuidelines`": $($sub.meetAccessibilityGuidelines | ConvertTo-Json),"
        $updated = $updated -replace '"canInstallOnRemovableMedia": .*,', "`"canInstallOnRemovableMedia`": $($sub.canInstallOnRemovableMedia | ConvertTo-Json),"
        $updated = $updated -replace '"automaticBackupEnabled": .*,', "`"automaticBackupEnabled`": $($sub.automaticBackupEnabled | ConvertTo-Json),"
        $updated = $updated -replace '"isGameDvrEnabled": .*,', "`"isGameDvrEnabled`": $($sub.isGameDvrEnabled | ConvertTo-Json),"

        # GAMING OPTIONS
        if ($null -ne $sub.gamingOptions)
        {
            $gamingOptionsGenres = $sub.gamingOptions.genres | ConvertTo-Json -Depth $script:jsonConversionDepth
            if ($null -eq $gamingOptionsGenres) { $gamingOptionsGenres = "[ ]" }
            $updated = $updated -replace '(\s+)"genres": \[.*(\r|\n)+\s*\]', "`$1`"genres`": $gamingOptionsGenres"

            $updated = $updated -replace '"isLocalMultiplayer": .*,', "`"isLocalMultiplayer`": $($sub.gamingOptions.isLocalMultiplayer | ConvertTo-Json),"
            $updated = $updated -replace '"isLocalCooperative": .*,', "`"isLocalCooperative`": $($sub.gamingOptions.isLocalCooperative | ConvertTo-Json),"
            $updated = $updated -replace '"isOnlineMultiplayer": .*,', "`"isOnlineMultiplayer`": $($sub.gamingOptions.isOnlineMultiplayer | ConvertTo-Json),"
            $updated = $updated -replace '"isOnlineCooperative": .*,', "`"isOnlineCooperative`": $($sub.gamingOptions.isOnlineCooperative | ConvertTo-Json),"

            $localMultiplayerMinPlayers = $sub.gamingOptions.localMultiplayerMinPlayers
            if ($null -eq $localMultiplayerMinPlayers) { $localMultiplayerMinPlayers = 0 }
            $updated = $updated -replace '"localMultiplayerMinPlayers": .*,', "`"localMultiplayerMinPlayers`": $localMultiplayerMinPlayers,"

            $localMultiplayerMaxPlayers = $sub.gamingOptions.localMultiplayerMaxPlayers
            if ($null -eq $localMultiplayerMaxPlayers) { $localMultiplayerMaxPlayers = 0 }
            $updated = $updated -replace '"localMultiplayerMaxPlayers": .*,', "`"localMultiplayerMaxPlayers`": $localMultiplayerMaxPlayers,"

            $localCooperativeMinPlayers = $sub.gamingOptions.localCooperativeMinPlayers
            if ($null -eq $localCooperativeMinPlayers) { $localCooperativeMinPlayers = 0 }
            $updated = $updated -replace '"localCooperativeMinPlayers": .*,', "`"localCooperativeMinPlayers`": $localCooperativeMinPlayers,"

            $localCooperativeMaxPlayers = $sub.gamingOptions.localCooperativeMaxPlayers
            if ($null -eq $localCooperativeMaxPlayers) { $localCooperativeMaxPlayers = 0 }
            $updated = $updated -replace '"localCooperativeMaxPlayers": .*,', "`"localCooperativeMaxPlayers`": $localCooperativeMaxPlayers,"

            $updated = $updated -replace '"isBroadcastingPrivilegeGranted": .*,', "`"isBroadcastingPrivilegeGranted`": $($sub.gamingOptions.isBroadcastingPrivilegeGranted | ConvertTo-Json),"
            $updated = $updated -replace '"isCrossPlayEnabled": .*,', "`"isCrossPlayEnabled`": $($sub.gamingOptions.isCrossPlayEnabled | ConvertTo-Json),"
            $updated = $updated -replace '"kinectDataForExternal": .*', "`"kinectDataForExternal`": $($sub.gamingOptions.kinectDataForExternal | ConvertTo-Json)"
        }

        # NOTES FOR CERTIFICATION
        $notesForCertification = Get-EscapedJsonValue -Value $sub.notesForCertification
        $updated = $updated -replace '"notesForCertification": ""', "`"notesForCertification`": `"$notesForCertification`""

        return $updated
    }
    catch
    {
        Write-Log -Message "Encountered problems getting current application submission values:" -Exception $_ -Level Error
        throw
    }
}

function New-StoreBrokerInAppProductConfigFile
{
<#
    .SYNOPSIS
        Creates a new configuration file as a template for an In-App Product submission.

    .DESCRIPTION
        Creates a new configuration file as a template for an In-App Product submission.
        The full path to the new file can be provided by the -Path parameter.

        The Git repo for this module can be found here: https://aka.ms/StoreBroker

    .PARAMETER Path
        A full path specifying where the new config file will go and what it will be
        named.  It is recommended to use the .json file extension.

    .PARAMETER IapId
        If specified, this will pre-populate the Iap config portion of the
        configuration file with the values from the most recent submission for this
        IapId.

    .EXAMPLE
        New-StoreBrokerConfigFile -Path "C:\users\alias\NewIapConfig.json"

        Creates the config file template "NewIapConfig.json" under "C:\users\alias"

    .EXAMPLE
        New-StoreBrokerInAppProductConfigFile -Path "C:\users\alias\NewIapConfig.json" -WhatIf

        This example is the same as Example 1 except no config file will be created.  The
        function will report on the actions it would have taken, instead.

    .EXAMPLE
        New-StoreBrokerInAppProductConfigFile -Path "C:\users\alias\NewIapConfig.json" -AppId 0ABCDEF12345

        Creates the config file template "NewIapConfig.json" under "C:\users\alias", but sets
        the values for the app config portion to be those from the most recent submission for
        IapId 0ABCDEF12345.
#>
    [CmdletBinding(SupportsShouldProcess)]
    [Alias('New-StoreBrokerIapConfigFile')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="Methods called within here make use of PSShouldProcess, and the switch is passed on to them inherently.")]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({ if ((Split-Path -Leaf $_) -like "*.*") { $true } else { throw "Path must include filename." } })]
        [string] $Path,

        [string] $IapId = ""
    )

    $dir = Split-Path -Parent -Path $Path
    if (-not (Test-Path -PathType Container -Path $dir -ErrorAction Ignore))
    {
        Write-Log -Message "Creating directory: $dir" -Level Verbose
        New-Item -Force -ItemType Directory -Path $dir | Out-Null
        Write-Log -Message "Created directory." -Level Verbose
    }

    $sourcePath = Join-Path -Path $PSScriptRoot -ChildPath $script:defaultIapConfigFileName

    # Get-Content returns an array of lines.... using Out-String gives us back the linefeeds.
    $template = (Get-Content -Path $sourcePath -Encoding UTF8) | Out-String

    if (-not ([String]::IsNullOrEmpty($IapId)))
    {
        $template = Get-StoreBrokerConfigFileContentForIapId -ConfigContent $template -IapId $IapId
    }

    Write-Log -Message "Copying (Item: $sourcePath) to (Target: $Path)." -Level Verbose
    Set-Content -Path $Path -Value $template -Encoding UTF8 -Force
    Write-Log -Message "Copy complete." -Level Verbose

    $telemetryProperties = @{ [StoreBrokerTelemetryProperty]::IapId = $IapId }
    Set-TelemetryEvent -EventName New-StoreBrokerIapConfigFile -Properties $telemetryProperties
}

function Get-StoreBrokerConfigFileContentForIapId
{
<#
    .SYNOPSIS
        Updates the default IAP configuration file template with the values from the
        indicated IAP's most recent submission.

    .DESCRIPTION
        Updates the default IAP configuration file template with the values from the
        indicated IAP's most recent submission.

        The Git repo for this module can be found here: https://aka.ms/StoreBroker

    .PARAMETER ConfigContent
        The content of the config file template as a simple string.

    .PARAMETER IapId
        The IapId whose most recent submission should be retrieved and used to fill
        in the default values of the template content.

    .EXAMPLE
        Get-StoreBrokerConfigFileContentForIapId -ConfigContent $template -IapId 0ABCDEF12345

        Assuming that $template has the content of the template file read in from disk and
        merged into a single string, this then gets the most recent IAP submission for
        IapId 0ABCDEF12345 and replaces the default values in the template with those from
        that submission.

    .OUTPUTS
        System.String - The template content modified with the values from the
                        most recent IAP submission.

    .NOTES
        We use regular expression matching within the implementation rather than operating
        on the content as a JSON object, because we want to retain all of the comments that
        are part of the template content.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $ConfigContent,

        [Parameter(Mandatory)]
        [string] $IapId
    )

    $updated = $ConfigContent

    try
    {
        $iap = Get-InAppProduct -IapId $IapId

        $submissionId = $iap.lastPublishedInAppProductSubmission.id
        if ([String]::IsNullOrEmpty($submissionId))
        {
            $submissionId = $iap.pendingInAppProductSubmission.id
            Write-Log -Message "No published submission exists for this In-App Product.  Using the current pending submission." -Level Warning
        }

        $sub = Get-InAppProductSubmission -IapId $IapId -SubmissionId $submissionId

        $updated = $updated -replace '"iapId": "",', "`"iapId`": `"$IapId`","

        # PUBLISH MODE AND VISIBILITY
        $updated = $updated -replace '"targetPublishMode": ".*",', "`"targetPublishMode`": `"$($sub.targetPublishMode)`","
        $updated = $updated -replace '"targetPublishDate": .*,', "`"targetPublishDate`": `"$($sub.targetPublishDate)`","
        $updated = $updated -replace '"visibility": ".*",', "`"visibility`": `"$($sub.visibility)`","

        # PRICING AND AVAILABILITY
        $updated = $updated -replace '"priceId": ".*",', "`"priceId`": `"$($sub.pricing.priceId)`","

        $marketSpecificPricings = $sub.pricing.marketSpecificPricings | ConvertTo-Json -Depth $script:jsonConversionDepth
        $updated = $updated -replace '(\s+)"marketSpecificPricings": {.*(\r|\n)+\s*}', "`$1`"marketSpecificPricings`": $marketSpecificPricings"

        # PROPERTIES
        $updated = $updated -replace '"lifetime": ".*",', "`"lifetime`": `"$($sub.lifetime)`","
        $updated = $updated -replace '"contentType": ".*",', "`"contentType`": `"$($sub.contentType)`","

        $tag = Get-EscapedJsonValue -Value $sub.tag
        $updated = $updated -replace '"tag": ""', "`"tag`": `"$tag`""

        $keywords = $sub.keywords | ConvertTo-Json -Depth $script:jsonConversionDepth
        if ($null -eq $keywords) { $keywords = "[ ]" }
        $updated = $updated -replace '(\s+)"keywords": \[.*(\r|\n)+\s*\]', "`$1`"keywords`": $keywords"

        # NOTES FOR CERTIFICATION
        $notesForCertification = Get-EscapedJsonValue -Value $sub.notesForCertification
        $updated = $updated -replace '"notesForCertification": ""', "`"notesForCertification`": `"$notesForCertification`""

        return $updated
    }
    catch
    {
        Write-Log -Message "Encountered problems getting current In-App Product submission values:" -Exception $_ -Level Error
        throw
    }
}

function Get-Config
{
<#
    .SYNOPSIS
        Opens the specified config file, removes comments, checks schema version,
        migrates to latest schema version, and returns the config object.

    .PARAMETER ConfigPath
        Full path to a .json file which will be interpreted as the Packaging Tool's config file.

    .PARAMETER VersionProperty
        The name of the property containing the config's schema version.

    .PARAMETER MinSupportedVersion
        The minimum config schema version supported by this version of PackageTool.

    .PARAMETER MaxSupportedVersion
        The maximum config schema version supported by this version of PackageTool.

    .OUTPUTS
        PSCustomObject

    .EXAMPLE
        Convert-AppConfig -ConfigPath 'C:\Some\Path\MapsConfig.json' -VersionProperty configSchemaVersion -MinSupportedVersion 2 -MaxSupportedVersion 3

        Validates the config's schema version is between 2-3, then
        returns MapsConfig.json represented as a PSCustomObject
#>
    param(
        [Parameter(Mandatory)]
        [ValidateScript({
            if (Test-Path -PathType Leaf $_ -ErrorAction Ignore) { return $true }
            else { throw "ConfigPath is not a file or cannot be found: [$_]." } })]
        [string] $ConfigPath,

        [string] $VersionProperty = $script:configSchemaVersionProperty,

        [Parameter(Mandatory)]
        [int] $MinSupportedVersion,

        [Parameter(Mandatory)]
        [int] $MaxSupportedVersion
    )

    if ($MinSupportedVersion -gt $MaxSupportedVersion)
    {
        $out = @()
        $out += "Unexpected min-max versions passed to Convert-AppConfig."
        $out += "The minimum supported schema version [$MinSupportedVersion] is greater than the maximum [$MaxSupportedVersion]."
        $out = $out -join [Environment]::NewLine

        Write-Log -Message $out -Level Error
        throw $out
    }

    # Convert the input config into an object
    $configObj = Get-Content -Path $ConfigPath -Encoding UTF8 |
        Remove-Comments |
        Out-String |
        ConvertFrom-Json

    # Validate we support this version of the config
    $configSchemaVersion = if ($null -eq $configObj.$VersionProperty) { 1 }
                           else { $configObj.$VersionProperty }

    if ($configSchemaVersion -isnot [int])
    {
        $out = @()
        $out += "For the config: [$ConfigPath]."
        $out += "Expected to find an integer value for the '$VersionProperty' property in the config,"
        $out += "but found a different type."
        $out += "This likely means you are using a config for StoreBroker v1, which is not supported for v2."
        $out += "You can migrate your config by running the following command:"
        $out += "    ConvertTo-LatestStoreBroker -ConfigPath `"$ConfigPath`" -Verbose"
        $out += ""
        $out += "For more information on ConvertTo-LatestStoreBroker and how to use it, run:"
        $out += "    help ConvertTo-LatestStoreBroker"
        $out = $out -join [Environment]::NewLine

        Write-Log -Message $out -Level Error
        throw $out
    }
    elseif ($configSchemaVersion -lt $MinSupportedVersion)
    {
        $out = @()
        $out += "For the config: [$ConfigPath]."
        $out += "The config schema version [$configSchemaVersion] is less than the minimum supported"
        $out += "schema version [$MinSupportedVersion] for this version of PackageTool."
        $out += "To update to the latest supported schema version [$MaxSupportedVersion], run the following command:"
        $out += "    ConvertTo-LatestStoreBroker -ConfigPath `"$ConfigPath`" -Verbose"
        $out += ""
        $out += "For more information on ConvertTo-LatestStoreBroker and how to use it, run:"
        $out += "    help ConvertTo-LatestStoreBroker"
        $out = $out -join [Environment]::NewLine

        Write-Log -Message $out -Level Error
        throw $out
    }
    elseif ($configSchemaVersion -gt $MaxSupportedVersion)
    {
        $out = @()
        $out += "For the config: [$ConfigPath]."
        $out += "The config schema version [$configSchemaVersion] is greater than the max currently supported schema version [$MaxSupportedVersion]."
        $out += "Please be sure you're using the right version of StoreBroker with your config file."
        $out = $out -join [Environment]::NewLine

        Write-Log -Message $out -Level Error
        throw $out
    }

    # Migrate the config to the latest config schema version
    # and return the result.
    $configObj |
        ConvertTo-LatestConfig |
        Write-Output
}

filter Remove-Comments
{
<#
    .SYNOPSIS
        Removes in-line comments starting with the comment delimiter
        (default is two forward-slashes "//"). Also removes any lines
        with only white-space.

    .PARAMETER CommentDelimiter
        String specifying the comment delimiter to use.  Default is two
        forward-slashes, i.e. "//"

    .PARAMETER Line
        The lines to be filtered.  Normally this filter receives the lines
        as input from the pipeline.

    .OUTPUTS
        System.Object[]  The filtered collection of lines

    .EXAMPLE
        "example", "test // input", "// remove this" | Remove-Comments

        "example", "test "
#>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "", Justification="Removing comments (plural) is the intuitive way we understand the behavior of this function.")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "", Justification="Does not cause any change to system state. No value gained from ShouldProcess in this specific instance.")]
    param(
        [string] $CommentDelimiter = "//",

        [Parameter(
            Mandatory,
            ValueFromPipeline)]
        [AllowEmptyString()]
        [string[]] $Line
    )

    # Filter text following the comment delimiter, empty lines, and lines that are only whitespace.
    $Line |
        ForEach-Object { ($_ -split $CommentDelimiter)[0] } |
        Where-Object   {  $_ -notmatch '^\s*$' }
}

function ConvertTo-LatestConfig
{
<#
    .DESCRIPTION
        Top-level function for updating a config of ambiguous type to the latest supported version.
        The function determines whether the provided config is an app config or an iap config, then
        calls helper functions to update the config to the most recent supported schema version.

        The function returns telemetry properties for:
            - StoreBrokerMigrationType (AppConfig of IapConfig).
            - ProductId. The actual ProductId, resolved based on ProductId, AppId, IapId, and config file content.
            - StartingConfigVersion.
            - EndingConfigVersion.

    .PARAMETER ProductId
        The ProductId representing this config's product, as given by v2 of the Submission API.

    .PARAMETER AppId
        The AppId representing this app config's product, as given by v1 of the Submission API.

    .PARAMETER IapId
        The IapId representing this iap config's product, as given by v1 of the Submission API.

    .PARAMETER Config
        The config object to be migrated. Can be sent as pipeline input.

    .PARAMETER TelemetryTable
        A reference to a hashtable. If present, the function will add relevant telemetry properties
        to the table, for the caller to log.
#>
    [CmdletBinding()]
    param(
        [string] $ProductId,

        [string] $AppId,

        [string] $IapId,

        [Parameter(
            Mandatory,
            ValueFromPipeline)]
        [PSCustomObject] $Config,

        [ref] $TelemetryTable
    )

    # Resolve a ProductId based on our inputs.
    $ProductId = Resolve-ProductId -ProductId $ProductId -AppId $AppId -IapId $IapId -Config $Config

    # Identify the schema version of the config (if present).
    $schemaVersion = if ($null -eq $Config.schemaVersion) { 1 }
                     else { [int] $Config.schemaVersion }

    # Check if it's an App config or an Iap config.
    if ($null -ne $Config.appSubmission)
    {
        $currentSchemaVersion = $script:maxAppConfigSchemaVersion
        $migrationType = [StoreBrokerMigrationType]::AppConfig
    }
    elseif ($null -ne $Config.iapSubmission)
    {
        $currentSchemaVersion = $script:maxIapConfigSchemaVersion
        $migrationType = [StoreBrokerMigrationType]::IapConfig
    }
    else
    {
        $out = @()
        $out += "Could not determine if the config is an App config or an In-App Product (Iap) config."
        $out += "The config does not have an `"appSubmission`" or `"iapSubmission`" field."
        $out = $out -join [Environment]::NewLine

        Write-Log -Message $out -Level Error
        throw $out
    }

    # Validate the schema's version against the current max schema version.
    if ($schemaVersion -gt $currentSchemaVersion)
    {
        $out = "The config's schema version [{0}] is greater than the current max config schema version [{1}]."
        $out = $out -f $schemaVersion, $currentSchemaVersion

        Write-Log -Message $out -Level Error
        throw $out
    }
    elseif ($schemaVersion -lt $currentSchemaVersion)
    {
        Write-Log -Message "Updating app config from schema version [$schemaVersion] to [$currentSchemaVersion]." -Level Verbose
    }

    # Migrate the config.
    $Config |
        # Future migration handlers can be added here.
        Convert-ConfigSchemaFrom1To2 -ProductId $ProductId |
        Write-Output

    # Report telemetry for this function call.
    if ($TelemetryTable.Value -is [System.Collections.IDictionary])
    {
        @{
            [StoreBrokerTelemetryProperty]::ProductId = $ProductId
            [StoreBrokerTelemetryProperty]::MigrationType = $migrationType
            [StoreBrokerTelemetryProperty]::StartingConfigVersion = $schemaVersion
            [StoreBrokerTelemetryProperty]::EndingConfigVersion = $currentSchemaVersion
        }.GetEnumerator() | ForEach-Object {
            $TelemetryTable.Value[$_.Key] = $_.Value
        }
    }
}

filter Convert-ConfigSchemaFrom1To2
{
<#
    .DESCRIPTION
        This is the working function for converting a config from schema version 1 to 2 (App or Iap config).

        If the input config's schema version is greater than 1, this function will do no work but will
        still write its input to the pipeline for other functions.

        The function:
            - Adds the current max schema version for the config type (App or Iap).
            - Adds the ProductId to the 'appSubmission'/'iapSubmission' object.
            - Replaces 'ImagesRootPath' with 'MediaRootPath'.
            - Replaces 'AppxPath' with 'PackagePath' (App config only).

    .PARAMETER Config
        A PSCustomObject representing the config.

    .PARAMETER ProductId
        The ProductId representing this config's product, as given by v2 of the Submission API.

    .EXAMPLE
        $v1ConfigObj |
            Convert-ConfigSchemaFrom1To2 -ProductId $productId |
            ConvertTo-Json -Depth 100
            Out-File @outArgs

        Migrates the config from v1 to v2, then writes the file as specified by $outArgs.

    .EXAMPLE
        $v2ConfigObj |
            Convert-ConfigSchemaFrom1To2 -ProductId $productId |
            Convert-ConfigSchemaFrom2To3 @v2Args |
            ConvertTo-Json -Depth 100
            Out-File @outArgs

        Performs no work because the config's schema version is already greater than 1, but the function forwards
        its input to the Convert-ConfigSchema-From2-To3 function so that migration can happen there.
#>
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory,
            ValueFromPipeline)]
        [PSCustomObject] $Config,

        [Parameter(Mandatory)]
        [string] $ProductId
    )

    $schemaVersion = if ($null -eq $Config.schemaVersion) { 1 }
                     else { $Config.schemaVersion }

    if ($schemaVersion -eq 1)
    {
        Write-Log -Message "`tMigrating config from schema version [1] to [2]." -Level Verbose

        # Ensure schemaVersion property.
        $Config | Add-Member -Force -NotePropertyName 'schemaVersion' -NotePropertyValue 2
        Write-Log -Message "`t`tAdded schema version: [2]." -Level Verbose

        # Ensure helpUri property.
        $Config | Add-Member -Force -NotePropertyName 'helpUri' -NotePropertyValue $script:configHelpUri
        Write-Log -Message "`t`tAdded config template help uri: [$script:configHelpUri]." -Level Verbose

        # Standard format string for errors during processing.
        $invalidMessage = "The config is not a valid v1 config. {0}"

        # Ensure we have a valid config object with an appSubmission/iapSubmission property.
        $isAppConfig = $null -ne $Config.appSubmission
        $isIapConfig = $null -ne $Config.iapSubmission
        if (-not ($isAppConfig -or $isIapConfig))
        {
            $out =  $invalidMessage -f "It does not have an 'appSubmission' nor 'iapSubmission' property."
            Write-Log -Message $out -Level Error
            throw $out
        }

        # Add ProductId
        $submissionObj = if ($isAppConfig) { $Config.appSubmission } else { $Config.iapSubmission }
        $submissionObj | Add-Member -Force -NotePropertyName 'productId' -NotePropertyValue $ProductId

        Write-Log -Message "`t`tAdded ProductId." -Level Verbose

        # Ensure we have a valid config object with a packageParameters property
        $packageParameters = $Config.packageParameters
        if ($null -eq $packageParameters)
        {
            $out = $invalidMessage -f "It does not have a 'packageParameters' property."
            Write-Log -Message $out -Level Error
            throw $out
        }

        # Assign values for MediaRootPath and PackagePath
        $mediaRootPathValue = [string] $packageParameters.ImagesRootPath
        $packagePathValue = [string[]] @( $packageParameters.AppxPath |
            Where-Object { -not [String]::IsNullOrWhiteSpace($_) })

        # MediaRootPath from ImagesRootPath
        $packageParameters |
            Add-Member -Force -NotePropertyName 'MediaRootPath' -NotePropertyValue $mediaRootPathValue -PassThru |
            Remove-Member -Name 'ImagesRootPath'

        Write-Log -Message "`t`tReplaced 'ImagesRootPath' with 'MediaRootPath'." -Level Verbose

        if ($isAppConfig)
        {
            # PackagePath from AppxPath
            $packageParameters |
                Add-Member -Force -NotePropertyName 'PackagePath' -NotePropertyValue $packagePathValue -PassThru |
                Remove-Member -Name 'AppxPath'

            Write-Log -Message "`t`tReplaced 'AppxPath' with 'PackagePath'." -Level Verbose
        }
    }
    elseif ($schemaVersion -lt 1)
    {
        $out = "The config schema version is invalid: [$schemaVersion]."
        Write-Log -Message $out -Level Error
        throw $out
    }

    # Write our input back to the pipeline no matter what.
    $Config | Write-Output
}

function Resolve-ProductId
{
<#
    .SYNOPSIS
        Resolves a valid ProductId value based on the provided inputs.

    .DESCRIPTION
        Ideally, the ProductId is a valid value and the function simply returns it.
        If not, the function resolves an AppId or IapId. If either value is not valid, then
        the function searches for those values in the config. Once a valid value is determined,
        the ProductId can be found by reverse-lookup.

    .PARAMETER ProductId
        The ProductId to be resolved. If this is valid, then it is the function's result.

    .PARAMETER AppId
        The AppId that identifies the product. If this is valid, the ProductId is found by
        a reverse-lookup.

    .PARAMETER IapId
        The IapId that identifies the product. If this is valid, the ProductId is found by
        a reverse-lookup.

    .PARAMETER Config
        A PSCustomObject representing the config. If there is no AppId or IapId, the function
        checks for a valid value in the config.
#>
    [CmdletBinding()]
    param(
        [string] $ProductId,
        [string] $AppId,
        [string] $IapId,
        [PSCustomObject] $Config
    )

    $errorFormat = @(
        "The resolved {0} [{1}] does not represent a valid product in the Submission API.",
        "Please provided a valid {0} at the command-line and also make sure your config has correct",
        "values for AppId/IapId."
        ) | Out-String

    if ([String]::IsNullOrWhiteSpace($ProductId))
    {
        # Use AppId or IapId and do a reverse lookup of ProductId.
        # If we don't have either, check the config for the value.
        $externalId = $null
        $externalIdType = $null
        if (-not [String]::IsNullOrWhiteSpace($AppId))
        {
            $externalId = $AppId
            $externalIdType = "AppId"
            Write-Log -Message "Using AppId: [$AppId]." -Level Verbose
        }
        elseif (-not [String]::IsNullOrWhiteSpace($IapId))
        {
            $externalId = $IapId
            $externalIdType = "IapId"
            Write-Log -Message "Using IapId: [$IapId]." -Level Verbose
        }
        elseif ($null -ne $Config.appSubmission.appId)
        {
            $externalId = $Config.appSubmission.appId
            $externalIdType = "AppId"
            Write-Log -Message "Using AppId from config: [$externalId]." -Level Verbose
        }
        elseif ($null -ne $Config.iapSubmission.iapId)
        {
            $externalId = $Config.iapSubmission.iapId
            $externalIdType = "IapId"
            Write-Log -Message "Using IapId from config: [$externalId]." -Level Verbose
        }

        if ([String]::IsNullOrWhiteSpace($externalId))
        {
            $out = @()
            $out += "Could not find a ProductId, AppId, nor IapId."
            $out += "Please supply one of these values at the command-line."
            $out = $out -join [Environment]::NewLine

            Write-Log -Message $out -Level Error
            throw $out
        }

        Write-Log -Message "Validating $($externalIdType): [$externalId]" -Level Verbose
        $product = Get-Product -ExternalId $externalId
        if ($null -eq $product)
        {
            $out = $errorFormat -f $externalIdType, $externalId
            Write-Log -Message $out -Level Error
            throw $out
        }

        $ProductId = $product.id
    }
    else
    {
        Write-Log -Message "Validating ProductId: [$ProductId]" -Level Verbose
        $product = Get-Product -ProductId $ProductId
        if ($null -eq $product)
        {
            $out = $errorFormat -f "ProductId", $ProductId
            Write-Log -Message $out -Level Error
            throw $out
        }
    }

    Write-Log -Message "Resolved ProductId [$ProductId] for $($product.resourceType): [$($product.name)]" -Level Verbose
    return $ProductId
}

filter Remove-Member
{
<#
    .SYNOPSIS
        A utility function for removing a property from a PSCustomObject.

    .PARAMETER InputObject
        The object to be acted upon. Can be passed by pipeline.

    .PARAMETER Name
        The name of the property to remove.
#>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "", Justification="This function does not change system state.")]
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory,
            ValueFromPipeline)]
        [PSCustomObject] $InputObject,

        [Parameter(Mandatory)]
        [string] $Name
    )

    # This method is safe even if
    # the property does not exist.
    $InputObject.PSObject.Properties.Remove($Name)
}

function Get-OrderedConfigTemplate
{
<#
    .DESCRIPTION
        A helper function to enabling writing a JSON object with a guaranteed property order.
        The config templates contain an [ordered] dictionary representing the config. This
        function simply dot-sources the appropriate template and returns that dictionary.

    .PARAMETER Type
        The type of config to be converted.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('App','Iap')]
        [string] $Type
    )

    $configFile = if ($Type -eq 'App') { $script:defaultConfigFileName }
                  else { $script:defaultIapConfigFileName }
    $configPath = Join-Path -Path $PSScriptRoot -ChildPath $configFile

    return . $configPath
}

filter ConvertTo-OrderedJson
{
<#
    .DESCRIPTION
        Top-level function for converting a PSCustomObject to ordered JSON text.

        Given the input object and an ordered dictionary whose keys are the order of the
        object's properties as they should be written, the function will use a helper
        to convert the object to an ordered dictionary whose keys follow the template's
        order and whose values are the property values from the object. The result is
        written to JSON and the ordering is preserved.

    .PARAMETER InputObject
        The object to be converted to JSON. Can be sent as pipeline input.

    .PARAMETER Template
        An ordered dictionary whose keys are properties on the InputObject.
        The ordering of keys in this dictionary determines the ordering of
        the object's properties when it is converted to JSON. The values
        are only used if the matching property is an object, in which case
        the value should be an ordered dictionary containing the ordering
        information for that sub-object.
#>
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory,
            ValueFromPipeline)]
        [PSCustomObject] $InputObject,

        [Parameter(Mandatory)]
        [System.Collections.Specialized.OrderedDictionary] $Template,

        [ValidateRange(0, 100)]
        [int] $Depth = 100
    )

    $InputObject |
        Sort-ObjectProperties -Template $Template |
        ConvertTo-Json -Depth $Depth |
        Write-Output
}

filter Sort-ObjectProperties
{
<#
    .DESCRIPTION
        Utility function for sorting the properties of a PSCustomObject according to the provided
        template. The function is recursive, so any property that is an object or an array of
        objects will also be converted according to the matching template for that property.
        If the object has properties that are not specified by the template, those properties
        will be written in the order they were retrieved, meaning their order is not guaranteed
        between multiple uses of this function.

    .PARAMETER InputObject
        The object to be manipulated. Can be sent as pipeline input.

    .PARAMETER Template
        An ordered dictionary whose keys are properties on the InputObject.
        The ordering of keys in this dictionary determines the ordering of
        the object's properties when it is converted to JSON. The values
        are only used if the matching property is an object, in which case
        the value should be an ordered dictionary containing the ordering
        information for that sub-object.

    .EXAMPLE
        PS C:\> $in = [PSCustomObject] @{ a= 1; b = @{ c = 2; d = 3 } }
        PS C:\> $template = [ordered]@{ b = [ordered]@{ d = 1; c = 2 }; a = 3 }
        PS C:\> Sort-ObjectProperties -InputObject $in -Template $template | ConvertTo-Json
        {
            "b":  {
                    "d":  3,
                    "c":  2
                },
            "a":  1
        }

        The output matches the ordering of the template. The example also shows that subobjects
        in the input object can also have guaranteed order, and that the value of the properties
        in the output JSON match the input object even though they do not match the template.
#>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseApprovedVerbs", "", Justification="Sort appears in the Sort-Object cmdlet and is the most appropriate verb to describe this internal function.")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "", Justification="An object with one property does not need its properties, so this function only makes sense for multiple properties.")]
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory,
            ValueFromPipeline)]
        [AllowNull()]
        [PSCustomObject] $InputObject,

        [Parameter(Mandatory)]
        [AllowNull()]
        [System.Collections.Specialized.OrderedDictionary] $Template
    )

    # We want to iterate over the input object's properties in the correct order.
    # This helper function will return the list of properties, so that any properties
    # with entries in the template will exist in the list in the same relative order.
    $orderedProperties = @(Get-OrderedPropertyList `
                            -Properties @($InputObject.PSObject.Properties.Name) `
                            -Ordering @($Template.Keys))

    # The resulting PSCustomObject will be backed by an ordered dictionary.
    # The keys for the dictionary act like a queue, so the order they are
    # added determines the ordering of properties when the result object
    # is written to JSON.
    $orderedObj = [ordered] @{}
    foreach ($property in $orderedProperties)
    {
        $val = $InputObject.$property
        if ($property -in $Template.Keys)
        {
            # The property has an order.
            # There are two cases we need to consider for conversion.
            if ($val -is [PSCustomObject])
            {
                # We will also order the subobject according to the template
                # defined for that property.
                $val = $val | Sort-ObjectProperties -Template $Template.$property
            }
            elseif ($val -is [array])
            {
                # The value is a collection, so we need to convert its
                # elements if they are PSCustomObject types.
                $elementTemplate = $null
                $isPSCustomObjArray = $false
                $collection = @()
                for ($i = 0; $i -lt $val.Count; $i++)
                {
                    if ($i -eq 0)
                    {
                        # If the elements are PSCustomObject type,
                        # we should have a template for them, but there
                        # is likely only one element in the template's collection,
                        # so we need to make sure we re-use it for every element
                        # being converted.
                        # NOTE: This method fails for heterogenous-type arrays.
                        $elementTemplate = $Template.$property[0]
                        $isPSCustomObjArray = $val[0] -is [PSCustomObject]
                    }

                    $collection += if ($isPSCustomObjArray) { $val[$i] | Sort-ObjectProperties -Template $elementTemplate }
                                   else { $val[$i] }
                }

                $val = $collection
            }
        }

        $orderedObj[$property] = $val
    }

    return [PSCustomObject] $orderedObj
}

function Get-OrderedPropertyList
{
<#
    .DESCRIPTION
        Utility function for sorting a subset of the elements in a list of property names.

        Given the list of property names and an ordering that is a subset of that list,
        the function will change the position of items in the ordering list, to match
        the order of items in that list.

    .PARAMETER Properties
        The list of property names to be partially sorted.

    .PARAMETER Ordering
        A subset of the Properties list. The order of items in this list will be the
        relative ordering of items in the Properties list.

    .EXAMPLE
        PS C:\> $properties = [string[]] "abcdefg".ToCharArray()
        PS C:\> $ordering = [string[]] "efca".ToCharArray()
        PS C:\> (Get-OrderedPropertyList -Properties $properties -Ordering $ordering) -join ", "
        e, b, f, d, c, a, g
#>
    [CmdletBinding()]
    param(
        [string[]] $Properties = @(),
        [string[]] $Ordering = @()
    )

    # Filter the inputs to make sure the items are valid.
    # Note that Ordering is a subset of Properties, therefore all items are implicitly
    # not $null/whitespace as well.
    $Properties = @($Properties | Where-Object { -not [String]::IsNullOrWhiteSpace($_) })
    $Ordering = @($Ordering | Where-Object { $_ -in $Properties })

    # Move through the Properties list by index, keeping track of the index
    # of the next orderd property in Ordering. pIndex will be the index
    # in the Properties list and oIndex in the Ordering list.
    for ($pIndex = $oIndex = 0; $pIndex -lt $Properties.Count; $pIndex++)
    {
        $property = $Properties[$pIndex]

        # Check that we're not the last element (which would naturally be ordered).
        # If the property isn't in the Ordering list, it keeps its position.
        if (($pIndex -lt $Properties.Count - 1) -and ($oIndex -lt $Ordering.Count) -and ($property -in $Ordering))
        {
            # Get the next property that should appear in the final ordering.
            $nextOrdered = $Ordering[$oIndex]

            # If the Properties element matches the next ordered propertry,
            # we can simply leave it in its current position.
            if ($property -ne $nextOrdered)
            {
                # If the elements don't match, we know that the Properties element
                # is in the Ordering, it's simply not in the correct position.
                # The target next ordered property name must exist in the Properties
                # list, so we'll find its index and swap its position with the current
                # Properties element.
                $swapIndex = [Array]::IndexOf($Properties, $nextOrdered, $pIndex + 1)
                ,$Properties | Swap-Objects $pIndex $swapIndex

                $property = $nextOrdered
            }

            # Move to the next ordered property element.
            $oIndex++
        }

        $property | Write-Output
    }
}

function Swap-Objects
{
<#
    .SYNOPSIS
        Utility function for swapping the position of two elements in an array.
#>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseApprovedVerbs", "", Justification="There is no approved verb that matches the functions intended behavior and this function is internal only.")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "", Justification="This function only makes sense for swapping two objects, so plurality is correct.")]
    param(
        [Parameter(Mandatory)]
        [int] $A,

        [Parameter(Mandatory)]
        [int] $B,

        [Parameter(
            Mandatory,
            ValueFromPipeline)]
        $InputObject
    )

    $temp = $InputObject[$A]
    $InputObject[$A] = $InputObject[$B]
    $InputObject[$B] = $temp
}
