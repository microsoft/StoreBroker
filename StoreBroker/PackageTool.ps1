# Copyright (C) Microsoft Corporation.  All rights reserved.


# Default file name of the AppConfig in the module folder
$script:defaultConfigFileName = "AppConfigTemplate.json"
$script:defaultIapConfigFileName = "IapConfigTemplate.json"

# Images will be placed in the .zip folder under the $packageImageFolderName subfolder
$script:packageImageFolderName = "Assets"

# New-SubmissionPackage supports these extensions.
$script:supportedExtensions = ".appx", ".appxbundle", ".appxupload"

# String constants for New-SubmissionPackage parameters
$script:s_ConfigPath = "ConfigPath"
$script:s_PDPRootPath = "PDPRootPath"
$script:s_Release = "Release"
$script:s_PDPInclude = "PDPInclude"
$script:s_PDPExclude = "PDPExclude"
$script:s_LanguageExclude = "LanguageExclude"
$script:s_ImagesRootPath = "ImagesRootPath"
$script:s_AppxPath = "AppxPath"
$script:s_OutPath = "OutPath"
$script:s_OutName = "OutName"
$script:s_DisableAutoPackageNameFormatting = "DisableAutoPackageNameFormatting"

function Get-StoreBrokerConfigFileContentForIapId
{
<#
    .SYNOPSIS
        Updates the default IAP configuration file template with the values from the
        indicated IAP's most recent submission.

    .DESCRIPTION
        Updates the default IAP configuration file template with the values from the
        indicated IAP's most recent submission.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

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
            Write-Log "No published submission exists for this In-App Product.  Using the current pending submission." -Level Warning
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

        # Need to replace actual CR's and LF's with their control codes.  We'll ensure all variations are uniformly formatted as \r\n
        $tag = $sub.tag -replace '\r\n', '\r\n' -replace '\r', '\r\n' -replace '\n', '\r\n'
        $updated = $updated -replace '"tag": ""', "`"tag`": `"$tag`""

        $keywords = $sub.keywords | ConvertTo-Json -Depth $script:jsonConversionDepth
        if ($null -eq $keywords) { $keywords = "[ ]" }
        $updated = $updated -replace '(\s+)"keywords": \[.*(\r|\n)+\s*\]', "`$1`"keywords`": $keywords"

        # NOTES FOR CERTIFICATION
        # Need to replace actual CR's and LF's with their control codes.  We'll ensure all variations are uniformly formatted as \r\n
        $notesForCertification = $sub.notesForCertification -replace '\r\n', '\r\n' -replace '\r', '\r\n' -replace '\n', '\r\n'
        $updated = $updated -replace '"notesForCertification": ""', "`"notesForCertification`": `"$notesForCertification`""

        return $updated
    }
    catch
    {
        Write-Log "Encountered problems getting current In-App Product submission values: $($_.Exception.Message)" -Level Error
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

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

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
    if (-not (Test-Path -PathType Container -Path $dir))
    {
        Write-Log "Creating directory: $dir" -Level Verbose
        New-Item -Force -ItemType Directory -Path $dir | Out-Null
    }

    $sourcePath = Join-Path -Path $PSScriptRoot -ChildPath $script:defaultIapConfigFileName

    # Get-Content returns an array of lines.... using Out-String gives us back the linefeeds.
    $template = (Get-Content -Path $sourcePath -Encoding UTF8) | Out-String

    if (-not ([String]::IsNullOrEmpty($IapId)))
    {
        $template = Get-StoreBrokerConfigFileContentForIapId -ConfigContent $template -IapId $IapId
    }

    Write-Log "Copying (Item: $sourcePath) to (Target: $Path)." -Level Verbose
    Set-Content -Path $Path -Value $template -Encoding UTF8 -Force

    $telemetryProperties = @{ [StoreBrokerTelemetryProperty]::IapId = $IapId }
    Set-TelemetryEvent -EventName New-StoreBrokerIapConfigFile -Properties $telemetryProperties
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

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

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

        $updated = $updated -replace '"appId": ".*",', "`"appId`": `"$AppId`","

        # PUBLISH MODE AND VISIBILITY
        $updated = $updated -replace '"targetPublishMode": ".*",', "`"targetPublishMode`": `"$($sub.targetPublishMode)`","
        $updated = $updated -replace '"targetPublishDate": .*,', "`"targetPublishDate`": `"$($sub.targetPublishDate)`","
        $updated = $updated -replace '"visibility": ".*",', "`"visibility`": `"$($sub.visibility)`","

        # PRICING AND AVAILABILITY
        $updated = $updated -replace '"priceId": ".*",', "`"priceId`": `"$($sub.pricing.priceId)`","
        $updated = $updated -replace '"trialPeriod": ".*",', "`"trialPeriod`": `"$($sub.pricing.trialPeriod)`","

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
                $updated = $updated -replace "`"$family`": [^,\r\n]*(,)?", "`"$family`": $($families.$family.ToString().ToLower())`$1"
            }
            else
            {
                $updated = $updated -replace "`"$family`": [^,\r\n]*(,)?", "// `"$family`": false`$1"
            }
        }

        $updated = $updated -replace '"allowMicrosoftDecideAppAvailabilityToFutureDeviceFamilies": .*,', "`"allowMicrosoftDecideAppAvailabilityToFutureDeviceFamilies`": $($sub.allowMicrosoftDecideAppAvailabilityToFutureDeviceFamilies.ToString().ToLower()),"
        $updated = $updated -replace '"enterpriseLicensing": ".*",', "`"enterpriseLicensing`": `"$($sub.enterpriseLicensing)`","

        # APP PROPERTIES
        $updated = $updated -replace '"applicationCategory": ".*",', "`"applicationCategory`": `"$($sub.applicationCategory)`","

        $hardwarePreferences = $sub.hardwarePreferences | ConvertTo-Json -Depth $script:jsonConversionDepth
        if ($null -eq $hardwarePreferences) { $hardwarePreferences = "[ ]" }
        $updated = $updated -replace '(\s+)"hardwarePreferences": \[.*(\r|\n)+\s*\]', "`$1`"hardwarePreferences`": $hardwarePreferences"

        $updated = $updated -replace '"hasExternalInAppProducts": .*,', "`"hasExternalInAppProducts`": $($sub.hasExternalInAppProducts.ToString().ToLower()),"
        $updated = $updated -replace '"meetAccessibilityGuidelines": .*,', "`"meetAccessibilityGuidelines`": $($sub.meetAccessibilityGuidelines.ToString().ToLower()),"
        $updated = $updated -replace '"canInstallOnRemovableMedia": .*,', "`"canInstallOnRemovableMedia`": $($sub.canInstallOnRemovableMedia.ToString().ToLower()),"
        $updated = $updated -replace '"automaticBackupEnabled": .*,', "`"automaticBackupEnabled`": $($sub.automaticBackupEnabled.ToString().ToLower()),"
        $updated = $updated -replace '"isGameDvrEnabled": .*,', "`"isGameDvrEnabled`": $($sub.isGameDvrEnabled.ToString().ToLower()),"

        # NOTES FOR CERTIFICATION
        # Need to replace actual CR's and LF's with their control codes.  We'll ensure all variations are uniformly formatted as \r\n
        $notesForCertification = $sub.notesForCertification -replace '\r\n', '\r\n' -replace '\r', '\r\n' -replace '\n', '\r\n'
        $updated = $updated -replace '"notesForCertification": ""', "`"notesForCertification`": `"$notesForCertification`""

        return $updated
    }
    catch
    {
        Write-Log "Encountered problems getting current application submission values: $($_.Exception.Message)" -Level Error
        throw
    }
}

function New-StoreBrokerConfigFile
{
<#
    .SYNOPSIS
        Creates a new configuration file as a template for an app submission.

    .DESCRIPTION
        Creates a new configuration file as a template for an app submission.
        The full path to the new file can be provided by the -Path parameter.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

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
    if (-not (Test-Path -PathType Container -Path $dir))
    {
        Write-Log "Creating directory: $dir" -Level Verbose
        New-Item -Force -ItemType Directory -Path $dir | Out-Null
    }

    $sourcePath = Join-Path -Path $PSScriptRoot -ChildPath $script:defaultConfigFileName

    # Get-Content returns an array of lines.... using Out-String gives us back the linefeeds.
    $template = (Get-Content -Path $sourcePath -Encoding UTF8) | Out-String

    if (-not ([String]::IsNullOrEmpty($AppId)))
    {
        $template = Get-StoreBrokerConfigFileContentForAppId -ConfigContent $template -AppId $AppId
    }

    Write-Log "Copying (Item: $sourcePath) to (Target: $Path)." -Level Verbose
    Set-Content -Path $Path -Value $template -Encoding UTF8 -Force

    $telemetryProperties = @{ [StoreBrokerTelemetryProperty]::AppId = $AppId }
    Set-TelemetryEvent -EventName New-StoreBrokerConfigFile -Properties $telemetryProperties
}

function Write-SubmissionRequestBody
{
<#
    .SYNOPSIS
        Converts an object into JSON and writes to the specified file.

    .PARAMETER JsonObject
        A PSCustomObj to be converted into JSON.

    .PARAMETER OutFilePath
        Full path to the file to be written to.
#>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject] $JsonObject,

        [Parameter(Mandatory)]
        [string] $OutFilePath
    )

    if ($PSCmdlet.ShouldProcess($OutFilePath, "Output to File"))
    {
        $JsonObject | ConvertTo-Json -Depth $script:jsonConversionDepth -Compress | Out-File -Encoding utf8 -FilePath $OutFilePath
    }
}

function Get-XsdPath
{
<#
    .SYNOPSIS
        Resolves a namespace schema URI to a local XSD file.

    .PARAMETER NamespaceUri
        The XML namespace URI.

    .OUTPUTS
        System.String - Full path to the XSD file.
        Exception if not found.
#>
    param(
        [Parameter(Mandatory)]
        [string] $NamespaceUri
    )

    $namespaces = @{
        'http://schemas.microsoft.com/appx/2012/ProductDescription'      = (Join-Path -Path $PSScriptRoot -ChildPath '..\PDP\ProductDescription.xsd')
        'http://schemas.microsoft.com/appx/2012/InAppProductDescription' = (Join-Path -Path $PSScriptRoot -ChildPath '..\PDP\InAppProductDescription.xsd')
    }

    $xsdPath = $namespaces[$NamespaceUri]

    if ([String]::IsNullOrEmpty($xsdPath))
    {
        throw "Namespace not found ($NamespaceUri)"
    }

    return $xsdPath
}

function Test-Xml
{
<#
    .SYNOPSIS
        Validates a specified XML file against the input schema.
        If any validation errors are detected, the program will print a list
        of all errors and halt execution.

    .PARAMETER XsdFile
        Full path to the XML Schema Definition file to use.

    .PARAMETER XmlFile
        Full path to the XML file to be validated.
#>
    param(
        [Parameter(Mandatory)]
        [string] $XsdFile,

        [Parameter(Mandatory)]
        [string] $XmlFile
    )

    # Relative paths such as '.\File.txt' can resolve as 'C:\windows\System32\File.txt' when
    # interacting with .NET libraries.  Run [string] path parameters through 'Convert-Path' to
    # get a full-path before using the path with any .NET libraries.
    $XsdFile = Convert-Path -Path $XsdFile
    $XmlFile = Convert-Path -Path $XmlFile

    # The ValidationEventHandler runs in its own scope and does not have access to variables from
    # Test-Xml.  Make $validationErrors a script variable so capture exceptions in the
    # ValidationEventHandler and report them in Test-Xml.
    $script:validationErrors = @()

    $handler = [scriptblock] {
        $script:validationErrors += $args[1].Message
    }

    $reader = New-Object System.Xml.XmlTextReader $XsdFile
    
    try
    {
        $schema = [System.Xml.Schema.XmlSchema]::Read($reader, $handler)

        $xml = New-Object System.Xml.XmlDocument
        $xml.Schemas.Add($schema) | Out-Null
        $xml.Load($XmlFile)
        $xml.Validate($handler)
    }
    finally
    {
        $reader.Close()
    }

    if ($script:validationErrors -gt 0)
    {
        $msg = @()
        $msg += "Provided XML file:`n`t$($XmlFile)`nis not valid under its referenced schema:`n`t$($XsdFile)"
        $script:validationErrors | ForEach-Object { $msg += $_ }
        $msg = $msg -join [Environment]::NewLine

        Write-Log $msg -Level Error
        throw "Halt Execution"
    }
}

function Convert-ListingToObject
{
<#
    .SYNOPSIS
        Consumes a single localized .xml file into a listing object.
        
    .DESCRIPTION
        Consumes a single localized .xml file into a listing object.
        If a node has only content, then that content is assigned.
        If a node has children, it's children are pooled into an array and assigned.
        The ScreenshotCaptions node is special.  For each caption, the function
        checks if there is an associated Desktop/Mobile/Xbox image, and adds new
        information for each type found.

    .PARAMETER PDPRootPath
        The root path of all the PDPs.  'XmlFilePath' should begin with 'PDPRootPath',
        so this function splits 'XmlFilePath' using 'PDPRootPath'.  The result
        should begin with the lang-code of the file being processed.

    .PARAMETER LanguageExclude
        Array of lang-code strings that SHOULD NOT be processed.

    .PARAMETER ImagesRootPath
        A path to the root path containing the new submission's images.  A screenshot
        caption has the potential for relative paths to Desktop, Mobile, and Xbox images.
        Each relative path is appended to ImagesRootPath to create a full path to the image.

    .PARAMETER XmlFilePath
        A full path to the localized .xml file to be parsed.
        
#>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string] $PDPRootPath,

        [Parameter(Mandatory)]
        [AllowNull()]
        [AllowEmptyString()]
        [string[]] $LanguageExclude,

        [Parameter(Mandatory)]
        [string] $ImagesRootPath,

        [Parameter(
            Mandatory,
            ValueFromPipeline)]
        [string[]] $XmlFilePaths
    )

    PROCESS
    {
        foreach ($xmlFilePath in $XmlFilePaths)
        {
            if ($PSCmdlet.ShouldProcess($xmlFilePath, "Convert-ListingToObject"))
            {
                try
                {
                    # Identify lang-code of the file to process.
                    # $array[-1] == $array[$array.Count-1]
                    if ($PDPRootPath[-1] -ne '\') { $PDPRootPath = "$PDPRootPath\" }

                    $split = $xmlFilePath -split $PDPRootPath, 0, "SimpleMatch" |
                             Where-Object { -not [String]::IsNullOrWhiteSpace($_) } |
                             Select-Object -First 1
                    $language = $split -split "\", 0, "SimpleMatch" |
                                Where-Object { -not [String]::IsNullOrWhiteSpace($_) } |
                                Select-Object -First 1

                    # Skip processing if language is marked for exclusion
                    if ($language -in $LanguageExclude)
                    {
                        $out = "Skipping file '$xmlFilePath' because its lang-code '$language' is in the language exclusion list."
                        Write-Log $out -Level Verbose

                        return
                    }

                    $xml = [xml] (Get-Content -Path $xmlFilePath -Encoding UTF8)

                    # ProductDescription node contains the metadata
                    $ProductDescriptionNode = $xml.ProductDescription

                    # Verify xml conforms to schema
                    Test-Xml -XsdFile (Get-XsdPath -NamespaceUri $ProductDescriptionNode.xmlns) -XmlFile $xmlFilePath

                    # Assemble the BaseListing object
                    # Nodes with one item can be immediately assigned
                    $baseListing = @{
                        "copyrightAndTrademarkInfo" = $ProductDescriptionNode.CopyrightAndTrademark;
                        "licenseTerms"              = $ProductDescriptionNode.AdditionalLicenseTerms;
                        "privacyPolicy"             = $ProductDescriptionNode.PrivacyPolicyURL;
                        "supportContact"            = $ProductDescriptionNode.SupportContactInfo;
                        "websiteUrl"                = $ProductDescriptionNode.WebsiteURL;
                        "title"                     = $ProductDescriptionNode.AppStoreName;
                        "description"               = $ProductDescriptionNode.Description;
                        "releaseNotes"              = $ProductDescriptionNode.ReleaseNotes;
                    }

                    # Identify the keys whose values are non-null and trim the values.
                    # Must be done in two steps because $baseListings can't be modified
                    # while enumerating its keys.
                    $trimKeys = $baseListing.Keys |
                        Where-Object { ($null -ne $baseListing[$_].InnerText) -or ($baseListing[$_] -is [String]) } 

                    $trimKeys | ForEach-Object { 
                        if ($null -ne $baseListing[$_].InnerText)
                        {
                            $baseListing[$_] = $baseListing[$_].InnerText
                        }
                        
                        $baseListing[$_] = $baseListing[$_].Trim()
                    }

                    # For title specifically, we need to ensure that it's set to $null if there's
                    # no value.  An empty string value is not the same as $null.
                    if ([String]::IsNullOrWhiteSpace($baseListing['title']))
                    {
                        $baseListing['title'] = $null
                    }
        
                    # Nodes with children need to have each value extracted into an array.
                    # When using -Confirm, PS will ask user to confirm selecting 'InnerText'.
                    # Explicitly set -Confirm:$false to prevent this dialog from reaching the user.
                    @{
                        "features"            = $ProductDescriptionNode.AppFeatures;
                        "keywords"            = $ProductDescriptionNode.Keywords;
                        "recommendedHardware" = $ProductDescriptionNode.RecommendedHardware;
                    }.GetEnumerator() | ForEach-Object {
                        $baseListing[$_.Name] = @($_.Value.ChildNodes | 
                                                    Where-Object NodeType -eq Element |
                                                    ForEach-Object -WhatIf:$false -Confirm:$false InnerText |
                                                    Where-Object { $_ -ne $null } |
                                                    ForEach-Object { $_.Trim() })
                    }           

                    # ScreenshotCaption node is special, needs to be consumed separately
                    $packageImagePath = Join-Path $script:tempFolderPath (Join-Path $script:packageImageFolderName $language)
                    if (-not (Test-Path -PathType Container -Path $packageImagePath))
                    {
                        New-Item -ItemType directory -Path $packageImagePath | Out-Null
                    }

                    $imageListings = @()
                    $captions = $ProductDescriptionNode.ScreenshotCaptions.ChildNodes |
                        Where-Object NodeType -eq Element

                    foreach ($caption in $captions)
                    {
                        $imageTypeMap = @{
                            "DesktopImage" = "Screenshot";
                            "MobileImage"  = "MobileScreenshot";
                            "XboxImage"    = "XboxScreenshot";
                            "HoloLensImage" = "HoloLensScreenshot";
                            "SurfaceHubImage" = "SurfaceHubScreenshot";
                        }

                        foreach ($member in $imageTypeMap.Keys)
                        {
                            $imageFileName = $caption.$member
                            if (-not [System.String]::IsNullOrWhiteSpace($imageFileName))
                            { 
                                #imageContainerPath = <imagesRootPath>/<release>/<lang-code>/
                                $imageContainerPath = [System.IO.Path]::Combine($ImagesRootPath, $ProductDescriptionNode.Release, $language)
                                if (Test-Path -Path $imageContainerPath -PathType Container)
                                {
                                    $image = Get-ChildItem -Recurse -File -Path $imageContainerPath -Include $imageFileName | Select-Object -First 1

                                    if ($null -eq $image)
                                    {
                                        Write-Log "Could not find image '$($imageFileName)' in any subdirectory of '$imageContainerPath'." -Level Error
                                        throw "Halt Execution"
                                    }
                        
                                    $destinationInPackage = Join-Path $packageImagePath $image.Name
                                    if (-not (Test-Path -PathType Leaf $destinationInPackage))
                                    {
                                        Copy-Item -Path $image.FullName -Destination $destinationInPackage
                                    }

                                    $imageType = $imageTypeMap[$member]
                        
                                    $imageListings += @{
                                        "fileName"     = [System.IO.Path]::Combine($script:packageImageFolderName, $language, $image.Name)
                                        "fileStatus"   = "PendingUpload";
                                        "description"  = $caption.InnerText.Trim();
                                        "imageType"    = $imageType;
                                    }
                                }
                                else
                                {
                                    Write-Log "Provided image directory was not found: $imageContainerPath" -Level Error
                                    throw "Halt Execution"
                                }
                            }
                        }
                    }

                    $baseListing["images"] = $imageListings
                    # BaseListing done

                    # Platform Overrides
                    $platformOverrides = @{}

                    # Package and return the results
                    $listing = @{
                        "baseListing"       = $baseListing;
                        "platformOverrides" = $platformOverrides;
                    }

                    Write-Output @{ "lang" = $language.ToLowerInvariant(); "listing" = $listing }
                }
                catch [System.InvalidCastException]
                {
                    Write-Log "Provided .xml file is not a valid .xml document: $xmlFilePath" -Level Error
                    throw "Halt Execution"
                }
            }
        }
    }
}

function Convert-ListingsMetadata
{
<#
    .SYNOPSIS
        Top-level function for consuming localized metadata about the application submission.
        Each language's .xml file, in a subfolder under XmlListingsRootPath, is parsed and
        added to the listings object with the language as the key.

    .PARAMETER PDPRootPath
        The root path to the directory containing language-specific subfolders holding the
        localized metadata.

    .PARAMETER PDPInclude
        The name of the XML file to be parsed (same for every language). Wildcards are allowed.
        It is okay to specify both 'PDPInclude' and 'PDPExclude'.

    .PARAMETER PDPExclude
        XML filenames to be excluded from parsing. Wildcards are allowed. It is okay to specify
        both 'PDPInclude' and 'PDPExclude'.

    .PARAMETER LanguageExclude
        Array of lang-code strings that SHOULD NOT be processed.

    .PARAMETER ImagesRootPath
        The root path to the directory where this submission's images are located.

    .OUTPUTS
        Hashtable  A hastable with each key being a language and the corresponding value, an object
                   containing localized data for the app (Description, Notes, Screenshot captions, etc.)

    .EXAMPLE
        Convert-ListingsMetadata -PDPRootPath 'C:\PDP\' -PDPInclude 'ProductDescription.xml' -ImagesRootPath 'C:\AppImages'

        Assumes the folder structure:
        C:\PDP\language1\...\ProductDescription.xml
        C:\PDP\language2\...\ProductDescription.xml
#>
    [CmdletBinding()]
    [OutputType([Hashtable])]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({
            if (Test-Path -PathType Container -Path $_) { $true } 
            else { throw "'$_' is not a directory or cannot be found." } })]
        [string] $PDPRootPath,

        [Parameter(Mandatory)]
        [AllowNull()]
        [AllowEmptyString()]
        [string[]] $PDPInclude,

        [Parameter(Mandatory)]
        [AllowNull()]
        [AllowEmptyString()]
        [string[]] $PDPExclude,

        [Parameter(Mandatory)]
        [AllowNull()]
        [AllowEmptyString()]
        [string[]] $LanguageExclude,

        [Parameter(Mandatory)]
        [ValidateScript({ 
            if (Test-Path -PathType Container -Path $_) { $true }
            else { throw "'$_' is not a directory or cannot be found." } })]
        [string] $ImagesRootPath
    )

    $listings = @{}

    (Get-ChildItem -File $PDPRootPath -Recurse -Include $PDPInclude -Exclude $PDPExclude).FullName |
        Convert-ListingToObject -PDPRootPath $PDPRootPath -LanguageExclude $LanguageExclude -ImagesRootPath $ImagesRootPath |
        ForEach-Object { $listings[$_."lang"] = $_."listing" }

    return $listings
}

function Convert-InAppProductListingToObject
{
<#
    .SYNOPSIS
        Consumes a single localized .xml file into an In-App Product listing object.
        
    .DESCRIPTION
        Consumes a single localized .xml file into an In-App Product listing object.
        If a node has only content, then that content is assigned.
        If a node has children, it's children are pooled into an array and assigned.

    .PARAMETER PDPRootPath
        The root path of all the PDPs.  'XmlFilePath' should begin with 'PDPRootPath',
        so this function splits 'XmlFilePath' using 'PDPRootPath'.  The result
        should begin with the lang-code of the file being processed.

    .PARAMETER LanguageExclude
        Array of lang-code strings that SHOULD NOT be processed.

    .PARAMETER ImagesRootPath
        A path to the root path containing the new submission's images.  Currently, an IAP can have
        an optional icon associated with it. Each relative path is appended to ImagesRootPath to
        create a full path to the image.

    .PARAMETER XmlFilePath
        A full path to the localized .xml file to be parsed.
#>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string] $PDPRootPath,

        [Parameter(Mandatory)]
        [AllowNull()]
        [AllowEmptyString()]
        [string[]] $LanguageExclude,

        [Parameter(Mandatory)]
        [string] $ImagesRootPath,

        [Parameter(
            Mandatory,
            ValueFromPipeline)]
        [string[]] $XmlFilePaths
    )

    PROCESS
    {
        foreach ($xmlFilePath in $XmlFilePaths)
        {
            if ($PSCmdlet.ShouldProcess($xmlFilePath, "Convert-InAppProductListingToObject"))
            {
                try
                {
                    # Identify lang-code of the file to process.
                    # $array[-1] == $array[$array.Count-1]
                    if ($PDPRootPath[-1] -ne '\') { $PDPRootPath = "$PDPRootPath\" }

                    $split = $xmlFilePath -split $PDPRootPath, 0, "SimpleMatch" |
                             Where-Object { -not [String]::IsNullOrWhiteSpace($_) } |
                             Select-Object -First 1
                    $language = $split -split "\", 0, "SimpleMatch" |
                                Where-Object { -not [String]::IsNullOrWhiteSpace($_) } |
                                Select-Object -First 1

                    # Skip processing if language is marked for exclusion
                    if ($language -in $LanguageExclude)
                    {
                        $out = "Skipping file '$xmlFilePath' because its lang-code '$language' is in the language exclusion list."
                        Write-Log $out -Level Verbose

                        return
                    }

                    $xml = [xml] (Get-Content -Path $xmlFilePath -Encoding UTF8)

                    # InAppProductDescription node contains the metadata
                    $InAppProductDescriptionNode = $xml.InAppProductDescription

                    # Verify xml conforms to schema
                    Test-Xml -XsdFile (Get-XsdPath -NamespaceUri $InAppProductDescriptionNode.xmlns) -XmlFile $xmlFilePath

                    # Assemble the Listing object
                    # Nodes with one item can be immediately assigned
                    $listing = @{
                        "title"                     = $InAppProductDescriptionNode.Title;
                        "description"               = $InAppProductDescriptionNode.Description;
                    }

                    # Identify the keys whose values are non-null and trim the values.
                    # Must be done in two steps because $listings can't be modified
                    # while enumerating its keys.
                    $trimKeys = $listing.Keys |
                        Where-Object { ($null -ne $listing[$_].InnerText) -or ($listing[$_] -is [String]) } 

                    $trimKeys | ForEach-Object { 
                        if ($null -ne $listing[$_].InnerText)
                        {
                            $listing[$_] = $listing[$_].InnerText
                        }
                        
                        $listing[$_] = $listing[$_].Trim()
                    }

                    # For title specifically, we need to ensure that it's set to $null if there's
                    # no value.  An empty string value is not the same as $null.
                    if ([String]::IsNullOrWhiteSpace($listing['title']))
                    {
                        $listing['title'] = $null
                    }
        
                    # Icon node is special, needs to be consumed separately
                    $packageImagePath = Join-Path -Path $script:tempFolderPath -ChildPath (Join-Path -Path $script:packageImageFolderName -ChildPath $language)
                    if (-not (Test-Path -PathType Container -Path $packageImagePath))
                    {
                        New-Item -ItemType directory -Path $packageImagePath | Out-Null
                    }

                    $imageFileName = $InAppProductDescriptionNode.icon.fileName
                    if (-not [System.String]::IsNullOrWhiteSpace($imageFileName))
                    { 
                        #imageContainerPath = <imagesRootPath>/<release>/<lang-code>/
                        $imageContainerPath = [System.IO.Path]::Combine($ImagesRootPath, $InAppProductDescriptionNode.Release, $language)

                        if (Test-Path -Path $imageContainerPath -PathType Container)
                        {
                            $image = Get-ChildItem -Recurse -File -Path $imageContainerPath -Include $imageFileName | Select-Object -First 1
                            if ($null -eq $image)
                            {
                                Write-Log "Could not find image '$($imageFileName)' in any subdirectory of '$imageContainerPath'." -Level Error
                                throw "Halt Execution"
                            }
                        
                            $destinationInPackage = Join-Path -Path $packageImagePath -ChildPath $image.Name
                            if (-not (Test-Path -PathType Leaf $destinationInPackage))
                            {
                                Copy-Item -Path $image.FullName -Destination $destinationInPackage
                            }

                            $iconListing += @{
                                "fileName"     = [System.IO.Path]::Combine($script:packageImageFolderName, $language, $image.Name)
                                "fileStatus"   = "PendingUpload";
                            }

                            $listing['icon'] = $iconListing
                        }
                        else
                        {
                            Write-Log "Provided image directory was not found: $imageContainerPath" -Level Error
                            throw "Halt Execution"
                        }
                    }

                    Write-Output @{ "lang" = $language.ToLowerInvariant(); "listing" = $listing }
                }
                catch [System.InvalidCastException]
                {
                    Write-Log "Provided .xml file is not a valid .xml document: $xmlFilePath" -Level Error
                    throw "Halt Execution"
                }
            }
        }
    }
}

function Convert-InAppProductListingsMetadata
{
<#
    .SYNOPSIS
        Top-level function for consuming localized metadata about the In-App Product submission.
        Each language's .xml file, in a subfolder under XmlListingsRootPath, is parsed and
        added to the listings object with the language as the key.

    .PARAMETER PDPRootPath
        The root path to the directory containing language-specific subfolders holding the
        localized metadata.

    .PARAMETER PDPInclude
        The name of the XML file to be parsed (same for every language). Wildcards are allowed.
        It is okay to specify both 'PDPInclude' and 'PDPExclude'.

    .PARAMETER PDPExclude
        XML filenames to be excluded from parsing. Wildcards are allowed. It is okay to specify
        both 'PDPInclude' and 'PDPExclude'.

    .PARAMETER LanguageExclude
        Array of lang-code strings that SHOULD NOT be processed.

    .PARAMETER ImagesRootPath
        The root path to the directory where this submission's images are located.

    .OUTPUTS
        Hashtable  A hastable with each key being a language and the corresponding value, an object
                   containing localized data for the app (Title, Description, Icon, etc.)

    .EXAMPLE
        Convert-InAppProductListingsMetadata -PDPRootPath 'C:\PDP\' -PDPInclude 'InAppProductDescription.xml' -ImagesRootPath 'C:\IapIcons'

        Assumes the folder structure:
        C:\PDP\language1\...\InAppProductDescription.xml
        C:\PDP\language2\...\InAppProductDescription.xml
#>
    [CmdletBinding()]
    [OutputType([Hashtable])]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({
            if (Test-Path -PathType Container -Path $_) { $true } 
            else { throw "'$_' is not a directory or cannot be found." } })]
        [string] $PDPRootPath,

        [Parameter(Mandatory)]
        [AllowNull()]
        [AllowEmptyString()]
        [string[]] $PDPInclude,

        [Parameter(Mandatory)]
        [AllowNull()]
        [AllowEmptyString()]
        [string[]] $PDPExclude,

        [Parameter(Mandatory)]
        [AllowNull()]
        [AllowEmptyString()]
        [string[]] $LanguageExclude,

        [Parameter(Mandatory)]
        [ValidateScript({ 
            if (Test-Path -PathType Container -Path $_) { $true }
            else { throw "'$_' is not a directory or cannot be found." } })]
        [string] $ImagesRootPath
    )

    $listings = @{}

    (Get-ChildItem -File $PDPRootPath -Recurse -Include $PDPInclude -Exclude $PDPExclude).FullName |
        Convert-InAppProductListingToObject -PDPRootPath $PDPRootPath -LanguageExclude $LanguageExclude -ImagesRootPath $ImagesRootPath |
        ForEach-Object { $listings[$_."lang"] = $_."listing" }

    return $listings
}

function Get-AppxIdentity
{
<#
    .SYNOPSIS
        Gets the ManifestType_AppName_Version_Architecture formatted name for the specified
       .appx files.

    .DESCRIPTION
        Gets the ManifestType_AppName_Version_Architecture formatted name for the specified
        .appx files.

        If multiple .appx files are provided, they will be used to create a set of ManifestTypes
        based on their AppxManifest.xml.  Similarly, a set of Architecture types will be created.

        ManifestType includes "Desktop", "Mobile", "Universal", "Team"

        The AppName and Version returned are determined by the last .appx file provided.

    .PARAMETER AppxPath
        An array of full paths to the .appx files to be parsed.

    .PARAMETER AppxInfo
        If provided, will be updated to maintain information about the app being packaged
        (like AppName and Version) if the information can be determined.

    .OUTPUTS
        System.String. The ManifestType_AppName_Version_Architecture formatted name.

    .EXAMPLE
        "C:\path\App_x86.appx", "C:\other\path\App_arm" | Get-AppxIdentity

        Returns something like "Desktop.Mobile_App_<version>_arm.x86"

    .NOTES
        We have to use [ref] for AppxInfo because arrays are immutable.  When we add new items
        to them (via +=), it actually creates a new array behind the scenes.  If we didn't pass
        the array as [ref], then the array reference that was passed in would continue pointing
        to the original array.        
#>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(
            Mandatory,
            ValueFromPipeline)]
        [string[]] $AppxPath,

        [ref] $AppxInfo
    )

    BEGIN
    {
        Add-Type -AssemblyName System.IO.Compression.FileSystem

        $manifestTypes = @()
        $appName = ""
        $version = ""
        $archTypes = @()
    }

    PROCESS
    {
        foreach ($filePath in $AppxPath)
        {
            if ($PSCmdlet.ShouldProcess($filePath))
            {
                try
                {
                    # Copy APPX.appx to TEMP\GUID.zip
                    $appxZipPathFormat = Join-Path $env:TEMP '{0}.zip'

                    do
                    {
                        $appxZipPath = $appxZipPathFormat -f [System.Guid]::NewGuid()
                    }
                    while (Test-Path -PathType Leaf -Path $appxZipPath)

                    Write-Log "Copying (Item: $filePath) to (Target: $appxZipPath)." -Level Verbose
                    Copy-Item -Force -Path $filePath -Destination $appxZipPath

                    # Expand TEMP\GUID.zip to TEMP\GUID folder
                    $expandedAppxPath = New-TemporaryDirectory

                    Write-Log "Unzipping archive (Item: $appxZipPath) to (Target: $expandedAppxPath)." -Level Verbose
                    [System.IO.Compression.ZipFile]::ExtractToDirectory($appxZipPath, $expandedAppxPath)

                    # Get AppxManifest.xml
                    $appxManifest = Get-ChildItem -Recurse -Path $expandedAppxPath -Include 'AppxManifest.xml'
                    $xmlAppxManifest = [xml] (Get-Content -Path $appxManifest.FullName -Encoding UTF8)

                    $identityNode = $xmlAppxManifest.Package.Identity
        
                    # Ignore leading "Microsoft." string
                    $appName = $identityNode.Name -split "Microsoft.", 0, "SimpleMatch" | Where-Object Length -gt 0 | Select-Object -First 1
                    $version = $identityNode.Version
                    $archTypes += $identityNode.ProcessorArchitecture

                    foreach ($targetDevice in $xmlAppxManifest.Package.Dependencies.TargetDeviceFamily)
                    {
                        # Ignore leading "Windows." string and avoid duplicates
                        $deviceName = $targetDevice.Name -split "Windows.", 0, "SimpleMatch" | Where-Object Length -gt 0 | Select-Object -First 1
                        if ($deviceName -notin $manifestTypes)
                        {
                            $manifestTypes += $deviceName
                        }
                    }
                }
                finally
                {
                    foreach ($path in @($appxZipPath, $expandedAppxPath))
                    {
                        if ((-not [System.String]::IsNullOrEmpty($path)) -and (Test-Path $path))
                        {
                            Write-Log "Deleting item: $path" -Level Verbose
                            Remove-Item -Force -Recurse -Path $path -ErrorAction SilentlyContinue
                        }
                    }
                }
            }
        }
    }

    END
    {
        # Categories with several items are joined with a '.' separator
        $manifestTypeTag = ($manifestTypes | Sort-Object) -join '.'
        $archTag = ($archTypes | Sort-Object) -join '.'

        # Categories are joined with a '_' separator
        $formattedBundleName = @($manifestTypeTag, $appName, $version, $archTag) -join '_'

        # Track the info about this package for later processing.
        $singleAppxInfo = @{}
        $singleAppxInfo[[StoreBrokerTelemetryProperty]::AppName] = $appName
        $singleAppxInfo[[StoreBrokerTelemetryProperty]::AppxVersion] = $version
        $AppxInfo.Value += $singleAppxInfo

        return $formattedBundleName
    }
}

function Open-AppxContainer
{
<#
    .SYNOPSIS
        Given a path to a .appxbundle or .appxupload file, unzips that file to a directory
        and returns that directory path.

    .PARAMETER AppxContainerPath
        Full path to the .appxbundle or .appxupload file.

    .OUTPUTS
        System.String.  Full path to the unzipped directory.

    .EXAMPLE
        Open-AppxContainer "C:\path\App.appxbundle"

        Unzips contents of App.appxbundle to <env:Temp>\<guid>\App\ and returns that path.

    .EXAMPLE
        Open-AppxContainer "C:\path\App.appxupload"

        Same as Example 1 only with a .appxupload file.

    .NOTES
        It is up to the client function to clean the path created by this function.  If it is not
        cleaned, it will be included in the final .zip created by New-SubmissionPackage.
#>
    param(
        [Parameter(Mandatory)]
        [string] $AppxContainerPath
    )

    try
    {
        Add-Type -AssemblyName System.IO.Compression.FileSystem

        # .appxcontainer can be either .appxbundle or .appxupload
        # Copy CONTAINER.appxcontainer to tempFolderPath\GUID.zip
        $containerZipPathFormat = Join-Path $env:TEMP '{0}.zip'

        do
        {
            $containerZipPath = $containerZipPathFormat -f [System.Guid]::NewGuid()
        }
        while (Test-Path -PathType Leaf -Path $containerZipPath)

        Write-Log "Copying (Item: $AppxContainerPath) to (Target: $containerZipPath)." -Level Verbose
        Copy-Item -Force -Path $AppxContainerPath -Destination $containerZipPath

        # Expand CONTAINER.appxcontainer.zip to CONTAINER folder
        $expandedContainerPath = New-TemporaryDirectory

        Write-Log "Unzipping archive (Item: $containerZipPath) to (Target: $expandedContainerPath)." -Level Verbose
        [System.IO.Compression.ZipFile]::ExtractToDirectory($containerZipPath, $expandedContainerPath)

        return $expandedContainerPath
    }
    catch
    {
        if ((-not [System.String]::IsNullOrEmpty($expandedContainerPath)) -and (Test-Path $expandedContainerPath))
        {
            Write-Log "Deleting item: $expandedContainerPath" -Level Verbose
            Remove-Item -Force -Recurse -Path $expandedContainerPath -ErrorAction SilentlyContinue
        }

        throw
    }
    finally
    {
        if ((-not [System.String]::IsNullOrEmpty($containerZipPath)) -and (Test-Path $containerZipPath))
        {
            Write-Log "Deleting item: $containerZipPath" -Level Verbose
            Remove-Item -Force -Recurse -Path $containerZipPath -ErrorAction SilentlyContinue
        }
    }
}

function Report-UnsupportedFile
{
<#
    .SYNOPSIS
        When we can't find an .appx file inside any of our supported exceptions,
        raise a new telemetry event and report the file path.

    .PARAMETER Path
        Filepath of the file that could not be identified.
#>
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseApprovedVerbs", "", Justification="Internal-only helper method.  Best description for purpose.")]
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    if ($PSCmdlet.ShouldProcess($Path))
    {
        $telemetryProperties = @{ [StoreBrokerTelemetryProperty]::SourceFilePath = (Get-PiiSafeString -PlainText $Path) }
        Set-TelemetryEvent -EventName New-SubmissionPackage-UnsupportedFile -Properties $telemetryProperties

        Write-Log "Unable to find an .appx file in: `"$Path`"" -Level Error
    }
}

function Get-FormattedAppxContainerFileName
{
<#
    .SYNOPSIS
        Gets the ManifestType_AppName_Version_Architecture.extension formatted name for the
        specified .appxbundle, .appxupload, or .appx.

    .DESCRIPTION
        Gets the ManifestType_AppName_Version_Architecture.extension formatted name for the
        specified .appxbundle, .appxupload, or .appx.

        ManifestType is specified by each .appx and includes "Desktop", "Mobile", "Universal", "Team".
        AppName is specified in the Identity element of the AppxManifest.xml file.
        Version is specified in the Identity element of the AppxManifest.xml file.
        Architecture is specified in the Identity element of the AppxManifest.xml file.

    .PARAMETER AppxPath
        Full path to the .appxbundle, .appxupload, or .appx file.

    .PARAMETER AppxInfo
        If provided, will be updated to maintain information about the app being packaged
        (like AppName and Version) if the information can be determined.

    .PARAMETER IsNested
        Switch that identifies whether this is a top-level call of this function, or a
        recursive sub-call.  Used so that we correctly report the original filepath
        we were unable to process, instead of a nested file inside that archive.

    .OUTPUTS
        System.String. The ManifestType_AppName_Version_Architecture.extension string.

    .EXAMPLE
        Get-FormattedAppxContainerFileName "C:\path\MessagingApp.appxbundle"

        If MessagingApp.appxbundle was built for x86/arm, would return something like
        "Desktop.Mobile_Messaging_2.13.22002.0_arm.x86.appxbundle"

    .EXAMPLE
        Get-FormattedAppxContainerFileName "C:\path\Maps_x86.appxupload"

        Would return something like "Desktop_Maps_2.13.22002.0_x86.appxupload"
#>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({
            if (Test-Path -PathType Leaf -Include ($script:supportedExtensions | ForEach-Object { "*" + $_ }) $_) { $true }
            else { throw "$_ cannot be found or is not a supported extension: $($script:supportedExtensions -join ", ")." } })]
        [string] $AppxPath,

        [ref] $AppxInfo,

        [switch] $IsNested
    )

    if ($PSCmdlet.ShouldProcess($AppxPath))
    {
        try
        {
            $fileName = Split-Path -Leaf -Path $AppxPath
            $formattedIdentity = $fileName
            $extension = [System.IO.Path]::GetExtension($AppxPath)

            $appxFilePaths = @()
            switch ($extension)
            {
                ".appxbundle"
                {
                    $expandedContainerPath = Open-AppxContainer -AppxContainerPath $AppxPath

                    # Get AppxBundleManifest.xml
                    $bundleManifestPath = (Get-ChildItem -Recurse -Path $expandedContainerPath -Include 'AppxBundleManifest.xml').FullName
                    if ($null -ne $bundleManifestPath)
                    {
                        Write-Log "Opening `"$bundleManifestPath`"." -Level Verbose

                        $xmlBundleManifest = [xml] (Get-Content -Path $bundleManifestPath -Encoding UTF8)

                        # When using -Confirm, PS will ask user to confirm selecting 'FileName'.
                        # Explicitly set -Confirm:$false to prevent this dialog from reaching the user.
                        $applications = $xmlBundleManifest.Bundle.Packages.ChildNodes | Where-Object Type -like "application" | ForEach-Object FileName -Confirm:$false
                        foreach ($application in $applications)
                        {
                            $appxFilePaths += (Get-ChildItem -Recurse -Path $expandedContainerPath -Include $application).FullName
                        }
                    }
                }

                ".appxupload"
                {
                    $expandedContainerPath = Open-AppxContainer -AppxContainerPath $AppxPath

                    $appxFilePaths = (Get-ChildItem -Recurse -Path $expandedContainerPath -Include "*.appx").FullName
                    if ($null -eq $appxFilePaths)
                    {
                        $appxFilePaths = (Get-ChildItem -Recurse -Path $expandedContainerPath -Include "*.appxbundle").FullName
                        if ($null -ne $appxFilePaths)
                        {
                            $formattedIdentity = (Get-FormattedAppxContainerFileName -AppxPath $appxFilePaths -AppxInfo $AppxInfo -IsNested)
                            $formattedIdentity = ([System.IO.Path]::GetFileNameWithoutExtension($formattedIdentity) + ".appxupload")
                        }
                    }
                }

                ".appx"
                {
                    $appxFilePaths = $AppxPath
                }
            }

            if ($appxFilePaths.Count -eq 0)
            {
                throw "No supported files were found for examination."
            }

            if ($formattedIdentity -eq $fileName)
            {
                $formattedIdentity = (Get-AppxIdentity -AppxPath $appxFilePaths -AppxInfo $AppxInfo) + $extension
            }

            return $formattedIdentity
        }
        catch
        {
            if (-not $IsNested)
            {
                # In this case, we weren't able to find any appx files to open.
                # Report the file we tried to package.
                Report-UnsupportedFile -Path $AppxPath
            }

            throw "Unable to find an .appx file in: `"$AppxPath`""
        }
        finally
        {
            if ((-not [System.String]::IsNullOrEmpty($expandedContainerPath)) -and (Test-Path $expandedContainerPath))
            {
                Write-Log "Deleting item: $expandedContainerPath" -Level Verbose
                Remove-Item -Force -Recurse -Path $expandedContainerPath -ErrorAction SilentlyContinue
            }
        }
    }
}

function Add-AppPackagesMetadata
{
<#
    .SYNOPSIS
        Adds a property to the SubmissionObject with metadata about the
        various .appxbundle, .appxupload, or .appx files being submitted.

    .PARAMETER AppxPath
        Array of full paths to the .appxbundle, .appxupload, or .appx
        files that will be uploaded as the new submission.

    .PARAMETER SubmissionObject
        A PSCustomObj representing the application submission request body.  This function
        will add a property to this object with metadata about the .appx files being uploaded.

    .PARAMETER AppxInfo
        If provided, will be updated to maintain information about the app being packaged
        (like AppName and Version) if the information can be determined.

    .PARAMETER EnableAutoPackageNameFormatting
        If specified, the packages will be renamed using a consistent naming scheme, which
        embeds the application name, version, as well as targeted platform and architecture.

    .EXAMPLE
        Add-AppPackagesMetadata -AppxPath "C:\App.appxbundle" -SubmissionObject $object

        Adds metadata about "C:\App.appxbundle" to the $object object.

    .EXAMPLE
        $object | Add-AppPackagesMetadata -AppxPath "C:\x86\App_x86.appxbundle"

        Same as Example 1 except the $object object is piped in to the function and the appxbundle
        used is for x86 architecture.
#>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({ 
            foreach ($path in $_)
            {
                if (-not (Test-Path -PathType Leaf -Include ($script:supportedExtensions | ForEach-Object { "*" + $_ }) -Path $path))
                {
                    throw "$_ is not a file or cannot be found."
                } 
            }

            return $true
        })]
        [string[]] $AppxPath,

        [Parameter(
            Mandatory,
            ValueFromPipeline)]
        [PSCustomObject] $SubmissionObject,

        [ref] $AppxInfo,

        [switch] $EnableAutoPackageNameFormatting
    )

    $SubmissionObject | Add-Member -MemberType NoteProperty -Name "applicationPackages" -Value ([System.Array]::CreateInstance([Object], 0))

    foreach ($path in $AppxPath)
    {
        if ($PSCmdlet.ShouldProcess($path))
        {

            $appxName = Split-Path -Leaf -Path $path

            # We always calculate the formatted name, even if we won't use it, in order to
            # populate $AppxInfo with the additional metadata.
            $formattedAppxName =  Get-FormattedAppxContainerFileName -AppxPath $path -AppxInfo $AppxInfo
            if ($EnableAutoPackageNameFormatting)
            {
                $appxName = $formattedAppxName
            }

            $appPackageObject = New-Object System.Object | Add-Member -PassThru -NotePropertyMembers @{
                fileName = $appxName;
                fileStatus = "PendingUpload";
                version = $null;
                architecture = $null;
                languages = [System.Array]::CreateInstance([Object], 0);
                capabilities = [System.Array]::CreateInstance([Object], 0);
                minimumDirectXVersion = "None";
                minimumSystemRam = "None";
            }

            if ($script:tempFolderExists)
            {
                $destinationPath = Join-Path $script:tempFolderPath $appxName
                Write-Log "Copying (Item: $path) to (Target: $destinationPath)" -Level Verbose
                Copy-Item -Path $path -Destination $destinationPath
            }

            $SubmissionObject.applicationPackages += $appPackageObject
        }
    }
}

function Remove-DeprecatedProperties
{
<#
    .SYNOPSIS
        Returns back a modified version of the submission request body that has removed
        any properties that have been deprecated by the Store team.

    .PARAMETER SubmissionRequestBody
        A PSCustomObject representing the submission request body that may contain
        properties that have been deprecated.

    .OUTPUTS
        PSCustomObject  An object representing the full application submission request, with
                        deprecated properties removed.

    .EXAMPLE
        $updated = Remove-DeprecatedProperties $submissionRequestBody

        Scans the provided request body, and returns back a modified version that has any
        deprecated properties removed.
#>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "", Justification="This is intended to be where all deprecated properties are removed.  It's an accurate name.")]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject] $SubmissionRequestBody

    )

    # No side-effects.  We'll work off of a copy of the passed-in object
    $requestBody = DeepCopy-Object $SubmissionRequestBody
    
    # hardwareRequirements was deprecated on 5/13/2016
    # Deprecated due to business reasons.  This field is not exposed from the UI.
    $requestBody.PSObject.Properties.Remove('hardwareRequirements')

    return $requestBody
}

function Get-SubmissionRequestBody
{
<#
    .SYNOPSIS
        Creates a PSCustomObject representing the JSON that will be sent with an
        application submission request.  Some property values are taken from the
        config file, some are given static values, some depend on the arch-specific
        .appx files being submitted, and some are retrieved from localized metadata.

    .PARAMETER ConfigObj
        A PSCustomObject representing this tool's configuration file.  Some values of the
        submission are populated in the config file and retrieved here.

    .PARAMETER PDPRootPath
        Root path to the directory containing lang-code subfolders of PDPs to be processed.

    .PARAMETER Release
        Optional.  When specified, it is used to indicate the correct subfolder within
       'PDPRootPath' to find the PDP files to use.

    .PARAMETER PDPInclude
        PDP filenames that SHOULD be processed.
        Wildcards are allowed, eg "ProductDescription*.xml".
        It is fine to specify both "PDPInclude" and "PDPExclude".

    .PARAMETER PDPExclude
        PDP filenames that SHOULD NOT be processed.
        Wildcards are allowed, eg "ProductDescription*.xml".
        It is fine to specify both "PDPInclude" and "PDPExclude".

    .PARAMETER LanguageExclude
        Array of lang-code strings that SHOULD NOT be processed.

    .PARAMETER ImagesRootPath
        Root path to the directory containing release subfolders of images to be packaged.

    .PARAMETER AppxPath
        A list of file paths to be included in the package.

    .PARAMETER AppxInfo
        If provided, will be updated to maintain information about the app being packaged
        (like AppName and Version) if the information can be determined.

    .PARAMETER DisableAutoPackageNameFormatting
        By default, the packages will be renamed using a consistent naming scheme, which
        embeds the application name, version, as well as targeted platform and architecture.
        To retain the existing package filenames, specify this switch.

    .OUTPUTS
        PSCustomObject  An object representing the full application submission request.

    .NOTES
        It is expected that at least one path is missing from the map as 'AppxPath'
        is mutually exclusive with the remaining three path types.

    .EXAMPLE
        Get-SubmissionRequestBody "C:\App\Appx.appxupload" (Get-Content $ConfigPath -Encoding UTF8 | ConvertFrom-Json)

        Retrieves the submission request generated using the config file at $ConfigPath and the
        appxupload located at "C:\App\Appx.appxupload".

    .EXAMPLE
        (Get-Content $ConfigPath -Encoding UTF8 | ConvertFrom-Json) | Get-SubmissionRequestBody -AppxPath "C:\Appx_x86.appxbundle", "C:\Appx_arm.appxbundle" -Release MarchRelease

        Retrieves the submission request generated using the config file at $ConfigPath and the
        appxbundle files located at "C:\Appx_x86.appxbundle" and "C:\Appx_arm.appxbundle".
        The Release used for finding PDPs under 'PDPRootPath' is MarchRelease.
#>
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="Methods called within here make use of PSShouldProcess, and the switch is passed on to them inherently.")]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject] $ConfigObject,

        [string] $PDPRootPath,
        
        [string] $Release,

        [string[]] $PDPInclude,

        [string[]] $PDPExclude,

        [string[]] $LanguageExclude,
        
        [string] $ImagesRootPath,

        [string[]] $AppxPath,

        [ref] $AppxInfo,

        [switch] $DisableAutoPackageNameFormatting
    )

    # Add static properties and metadata about packaged binaries.
    $submissionRequestBody = $ConfigObject.appSubmission

    if ($AppxPath.Count -gt 0)
    {
        $submissionRequestBody | Add-AppPackagesMetadata -AppxPath $AppxPath -AppxInfo $AppxInfo -EnableAutoPackageNameFormatting:(-not $DisableAutoPackageNameFormatting)
    }

    if (-not [String]::IsNullOrWhiteSpace($PDPRootPath))
    {
        $submissionRequestBody | Add-Member -MemberType NoteProperty -Name "listings" -Value (New-Object System.Object)

        # Add listings information
        $listingsPath = $PDPRootPath

        # If 'Release' is present, no need to look within a sub-folder..
        if (-not [System.String]::IsNullOrWhiteSpace($Release))
        {
            $pathWithRelease = Join-Path -Path $PDPRootPath -ChildPath $Release
            if (Test-Path -PathType Container -Path $pathWithRelease)
            {
                $listingsPath = $pathWithRelease
            }
            else
            {
                $out = @()
                $out += "'$pathWithRelease' is not a valid directory or cannot be found."
                $out += "Check the values of '$script:s_PDPRootPath' and '$script:s_Release' and try again."

                Write-Log ($out -join [Environment]::NewLine) -Level Error
                throw "Halt Execution"
            }
        }

        $listingsResources = @{
            $script:s_PDPRootPath = $listingsPath;
            $script:s_PDPInclude = $PDPInclude;
            $script:s_PDPExclude = $PDPExclude;
            $script:s_LanguageExclude = $LanguageExclude;
            $script:s_ImagesRootPath = $ImagesRootPath;
        }

        $submissionRequestBody.listings = Convert-ListingsMetadata @listingsResources
    }

    $submissionRequestBody = Remove-DeprecatedProperties -SubmissionRequestBody $submissionRequestBody

    return $submissionRequestBody
}

function Get-InAppProductSubmissionRequestBody
{
<#
    .SYNOPSIS
        Creates a PSCustomObject representing the JSON that will be sent with an
        In-App Product submission request.  Some property values are taken from the
        config file, some are given static values, and some are retrieved from localized metadata.

    .PARAMETER ConfigObj
        A PSCustomObject representing this tool's configuration file.  Some values of the
        submission are populated in the config file and retrieved here.

    .PARAMETER PDPRootPath
        Root path to the directory containing lang-code subfolders of PDPs to be processed.

    .PARAMETER Release
        Optional.  When specified, it is used to indicate the correct subfolder within
       'PDPRootPath' to find the PDP files to use.

    .PARAMETER PDPInclude
        PDP filenames that SHOULD be processed.
        Wildcards are allowed, eg "InAppProductDescription*.xml".
        It is fine to specify both "PDPInclude" and "PDPExclude".

    .PARAMETER PDPExclude
        PDP filenames that SHOULD NOT be processed.
        Wildcards are allowed, eg "InAppProductDescription*.xml".
        It is fine to specify both "PDPInclude" and "PDPExclude".

    .PARAMETER LanguageExclude
        Array of lang-code strings that SHOULD NOT be processed.

    .PARAMETER ImagesRootPath
        Root path to the directory containing release subfolders of images to be packaged.

    .OUTPUTS
        PSCustomObject  An object representing the full In-App Product submission request.

    .EXAMPLE
        Get-InAppProductSubmissionRequestBody (Get-Content $ConfigPath -Encoding UTF8 | ConvertFrom-Json)

        Retrieves the submission request generated using the config file at $ConfigPath.

    .EXAMPLE
        (Get-Content $ConfigPath -Encoding UTF8 | ConvertFrom-Json) | Get-InAppProductSubmissionRequestBody -Release MarchRelease

        Retrieves the submission request generated using the config file at $ConfigPath.
        The Release used for finding PDPs under 'PDPRootPath' is MarchRelease.
#>
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="Methods called within here make use of PSShouldProcess, and the switch is passed on to them inherently.")]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject] $ConfigObject,

        [string] $PDPRootPath,
        
        [string] $Release,

        [string[]] $PDPInclude,

        [string[]] $PDPExclude,

        [string[]] $LanguageExclude,
        
        [string] $ImagesRootPath
    )

    # Add static properties and metadata about packaged binaries.
    $submissionRequestBody = $ConfigObject.iapSubmission

    if (-not [String]::IsNullOrWhiteSpace($PDPRootPath))
    {
        $submissionRequestBody | Add-Member -MemberType NoteProperty -Name "listings" -Value (New-Object System.Object)

        # Add listings information
        $listingsPath = $PDPRootPath

        # If 'Release' is present, no need to look within a sub-folder..
        if (-not [System.String]::IsNullOrWhiteSpace($Release))
        {
            $pathWithRelease = Join-Path -Path $PDPRootPath -ChildPath $Release
            if (Test-Path -PathType Container -Path $pathWithRelease)
            {
                $listingsPath = $pathWithRelease
            }
            else
            {
                $out = @()
                $out += "'$pathWithRelease' is not a valid directory or cannot be found."
                $out += "Check the values of '$script:s_PDPRootPath' and '$script:s_Release' and try again."

                Write-Log ($out -join [Environment]::NewLine) -Level Error
                throw "Halt Execution"
            }
        }

        $listingsResources = @{
            $script:s_PDPRootPath = $listingsPath;
            $script:s_PDPInclude = $PDPInclude;
            $script:s_PDPExclude = $PDPExclude;
            $script:s_LanguageExclude = $LanguageExclude;
            $script:s_ImagesRootPath = $ImagesRootPath;
        }

        $submissionRequestBody.listings = Convert-InAppProductListingsMetadata @listingsResources
    }

    return $submissionRequestBody
}

function Resolve-PackageParameters
{
<#
    .SYNOPSIS
        Ensures all required values for New-SubmissionPackage exist.

    .DESCRIPTION
        Ensures all required values for New-SubmissionPackage exist.

        If a parameter is not provided at runtime, this function will check the config
        for a value.  If there is no valid value in the config, then it will throw an
        exception.

    .PARAMETER ConfigObject
        Object representation of the config file passed to New-SubmissionPackage

    .PARAMETER ParamMap
        Hashtable mapping the parameters of New-SubmissionPackage (except for ConfigPath)
        to their provided values.

    .PARAMETER SkipValidation
        An array of parameters that this method should not attempt to validate.

    .OUTPUTS
        Hashtable with keys "PDPRootPath", "Release", "PDPInclude", "PDPExclude",
        "ImagesRootPath", "AppxPath", "OutPath", and "OutName", each with validated values.

    .EXAMPLE
        Resolve-PackagePaths -ConfigObject (Convert-AppConfig $ConfigPath) -ParamMap @{"AppxPath"=$null;"OutPath"=$null;"OutPath"=$null;"Release"=$null}

        Attempts to validate the "AppxPath", "OutPath", "OutName", and "Release" parameters by
        checking the config file for values.
#>
    [CmdletBinding()]
    [OutputType([Hashtable])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "", Justification="This is resolving multiple parameters at once.  There is no option for resolving a single parameter.")]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject] $ConfigObject,

        [Parameter(Mandatory)]
        [Hashtable] $ParamMap,

        [String[]] $SkipValidation = @()
    )

    # Generic fail message. Format with parameter name.
    $out = @()
    $out += "No value found for parameter '{0}'"
    $out += "Provide a value at runtime or in the config file."
    $out = $out -join [Environment]::NewLine

    # Generic value from config message. Format with parameter name and value
    $fromConfig = "`tUsing config value: {0} = `"{1}`""

    # 'PDPRootPath' and 'ImagesRootPath' are optional.
    # Check if there is a runtime or config value.
    foreach ($param in $script:s_PDPRootPath, $script:s_ImagesRootPath)
    {
        if ([String]::IsNullOrWhiteSpace($ParamMap[$param]))
        {
            $configVal = $ConfigObject.packageParameters.$param
            if (-not [String]::IsNullOrWhiteSpace($configVal))
            {
                $ParamMap[$param] = $configVal
                Write-Log ($fromConfig -f $param, $configVal) -Level Verbose
            }
        }

        # Check if user specified a path but the directory does not exist
        $ParamMap[$param] = $ParamMap[$param] | Where-Object { -not [String]::IsNullOrWhiteSpace($_) }
        if (-not [String]::IsNullOrWhiteSpace($ParamMap[$param]))
        {
            # Resolve path parameters to full paths. Necessary in case a path contains '.' or '..'
            $ParamMap[$param] = Convert-Path -Path $ParamMap[$param]

            if (-not (Test-Path -PathType Container -Path $ParamMap[$param]))
            {
                $out = "$($param): `"$($ParamMap[$param])`" is not a directory or cannot be found."

                Write-Log $out -Level Error
                throw "Halt Execution"
            }
        }
    }

    if (($SkipValidation -inotcontains $script:s_PDPRootPath) -and ($SkipValidation -inotcontains $script:s_ImagesRootPath))
    {
        # If either 'PDPRootPath' or 'ImagesRootPath' is present, both must be present
        if ((-not [String]::IsNullOrWhiteSpace($ParamMap[$script:s_PDPRootPath])) -xor
            (-not [String]::IsNullOrWhiteSpace($ParamMap[$script:s_ImagesRootPath])))
        {
            $out = @()
            $out += "Only one of '$script:s_PDPRootPath' and '$script:s_ImagesRootPath' was specified."
            $out += "If one of these parameters is specified, then both must be specified."

            Write-Log ($out -join [Environment]::NewLine) -Level Error
            throw "Halt Execution"
        }
    }
    

    if ($SkipValidation -inotcontains $script:s_OutPath)
    {
        # 'OutPath' is mandatory.
        if ([System.String]::IsNullOrWhiteSpace($ParamMap[$script:s_OutPath]))
        {
            $configVal = $ConfigObject.packageParameters.OutPath
            if ([System.String]::IsNullOrWhiteSpace($configVal))
            {
                Write-Log ($out -f $script:s_OutPath) -Level Error
                throw "Halt Execution"
            }
            else
            {
                $ParamMap[$script:s_OutPath] = $configVal
                Write-Log ($fromConfig -f $script:s_OutPath, $configVal) -Level Verbose
            }
        }

        # Resolve path parameters to full paths. Necessary in case a path contains '.' or '..'
        $ParamMap[$script:s_OutPath] = Convert-Path -Path $ParamMap[$script:s_OutPath]
    }


    if ($SkipValidation -inotcontains $script:s_OutName)
    {
        # 'OutName' is mandatory.
        if ([System.String]::IsNullOrWhiteSpace($ParamMap[$script:s_OutName]))
        {
            $configVal = $ConfigObject.packageParameters.OutName
            if ([System.String]::IsNullOrWhiteSpace($configVal))
            {
                Write-Log ($out -f $script:s_OutName) -Level Error
                throw "Halt Execution"
            }
            else
            {
                $ParamMap[$script:s_OutName] = $configVal
                Write-Log ($fromConfig -f $script:s_OutName, $configVal) -Level Verbose
            }
        }
    }

    # 'Release' is optional.
    # Look for a value but do not fail if none is found.
    if ([String]::IsNullOrWhiteSpace($ParamMap[$script:s_Release]))
    {
        $configVal = $ConfigObject.packageParameters.Release
        if (-not [String]::IsNullOrWhiteSpace($configVal))
        {
            $ParamMap[$script:s_Release] = $configVal
            Write-Log ($fromConfig -f $script:s_Release, $configVal) -Level Verbose
        }
    }

    # 'LanguageExclude', 'PDPInclude', and 'PDPExclude' are optional.
    # They are arrays and so need to be handled differently
    foreach ($param in $script:s_PDPInclude, $script:s_PDPExclude, $script:s_LanguageExclude)
    {
        if ($ParamMap[$param].Count -eq 0)
        {
            $configVal = $ConfigObject.packageParameters.$param
            if ($configVal.Count -gt 0)
            {
                $ParamMap[$param] = $configVal
                Write-Log ($fromConfig -f $param, ($configVal -join ', ')) -Level Verbose
            }
        }

        # Make sure we don't have null/empty strings
        $ParamMap[$param] = $ParamMap[$param] | Where-Object { -not [String]::IsNullOrWhiteSpace($_) }
    }

    # Set 'PDPInclude' default if empty
    if ($ParamMap[$script:s_PDPInclude].Count -eq 0)
    {
        $ParamMap[$script:s_PDPInclude] = @("*.xml")
        Write-Log "`tUsing default value: $script:s_PDPInclude = `"*.xml`"" -Level Verbose
    }

    if ($SkipValidation -inotcontains $script:s_AppxPath)
    {
        # 'AppxPath' is mandatory.
        if ($ParamMap[$script:s_AppxPath].Count -eq 0)
        {
            $packagePaths = @()
            $validExtensions = $script:supportedExtensions | ForEach-Object { "*" + $_ }
            foreach ($path in $ConfigObject.packageParameters.AppxPath)
            {
                if ((Test-Path -PathType Leaf -Include $validExtensions -Path $path) -and ($path -notin $packagePaths))
                {
                    $packagePaths += $path
                }
                elseif ([System.String]::IsNullOrWhiteSpace($env:TFS_DropLocation))
                {
                    $out = @()
                    $out += "`"$path`" is not a file or cannot be found."
                    $out += "See the `"$script:s_AppxPath`" object in the config file."

                    Write-Log ($out -join [Environment]::NewLine) -Level Error
                    throw "Halt Execution"
                }
                else
                {
                    $path = Join-Path $env:TFS_DropLocation $path
                    if ((Test-Path -PathType Leaf -Include $validExtensions -Path $path) -and ($path -notin $packagePaths))
                    {
                        $packagePaths += $path
                    }
                    elseif (Test-Path -PathType Container -Path $path)
                    {
                        $fullPaths = (Get-ChildItem -File -Include $validExtensions -Path (Join-Path $path "*.*")).FullName
                        foreach ($fullPath in $fullPaths)
                        {
                            if ($fullPath -notin $packagePaths)
                            {
                                $packagePaths += $fullPath
                            }
                        }
                    }
                    else
                    {
                        $out = @()
                        $out += "Could not find a file with a supported extension ($($script:supportedExtensions -join ", ")) using the relative path: '$path'."
                        $out += "See the `"$script:s_AppxPath`" object in the config file."

                        Write-Log ($out -join [Environment]::NewLine) -Level Error
                        throw "Halt Execution"
                    }
                }
            }

            $ParamMap[$script:s_AppxPath] = $packagePaths
            $quotedVals = $packagePaths | ForEach-Object { "`"$_`"" }
            Write-Log ($fromConfig -f $script:s_AppxPath, ($quotedVals -join ', ')) -Level Verbose
        }

        # Resolve AppxPath to a list of full paths.
        $ParamMap[$script:s_AppxPath] = $ParamMap[$script:s_AppxPath] | ForEach-Object { Convert-Path -Path $_ }
    }

    if ($SkipValidation -inotcontains $script:s_DisableAutoPackageNameFormatting)
    {
        # Switches always have a concrete value ($true or $false).  Therefore, we'll only consider a
        # switch to have been passed-in from the command-line (thus, overriding the config's value)
        # if its value is $true.
        if (-not $ParamMap[$script:s_DisableAutoPackageNameFormatting])
        {
            $configVal = $ConfigObject.packageParameters.DisableAutoPackageNameFormatting
            if ([System.String]::IsNullOrWhiteSpace($configVal))
            {
                $configVal = $false
            }

            $ParamMap[$script:s_DisableAutoPackageNameFormatting] = $configVal
            Write-Log ($fromConfig -f $script:s_DisableAutoPackageNameFormatting, $configVal) -Level Verbose
        }
    }
    return $ParamMap
}


filter Remove-Comment
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
        "example", "test // input", "// remove this" | Remove-Comment

        "example", "test "
#>

    param(
        [string] $CommentDelimiter = "//",

        [Parameter(
            Mandatory,
            ValueFromPipeline)]
        [AllowEmptyString()] # Mandatory parameters usually do not allow empty string, causing an error. Allow them but filter them out.
        [string[]] $Line
    )

    # Filter text following the comment delimiter, empty lines, and lines that are only whitespace.
    $Line |
        ForEach-Object { ($_ -split $CommentDelimiter)[0] } |
        Where-Object   {  $_ -notmatch '^\s*$' }
}

function Convert-AppConfig
{
<#
    .SYNOPSIS
        Opens the specified config file, removes comments, and returns the contents as a PSCustomObject

    .PARAMETER ConfigPath
        Full path to a .json file which will be interpreted as the Packaging Tool's config file

    .OUTPUTS
        PSCustomObject

    .EXAMPLE
        Convert-AppConfig -ConfigPath 'C:\Some\Path\MapsConfig.json'

        Returns MapsConfig.json represented as a PSCustomObject
#>

    param(
        [Parameter(Mandatory)]
        [ValidateScript({ if (Test-Path -PathType Leaf $_) { $true } else { throw "$_ cannot be found." } })]
        [string] $ConfigPath
    )

    $lines = (Get-Content -Path $ConfigPath -Encoding UTF8 | Remove-Comment) -join ''
        
    return ($lines | ConvertFrom-Json)
}

function Join-SubmissionPackage
{
<#
    .SYNOPSIS
        Merges the specified content from an ancillary StoreBroker payload into the master payload.

    .DESCRIPTION
        Merges the specified content from an ancillary StoreBroker payload into the master payload.
        This is most useful in the scenario where you have packages that are coming from different
        builds that should all be part of the same Store submission update.
        
        Users will only specify the .json files for the two payloads, with the expectation that
        the .zip will be at the same location and same name as its complementary .json file.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER MasterJsonPath
        The path to the .json file for the StoreBroker payload that will receive the additional
        specified content from AdditionalJsonPath.  The .zip for this payload should be located
        in the same folder with the same root name.

    .PARAMETER AdditionalJsonPath
        The path to the .json file for the StoreBroker payload whose specified content will be
        merged into MasterJsonPath.  The .zip for this payload should be located in the same
        folder with the same root name.

    .PARAMETER OutJsonPath
        The path to the .json file that should contain the merged content.  A .zip file with
        the same root name will be placed here as well.

    .PARAMETER AddPackages
        If specified, the packages from AdditionalJsonPath will be merged with those in
        MasterJsonPath

    .EXAMPLE
        Join-SubmissionPackage c:\SBCallingRS1.json c:\SBCallingTH2.json c:\SBCallingMerged.json -AddPackages

        Creates a new json called c:\SBCallingMerged.json that is a direct copy of
        c:\SBCallingRS1.json.  The application package entries from c:\SBCallingTH2.json will be
        copied into there, and the actual packages from c:\SBCallingTH2.zip will be copied into
        c:\SBCallingMerged.zip
#>
    [CmdletBinding(SupportsShouldProcess=$True)]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateScript({if (Test-Path -Path $_ -PathType Leaf) { $true } else { throw "$_ cannot be found." }})]
        [string] $MasterJsonPath,
 
        [Parameter(Mandatory=$true)]
        [ValidateScript({if (Test-Path -Path $_ -PathType Leaf) { $true } else { throw "$_ cannot be found." }})]
        [string] $AdditionalJsonPath,

        [Parameter(Mandatory=$true)]
        [ValidateScript({if (Test-Path -Path $_ -PathType Leaf) {  throw "$_ already exists. Choose a different name." } else { $true }})]
        [string] $OutJsonPath,
        
        [switch] $AddPackages
    )

    Add-Type -AssemblyName System.IO.Compression.FileSystem

    # Fix the paths
    $MasterJsonPath = Convert-Path $MasterJsonPath
    $AdditionalJsonPath = Convert-Path $AdditionalJsonPath

    # Determine the paths to the zip files for these json files
    $masterZipPath = Join-Path (Split-Path $MasterJsonPath -Parent) "$([System.IO.Path]::GetFileNameWithoutExtension($MasterJsonPath)).zip"
    $additionalZipPath = Join-Path (Split-Path $AdditionalJsonPath -Parent) "$([System.IO.Path]::GetFileNameWithoutExtension($AdditionalJsonPath)).zip"
    $outZipPath = Join-Path (Split-Path $OutJsonPath -Parent) "$([System.IO.Path]::GetFileNameWithoutExtension($OutJsonPath)).zip"

    # Make sure that these zip files actually exist.
    foreach ($zipFile in ($masterZipPath, $additionalZipPath))
    {
        if (-not (Test-Path -Path $zipFile -PathType Leaf))
        {
            throw "Could not find [$zipFile].  We expect the .json and .zip to have the same base name."
        }
    }

    # Make sure that the output one *doesn't* exist
    if (Test-Path -Path $outZipPath -PathType Leaf)
    {
        throw "[$outZipPath] already exists. Please choose a different name."
    }

    # Warn the user if they didn't specify anything to actually get merged in.
    # At the moment, the only switch supported is AddPackages, but this may change over time.
    if (-not $AddPackages)
    {
        $output = @()
        $output += "You have not specified any `"modification`" switch for joining the packages."
        $output += "This means that the new package payload will be identical to the Master [$MasterJsonPath]."
        $output += "If this was not your intention, please read-up on the documentation for this command:"
        $output += "     Get-Help Join-PackagePayload -ShowWindow"
        Write-Log $($output -join [Environment]::NewLine) -Level Warning
    }

    # Unpack the zips
    # out zip content will be based off of master, so we can just consider master's zip as "out"
    $outUnpackedZipPath = New-TemporaryDirectory
    if ($PSCmdlet.ShouldProcess($masterZipPath, "Unzip"))
    {
        Write-Log "Unzipping archive [$masterZipPath] to [$outUnpackedZipPath]" -Level Verbose
        [System.IO.Compression.ZipFile]::ExtractToDirectory($masterZipPath, $outUnpackedZipPath)
    }

    $additionalUnpackedZipPath = New-TemporaryDirectory
    if ($PSCmdlet.ShouldProcess($additionalZipPath, "Unzip"))
    {
        Write-Log "Unzipping archive [$additionalZipPath] to [$additionalUnpackedZipPath]" -Level Verbose
        [System.IO.Compression.ZipFile]::ExtractToDirectory($additionalZipPath, $additionalUnpackedZipPath)
    }

    # out json content will be based off of master, so we can just consider master's json as "out"
    $outJsonContent = (Get-Content -Path $MasterJsonPath -Encoding UTF8) | ConvertFrom-Json
    $additionalJsonContent = (Get-Content -Path $AdditionalJsonPath -Encoding UTF8) | ConvertFrom-Json

    if ($AddPackages)
    {
        # We copy over all package changes from the "AdditionalJson", including package removals,
        # package uploads and specified retention of existing packages.
        Write-Log "Adding applicationPackages from [$AdditionalJsonPath] to [$OutJsonPath]" -Level Verbose
        $outJsonContent.applicationPackages += $additionalJsonContent.applicationPackages

        # Copy packages from Additional over to Master
        foreach ($package in $additionalJsonContent.applicationPackages)
        {
            # Error if the same filename already exists.
            # We'll only try to copy over files that are marked as PendingUpload since those are
            # the only new ones that the API will attempt to process.
            if ($package.fileStatus -eq "PendingUpload")
            {
                $destPath = Join-Path $outUnpackedZipPath $package.fileName
                if (Test-Path $destPath -PathType Leaf)
                {
                    $output = "A package called [$($package.fileName)] already exists in the Master zip file."
                    Write-Log $output -Level Error
                    throw $output
                }

                $sourcePath = Join-Path $additionalUnpackedZipPath $package.fileName
                Write-Log "Copying [$sourcePath] to [$destPath]" -Level Verbose
                Copy-Item -Path $sourcePath -Destination $destPath
            }
        }
    }

    # Zip up out directory to $outZipPath
    if ($PSCmdlet.ShouldProcess($outZipPath, "Create zip"))
    {
        Write-Log "Zipping [$outUnpackedZipPath] into [$outZipPath]" -Level Verbose
        [System.IO.Compression.ZipFile]::CreateFromDirectory($outUnpackedZipPath, $outZipPath)
    }

    # Output the merged json
    if ($PSCmdlet.ShouldProcess($OutJsonPath, "Create json"))
    {
        $outJsonContent | ConvertTo-Json -Depth $script:jsonConversionDepth -Compress | Out-File -Encoding utf8 -FilePath $OutJsonPath
    }

    # Clean up the temp directories
    Write-Log "Cleaning up temp directories..." -Level Verbose
    Remove-Item -Path $outUnpackedZipPath -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $additionalUnpackedZipPath -Recurse -Force -ErrorAction SilentlyContinue
}

function New-SubmissionPackage
{
<#
    .SYNOPSIS
        Top-level function for creating an application submission's JSON body
        and .zip package for upload.

    .DESCRIPTION
        Creates the JSON body for a submission request.  Localized listing metadata
        is taken from the path specified in the config file.

        The .appxbundle, .appxupload, and .appx files are given via the [-AppxPath] parameter.

        In the process of creating the JSON, the packaging tool also copies any specified
        images and .appx files to a .zip file.

        The .json and .zip files generated by this tool are given the common name specified by
        the [-OutName] parameter.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER ConfigPath
        Full path to the JSON file the Packaging Tool will use as the configuration file.

    .PARAMETER PDPRootPath
       There are two supported layouts for your PDP files:
           1. <PDPRootPath>\<lang-code>\...\PDP.xml
           2. <PDPRootPath>\<Release>\<lang-code>\...\PDP.xml
       The only difference between these two is that there is a <Release> directory after the
       <PDPRootPath> and before the <lang-code> sub-directories.
      
       The first layout is generally used when your localization system will be downloading
       the localized PDP files during your build.  In that situation, it's always retrieving
       the latest version.  Alternatively, if the latest localized versions of your PDP
       files are always stored in the same location, this layout is also for you.
      
       On the other hand, if you will be archiving the localized PDP's based on each release
       to the Store, then the second layout is the one that you should use.  In this scenario,
       you will specify the value of "<Release>" immediately below, or at the commandline.

    .PARAMETER Release
        Optional.  When specified, it is used to indicate the correct subfolder within
       'PDPRootPath' to find the PDP files to use.

    .PARAMETER PDPInclude
        PDP filenames that SHOULD be processed.
        If not specified, the default is to process any XML files found in sub-directories
        of [-PDPRootPath].
        Wildcards are allowed, eg "ProductDescription*.xml".
        It is fine to specify both "PDPInclude" and "PDPExclude".

    .PARAMETER PDPExclude
        PDP filenames that SHOULD NOT be processed.
        Wildcards are allowed, eg "ProductDescription*.xml".
        It is fine to specify both "PDPInclude" and "PDPExclude".

    .PARAMETER LanguageExclude
        Array of lang-code strings that SHOULD NOT be processed.

    .PARAMETER ImagesRootPath
        Your store screenshots must be placed with this structure:
            <ImagesRootPath>\<Release>\<lang-code>\...\img.png
        
        The 'Release' that will be used is NOT the value specified to StoreBroker,
        it is the 'Release' value found in the corresponding PDP file.

    .PARAMETER AppxPath
        Array of full paths to the architecture-neutral .appxbundle, .appxupload, or .appx
        files that will be uploaded as the new submission.
        
    .PARAMETER OutPath
        Full path to a directory where the Packaging Tool can write the .json submission request
        body and .zip package to upload.

    .PARAMETER OutName
        Common name to give to the .json and .zip files outputted by the Packaging Tool.

    .PARAMETER DisableAutoPackageNameFormatting
        By default, the packages will be renamed using a consistent naming scheme, which
        embeds the application name, version, as well as targeted platform and architecture.
        To retain the existing package filenames, specify this switch.

    .EXAMPLE
        New-SubmissionPackage -ConfigPath 'C:\Config\StoreBrokerConfig.json' -OutPath 'C:\Out\Path\' -OutName 'Upload' -Release MarchRelease -AppxPath 'C:\bin\App.appxbundle'
        
        This example creates the submission request body and .zip file for the architecture-neutral
        '.appxbundle' located at 'C:\bin\App.appxbundle'.  Two files will be placed under 'C:\Out\Path\',
        'Upload.json' and 'Upload.zip'

    .EXAMPLE
        New-SubmissionPackage -ConfigPath 'C:\Config\StoreBrokerConfig.json' -OutPath 'C:\Out\Path\' -OutName 'Upload' -Release MarchRelease -AppxPath 'C:\bin\App.appxbundle' -Verbose
        
        This example is the same except it specifies Verbose logging and the function will output a
        detailed report of its actions.

    .EXAMPLE
        New-SubmissionPackage -ConfigPath 'C:\Config\StoreBrokerConfig.json' -OutPath 'C:\Out\Path\' -OutName 'Upload' -Release MarchRelease -AppxPath 'C:\bin\x86\App_x86.appxupload', 'C:\Other\Path\Arm\App_arm.appxupload'
        
        This example is the same except it specifies an x86 and Arm build.  Multiple files to
        include can be passed to 'AppxPath' by separating with a comma.
#>

    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({ if (Test-Path -PathType Leaf $_) { $true } else { throw "$_ cannot be found." } })]
        [string] $ConfigPath,

        [ValidateScript({ if (Test-Path -PathType Container $_) { $true } else { throw "$_ cannot be found." } })]
        [string] $PDPRootPath,

        [string] $Release,

        [string[]] $PDPInclude,

        [string[]] $PDPExclude,

        [string[]] $LanguageExclude,

        [ValidateScript({ if (Test-Path -PathType Container $_) { $true } else { throw "$_ cannot be found." } })]
        [string] $ImagesRootPath,

        [ValidateScript({ 
            foreach ($path in $_)
            {
                if (-not (Test-Path -PathType Leaf -Include ($script:supportedExtensions | ForEach-Object { "*" + $_ }) -Path $path))
                {
                    throw "$_ is not a file or cannot be found."
                } 
            }

            return $true
        })]
        [string[]] $AppxPath,

        [ValidateScript({ if (Test-Path -PathType Container $_) { $true } else { throw "$_ cannot be found." } })]
        [string] $OutPath,

        [string] $OutName,

        [switch] $DisableAutoPackageNameFormatting
    )

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    try 
    {
        Add-Type -AssemblyName System.IO.Compression.FileSystem

        # Preamble before printing invocation parameters
        Write-Log "New-SubmissionPackage invoked with parameters:" -Level Verbose
        Write-Log "`t$script:s_ConfigPath = `"$ConfigPath`"" -Level Verbose

        # Check the value of each parameter and add to parameter hashtable if not null.
        # Resolve-PackageParameters will take care of validating the values, we only need
        # to avoid splatting null values as this will generate a runtime exception.
        # Log the value of each parameter.
        $validationSet = $script:s_PDPRootPath, $script:s_Release, $script:s_PDPInclude, $script:s_PDPExclude, $script:s_LanguageExclude, $script:s_ImagesRootPath, $script:s_AppxPath, $script:s_OutPath, $script:s_OutName, $script:s_DisableAutoPackageNameFormatting
        $packageParams = @{}
        foreach ($param in $validationSet)
        {
            $val = Get-Variable -Name $param -ValueOnly -ErrorAction SilentlyContinue |
                   Where-Object { -not [String]::IsNullOrWhiteSpace($_) }

            # ([string] $null) -ne $null, is true.
            # Explicitly check the type of the value to avoid printing [string] params that are $null.
            if ((($val -isnot [System.String]) -and ($null -ne $val)) -or 
                (($val -is [System.String]) -and (-not [String]::IsNullOrWhiteSpace($val))))
            {
                $packageParams[$param] = $val
                
                # Treat the value as if it is an array.
                # If it's not, it will still pretty print fine.
                $quotedVals = $val | ForEach-Object { "`"$_`"" }
                Write-Log "`t$param = $($quotedVals -join ', ')" -Level Verbose
            }
        }
        
        # Convert the Config.json
        $config = Convert-AppConfig -ConfigPath $ConfigPath

        # Check that all parameters are provided or specified in the config
        $validatedParams = Resolve-PackageParameters -ConfigObject $config -ParamMap $packageParams

        # Assign final, validated params
        $validationSet |
            Where-Object { $null -ne $validatedParams[$_] } |
            ForEach-Object { Set-Variable -Name $_ -Value $validatedParams[$_] -ErrorAction SilentlyContinue }

        # Create a temp directory to work in
        $script:tempFolderPath = New-TemporaryDirectory

        # It may not actually exist due to What-If support.
        $script:tempFolderExists = (-not [System.String]::IsNullOrEmpty($script:tempFolderPath)) -and 
                                   (Test-Path -PathType Container $script:tempFolderPath)

        # Get the submission request object
        $resourceParams = $script:s_PDPRootPath, $script:s_Release, $script:s_PDPInclude, $script:s_PDPExclude, $script:s_LanguageExclude, $script:s_ImagesRootPath, $script:s_AppxPath, $script:s_DisableAutoPackageNameFormatting
        $params = Get-Variable -Name $resourceParams -ErrorAction SilentlyContinue |
                  ForEach-Object { $m = @{} } { $m[$_.Name] = $_.Value } { $m } # foreach begin{} process{} end{}

        $AppxInfo = @()
        $submissionBody = Get-SubmissionRequestBody -ConfigObject $config -AppxInfo ([ref]$AppxInfo) @params

        Write-SubmissionRequestBody -JsonObject $submissionBody -OutFilePath (Join-Path $OutPath ($OutName + '.json'))

        # Zip the contents of the temporary directory.  Then delete the temporary directory.
        $zipPath = Join-Path $OutPath ($OutName + '.zip')

        if ($PSCmdlet.ShouldProcess($zipPath, "Output to File") -and $script:tempFolderExists)
        {
            if (Test-Path -PathType Leaf $zipPath)
            {
                Remove-Item -Force -Recurse -Path $zipPath
            }

            [System.IO.Compression.ZipFile]::CreateFromDirectory($script:tempFolderPath, $zipPath)
        }

        # Record the telemetry for this event.
        $stopwatch.Stop()
        $telemetryMetrics = @{ [StoreBrokerTelemetryMetric]::Duration = $stopwatch.Elapsed.TotalSeconds }
        
        # We may have app info for multiple packages.  Let's normalize it.
        # By the very nature of how the Store works, all the packages have to be for the same app.
        # There can be multiple versions being submitted in a single submission.  For our purposes,
        # we'll just use the last processed appx for this submission...that should be good enough.
        $telemetryProperties = @{}
        if ($AppxInfo.Count -gt 0)
        {
            $telemetryProperties = $AppxInfo[$AppxInfo.Count - 1]
        }

        Set-TelemetryEvent -EventName New-SubmissionPackage -Properties $telemetryProperties -Metrics $telemetryMetrics
    }
    catch
    {
        # We may have app info for multiple packages.  Let's normalize it.
        # By the very nature of how the Store works, all the packages have to be for the same app.
        # There can be multiple versions being submitted in a single submission.  For our purposes,
        # we'll just use the last processed appx for this submission...that should be good enough.
        $telemetryProperties = @{}
        if ($AppxInfo.Count -gt 0)
        {
            $telemetryProperties = $AppxInfo[$AppxInfo.Count - 1]
        }

        Set-TelemetryException -Exception $_.Exception -ErrorBucket "New-SubmissionPackage" -Properties $telemetryProperties
        Write-Log $($_.Exception.Message) -Level Error

        throw
    }
    finally
    {
        if ($script:tempFolderExists)
        {
            Write-Log "Deleting temporary directory: $script:tempFolderPath" -Level Verbose
            Remove-Item -Force -Recurse $script:tempFolderPath -ErrorAction SilentlyContinue
        }
    }
}

function New-InAppProductSubmissionPackage
{
<#
    .SYNOPSIS
        Top-level function for creating an in-app product submission's JSON body
        and .zip package for upload.

    .DESCRIPTION
        Creates the JSON body for a submission request.  Localized listing metadata
        is taken from the path specified in the config file.

        In the process of creating the JSON, the packaging tool also copies any specified
        images to a .zip file.

        The .json and .zip files generated by this tool are given the common name specified by
        the [-OutName] parameter.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER ConfigPath
        Full path to the JSON file the Packaging Tool will use as the configuration file.

    .PARAMETER PDPRootPath
       There are two supported layouts for your PDP files:
           1. <PDPRootPath>\<lang-code>\...\PDP.xml
           2. <PDPRootPath>\<Release>\<lang-code>\...\PDP.xml
       The only difference between these two is that there is a <Release> directory after the
       <PDPRootPath> and before the <lang-code> sub-directories.
      
       The first layout is generally used when your localization system will be downloading
       the localized PDP files during your build.  In that situation, it's always retrieving
       the latest version.  Alternatively, if the latest localized versions of your PDP
       files are always stored in the same location, this layout is also for you.
      
       On the other hand, if you will be archiving the localized PDP's based on each release
       to the Store, then the second layout is the one that you should use.  In this scenario,
       you will specify the value of "<Release>" immediately below, or at the commandline.

    .PARAMETER Release
        Optional.  When specified, it is used to indicate the correct subfolder within
       'PDPRootPath' to find the PDP files to use.

    .PARAMETER PDPInclude
        PDP filenames that SHOULD be processed.
        If not specified, the default is to process any XML files found in sub-directories
        of [-PDPRootPath].
        Wildcards are allowed, eg "InAppProductDescription*.xml".
        It is fine to specify both "PDPInclude" and "PDPExclude".

    .PARAMETER PDPExclude
        PDP filenames that SHOULD NOT be processed.
        Wildcards are allowed, eg "InAppProductDescription*.xml".
        It is fine to specify both "PDPInclude" and "PDPExclude".

    .PARAMETER LanguageExclude
        Array of lang-code strings that SHOULD NOT be processed.

    .PARAMETER ImagesRootPath
        Your icons must be placed with this structure:
            <ImagesRootPath>\<Release>\<lang-code>\...\icon.png
        
        The 'Release' that will be used is NOT the value specified to StoreBroker,
        it is the 'Release' value found in the corresponding PDP file.

    .PARAMETER OutPath
        Full path to a directory where the Packaging Tool can write the .json submission request
        body and .zip package to upload.

    .PARAMETER OutName
        Common name to give to the .json and .zip files outputted by the Packaging Tool.

    .EXAMPLE
        New-InAppProductSubmissionPackage -ConfigPath 'C:\Config\StoreBrokerIAPConfig.json' -OutPath 'C:\Out\Path\' -OutName 'Upload' -Release MarchRelease
        
        This example creates the submission request body and .zip file for the IAP.Two files will
        be placed under 'C:\Out\Path\', 'Upload.json' and 'Upload.zip'

    .EXAMPLE
        New-InAppProductSubmissionPackage -ConfigPath 'C:\Config\StoreBrokerIAPConfig.json' -OutPath 'C:\Out\Path\' -OutName 'Upload' -Release MarchRelease -Verbose
        
        This example is the same except it specifies Verbose logging and the function will output a
        detailed report of its actions.
#>

    [CmdletBinding(SupportsShouldProcess)]
    [Alias('New-IapSubmissionPackage')]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({ if (Test-Path -PathType Leaf $_) { $true } else { throw "$_ cannot be found." } })]
        [string] $ConfigPath,

        [ValidateScript({ if (Test-Path -PathType Container $_) { $true } else { throw "$_ cannot be found." } })]
        [string] $PDPRootPath,

        [string] $Release,

        [string[]] $PDPInclude,

        [string[]] $PDPExclude,

        [string[]] $LanguageExclude,

        [ValidateScript({ if (Test-Path -PathType Container $_) { $true } else { throw "$_ cannot be found." } })]
        [string] $ImagesRootPath,

        [ValidateScript({ if (Test-Path -PathType Container $_) { $true } else { throw "$_ cannot be found." } })]
        [string] $OutPath,

        [string] $OutName
    )

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    try 
    {
        Add-Type -AssemblyName System.IO.Compression.FileSystem

        # Preamble before printing invocation parameters
        Write-Log "New-InAppProductSubmissionPackage invoked with parameters:" -Level Verbose
        Write-Log "`t$script:s_ConfigPath = `"$ConfigPath`"" -Level Verbose

        # Check the value of each parameter and add to parameter hashtable if not null.
        # Resolve-PackageParameters will take care of validating the values, we only need
        # to avoid splatting null values as this will generate a runtime exception.
        # Log the value of each parameter.
        $validationSet = $script:s_PDPRootPath, $script:s_Release, $script:s_PDPInclude, $script:s_PDPExclude, $script:s_LanguageExclude, $script:s_ImagesRootPath, $script:s_OutPath, $script:s_OutName
        $packageParams = @{}
        foreach ($param in $validationSet)
        {
            $val = Get-Variable -Name $param -ValueOnly -ErrorAction SilentlyContinue |
                   Where-Object { -not [String]::IsNullOrWhiteSpace($_) }

            # ([string] $null) -ne $null, is true.
            # Explicitly check the type of the value to avoid printing [string] params that are $null.
            if ((($val -isnot [System.String]) -and ($null -ne $val)) -or 
                (($val -is [System.String]) -and (-not [String]::IsNullOrWhiteSpace($val))))
            {
                $packageParams[$param] = $val
                
                # Treat the value as if it is an array.
                # If it's not, it will still pretty print fine.
                $quotedVals = $val | ForEach-Object { "`"$_`"" }
                Write-Log "`t$param = $($quotedVals -join ', ')" -Level Verbose
            }
        }
        
        # Convert the Config.json
        $config = Convert-AppConfig -ConfigPath $ConfigPath

        # Check that all parameters are provided or specified in the config
        $validatedParams = Resolve-PackageParameters -ConfigObject $config -ParamMap $packageParams -SkipValidation @($script:s_DisableAutoPackageNameFormatting, $script:s_AppxPath)

        # Assign final, validated params
        $validationSet |
            Where-Object { $null -ne $validatedParams[$_] } |
            ForEach-Object { Set-Variable -Name $_ -Value $validatedParams[$_] -ErrorAction SilentlyContinue }

        # Create a temp directory to work in
        $script:tempFolderPath = New-TemporaryDirectory

        # It may not actually exist due to What-If support.
        $script:tempFolderExists = (-not [System.String]::IsNullOrEmpty($script:tempFolderPath)) -and 
                                   (Test-Path -PathType Container $script:tempFolderPath)

        # Get the submission request object
        $resourceParams = $script:s_PDPRootPath, $script:s_Release, $script:s_PDPInclude, $script:s_PDPExclude, $script:s_LanguageExclude, $script:s_ImagesRootPath
        $params = Get-Variable -Name $resourceParams -ErrorAction SilentlyContinue |
                  ForEach-Object { $m = @{} } { $m[$_.Name] = $_.Value } { $m } # foreach begin{} process{} end{}

        $submissionBody = Get-InAppProductSubmissionRequestBody -ConfigObject $config @params

        Write-SubmissionRequestBody -JsonObject $submissionBody -OutFilePath (Join-Path -Path $OutPath -ChildPath ($OutName + '.json'))

        # Zip the contents of the temporary directory.  Then delete the temporary directory.
        $zipPath = Join-Path -Path $OutPath -ChildPath ($OutName + '.zip')

        if ($PSCmdlet.ShouldProcess($zipPath, "Output to File") -and $script:tempFolderExists)
        {
            if (Test-Path -PathType Leaf $zipPath)
            {
                Remove-Item -Force -Recurse -Path $zipPath
            }

            [System.IO.Compression.ZipFile]::CreateFromDirectory($script:tempFolderPath, $zipPath)
        }

        # Record the telemetry for this event.
        $stopwatch.Stop()
        $telemetryMetrics = @{ [StoreBrokerTelemetryMetric]::Duration = $stopwatch.Elapsed.TotalSeconds }
        
        Set-TelemetryEvent -EventName New-InAppProductSubmissionPackage -Metrics $telemetryMetrics
    }
    catch
    {
        Set-TelemetryException -Exception $_.Exception -ErrorBucket "New-InAppProductSubmissionPackage"
        Write-Log $($_.Exception.Message) -Level Error

        throw
    }
    finally
    {
        if ($script:tempFolderExists)
        {
            Write-Log "Deleting temporary directory: $script:tempFolderPath" -Level Verbose
            Remove-Item -Force -Recurse $script:tempFolderPath -ErrorAction SilentlyContinue
        }
    }
}