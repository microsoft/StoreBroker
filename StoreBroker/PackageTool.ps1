# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

# Images will be placed in the .zip folder under the $packageImageFolderName subfolder
$script:packageImageFolderName = "Assets"

# New-SubmissionPackage supports these extensions, but won't inspect their content due to encryption
$script:extensionsSupportingInspection = @(".appx", ".appxbundle", ".appxupload", ".msix", ".msixbundle", ".msixupload")
$script:extensionsNotSupportingInspection = @('.xvc')
$script:supportedExtensions =  $script:extensionsSupportingInspection + $script:extensionsNotSupportingInspection

# String constants for New-SubmissionPackage parameters
$script:s_ConfigPath = "ConfigPath"
$script:s_PDPRootPath = "PDPRootPath"
$script:s_Release = "Release"
$script:s_PDPInclude = "PDPInclude"
$script:s_PDPExclude = "PDPExclude"
$script:s_LanguageExclude = "LanguageExclude"
$script:s_MediaRootPath = "MediaRootPath"
$script:s_PackagePath = "PackagePath"
$script:s_OutPath = "OutPath"
$script:s_OutName = "OutName"
$script:s_DisableAutoPackageNameFormatting = "DisableAutoPackageNameFormatting"
$script:s_MediaFallbackLanguage = "MediaFallbackLanguage"

# String constants for application metadata
$script:applicationMetadataProperties = @(
    "version",
    "architecture",
    "targetPlatform",
    "languages",
    "capabilities",
    "targetDeviceFamilies",
    "targetDeviceFamiliesEx",
    "innerPackages"
)

# The API formats version numbers as "[device family] min version [min version]"
$script:minVersionFormatString = "{0} min version {1}"

# The current version of the StoreBroker schema that PackageTool is authoring for app and IAP submissions.
# The StoreBroker schema may include metadata that isn't a core part of the official Submission API
# JSON schema (like the appId or iapId, package metadata, etc...). These values should be updated any time
# we alter what additional metadata is added to the schema for that submission type.
$script:appSchemaVersion = 3
$script:iapSchemaVersion = 2
$script:schemaPropertyName = 'sbSchema'

function Out-DirectoryToZip
{
<#
    .SYNOPSIS
        Compresses a directory to a zip file, with logging.

    .DESCRIPTION
        Compresses a directory to a zip file, with logging.

        For performance reasons, we will always zip locally, then copy the zip to the final
        destination. This gives better performance when the final destination is not on the local
        machine.

        The function uses no compression during the zip process, as we didn't see a noticeable
        difference in file size. This is because the contents we are compressing (appx/appxbundles/png)
        have already been compressed so there is not much room for improvement.

    .PARAMETER Path
        The directory to be compressed. The path given must exist.

    .PARAMETER Destination
        The path to place the compressed contents of the Path. This path does not need to exist,
        but it must end in a .zip extension.
#>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({
            if (Test-Path -PathType Container -Path $_ -ErrorAction Ignore) { $true }
            else { throw "Could not find directory to compress: [$_]." }
        })]
        [string] $Path,

        [Parameter(Mandatory)]
        [ValidateScript({
            if (($_ -like "*.zip") -and (Test-Path -IsValid -Path $_ -ErrorAction Ignore)) { $true }
            else { throw "Destination path is not a zip file: [$_]." }
        })]
        [string] $Destination
    )

    try
    {
        if ($PSCmdlet.ShouldProcess($Destination, "Output to File"))
        {
            $tempLocalZipDir = New-TemporaryDirectory
            $tempLocalZipPath = Join-Path -Path $tempLocalZipDir -ChildPath "SBTempLocalPayload.zip"

            # Delete output paths if they already exist.
            foreach ($zipPath in ($tempLocalZipPath, $Destination))
            {
                if (Test-Path -PathType Leaf -Include "*.zip" -Path $zipPath -ErrorAction Ignore)
                {
                    Write-Log -Message "Removing zip path: [$zipPath]." -Level Verbose
                    Remove-Item -Force -Recurse -Path $zipPath
                    Write-Log -Message "Removal complete." -Level Verbose
                }
            }

            # Need to add this type in-order to access the ZipFile class.
            Add-Type -AssemblyName System.IO.Compression.FileSystem

            # The contents we are compressing have already been compressed so there's not much
            # of a disadvantage to using NoCompression.
            $compressionLevel = [System.IO.Compression.CompressionLevel]::NoCompression
            $includeBaseDir = $false

            Write-Log -Message "Compressing [$Path] to [$tempLocalZipPath]." -Level Verbose
            [System.IO.Compression.ZipFile]::CreateFromDirectory($Path, $tempLocalZipPath, $compressionLevel, $includeBaseDir)
            Write-Log -Message "Compression complete." -Level Verbose

            Write-Log -Message "Moving [$tempLocalZipPath] to [$Destination]." -Level Verbose
            Move-Item -Force -Path $tempLocalZipPath -Destination $Destination
            Write-Log -Message "Move complete." -Level Verbose
        }
    }
    finally
    {
        if ($null -ne $tempLocalZipDir)
        {
            Write-Log -Message "Removing temporary directory: [$tempLocalZipDir]." -Level Verbose
            Remove-Item -Force -Recurse -Path $tempLocalZipDir -ErrorAction Ignore
            Write-Log -Message "Removal complete." -Level Verbose
        }
    }
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
        Ensure-Directory -Path (Split-Path -Parent -Path $OutFilePath)

        Write-Log -Message "Writing submission request JSON file: [$OutFilePath]." -Level Verbose

        $JsonObject |
            ConvertTo-Json -Depth $script:jsonConversionDepth -Compress |
            Out-File -Encoding utf8 -FilePath $OutFilePath

        Write-Log -Message "Writing complete." -Level Verbose
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
    # interacting with .NET libraries.  Run [string] path parameters through 'Resolve-UnverifiedPath' to
    # get a full-path before using the path with any .NET libraries.
    $XsdFile = Resolve-UnverifiedPath -Path $XsdFile
    $XmlFile = Resolve-UnverifiedPath -Path $XmlFile

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

        # Note: PSScriptAnalyzer falsely flags this next line as PSUseDeclaredVarsMoreThanAssignment due to:
        # https://github.com/PowerShell/PSScriptAnalyzer/issues/699
        $script:validationErrors | ForEach-Object { $msg += $_ }
        $msg = $msg -join [Environment]::NewLine

        Write-Log -Message $msg -Level Error
        throw $msg
    }
}

function Get-TextFromXmlElement
{
    <#
    .SYNOPSIS
        Finds the actual text contained within an XMLElement, trims it and returns it.

    .DESCRIPTION
        Finds the actual text contained within an XMLElement, trims it and returns it.

        When an XMLElement has attributes and/or inner comments, you cannot simply
        access the text directly.  This function encapsulates the necessary logic
        so that you can consistently and reliably get access to the actual element's
        text.

    .PARAMETER Element
        This is the actual property from the XML DOM that you are intested in getting
        the text of.  This might just be a String if it's a simple text element,
        or it might end up being an XMLElement itself if has attributes and/or
        comments.

    .OUTPUTS
        System.String.  The trimmed text contained within the XML element.

    .EXAMPLE
        Get-TextFromXmlElement -Element $xml.ProductDescription.Description

        Returns back the trimmed text content contained within the Description element.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [AllowEmptyString()]
        $Element
    )

    $text = $Element

    # The text is only available to be accessed raw like this if there
    # is no attribute or inner comment on the containing element.
    # If there is, then this property will actually be an XmlElement
    # itself and not a string, meaning that we have to access the
    # InnerText to get its text value.
    if ($text -is [System.Xml.XmlElement])
    {
        $text = $text.InnerText
    }

    if ($null -ne $text)
    {
        $text = $text.Trim()
    }

    return $text
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

    .PARAMETER MediaRootPath
        A path to the root path containing the new submission's media.  A screenshot
        caption has the potential for relative paths to Desktop, Mobile, and Xbox images.
        Each relative path is appended to MediaRootPath to create a full path to the image.

    .PARAMETER XmlFilePath
        A full path to the localized .xml file to be parsed.

    .PARAMETER MediaFallbackLanguage
        Some apps may not localize all of their metadata media (images, trailers, etc..)
        across all languages.  By default, StoreBroker will look in the PDP langcode's subfolder
        within MediaRootPath for that language's media content.  If the requested filename is
        not found, StoreBroker packaging will fail. If you specify a fallback language here
        (e.g. 'en-us'), then if the requested file isn't found in the PDP language's media
        subfolder, StoreBroker will then look into the fallback language's media subfolder for
        the exactly same-named image, and only fail then if it still cannot be found.
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
        [string] $MediaRootPath,

        [Parameter(
            Mandatory,
            ValueFromPipeline)]
        [string[]] $XmlFilePaths,

        [string] $MediaFallbackLanguage
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
                        Write-Log -Message $out -Level Verbose

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
                        "shortDescription"          = $ProductDescriptionNode.ShortDescription;
                        "shortTitle"                = $ProductDescriptionNode.ShortTitle;
                        "sortTitle"                 = $ProductDescriptionNode.SortTitle;
                        "voiceTitle"                = $ProductDescriptionNode.VoiceTitle;
                        "devStudio"                 = $ProductDescriptionNode.DevStudio;
                        "releaseNotes"              = $ProductDescriptionNode.ReleaseNotes;
                    }

                    # Identify the keys whose values are non-null.
                    # Must be done in two steps because $baseListings can't be modified
                    # while enumerating its keys.
                    $trimKeys = $baseListing.Keys |
                        Where-Object { ($null -ne (Get-TextFromXmlElement -Element $baseListing[$_])) }

                    $trimKeys | ForEach-Object {
                        $baseListing[$_] = Get-TextFromXmlElement -Element $baseListing[$_]
                    }

                    # For title specifically, we need to ensure that it's set to $null if there's
                    # no value.  An empty string value is not the same as $null.
                    if ([String]::IsNullOrWhiteSpace($baseListing['title']))
                    {
                        $baseListing['title'] = $null
                    }

                    # Nodes with children need to have each value extracted into an array.
                    @{
                        "features"            = $ProductDescriptionNode.AppFeatures;
                        "keywords"            = $ProductDescriptionNode.Keywords;
                        "recommendedHardware" = $ProductDescriptionNode.RecommendedHardware;
                        "minimumHardware"     = $ProductDescriptionNode.MinimumHardware;
                    }.GetEnumerator() | ForEach-Object {
                        $baseListing[$_.Name] = @($_.Value.ChildNodes |
                                                    Where-Object NodeType -eq Element |
                                                    ForEach-Object { Get-TextFromXmlElement -Element $_ } |
                                                    Where-Object { $_ -ne $null })
                    }

                    # Handle screenshots and their captions.
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
                                # We start with the fallback language specified on an individual asset.
                                # We continue to climb up to find a more generally defined FallbackLanguage
                                # until we hit the ProductDescription node.  If one is still not specified
                                # there, then we'll try using the one specified at the commandline/config file.
                                $requestedFallbackLanguage = (
                                    $caption.FallbackLanguage,
                                    $ProductDescriptionNode.ScreenshotCaptions.FallbackLanguage,
                                    $ProductDescriptionNode.FallbackLanguage,
                                    $MediaFallbackLanguage) |
                                        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                                        Select-Object -First 1


                                $params = @{
                                    'Filename' = $imageFileName
                                    'MediaRootPath' = $MediaRootPath
                                    'Language' = $language
                                    'Release' = $ProductDescriptionNode.Release
                                    'MediaFallbackLanguage' = $requestedFallbackLanguage
                                }

                                $fileRelativePackagePath = Get-LocalizedMediaFile @params

                                $imageType = $imageTypeMap[$member]
                                $imageListings += @{
                                    "fileName" = $fileRelativePackagePath;
                                    "fileStatus" = "PendingUpload";
                                    "description" = (Get-TextFromXmlElement -Element $caption);
                                    "imageType" = $imageType;
                                }
                            }
                        }
                    }

                    # Handle additional image types (those without captions: AdditionalAssets)
                    $additionalAssets = $ProductDescriptionNode.AdditionalAssets.ChildNodes |
                        Where-Object NodeType -eq Element

                    foreach ($assetType in $additionalAssets)
                    {
                        $assetTypeName = $assetType.LocalName
                        $imageFileName = $assetType.FileName

                        # We start with the fallback language specified on an individual asset.
                        # We continue to climb up to find a more generally defined FallbackLanguage
                        # until we hit the ProductDescription node.  If one is still not specified
                        # there, then we'll try using the one specified at the commandline/config file.
                        $requestedFallbackLanguage = (
                            $assetType.FallbackLanguage,
                            $ProductDescriptionNode.AdditionalAssets.FallbackLanguage,
                            $ProductDescriptionNode.FallbackLanguage,
                            $MediaFallbackLanguage) |
                                Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                                Select-Object -First 1


                        $params = @{
                            'Filename' = $imageFileName
                            'MediaRootPath' = $MediaRootPath
                            'Language' = $language
                            'Release' = $ProductDescriptionNode.Release
                            'MediaFallbackLanguage' = $requestedFallbackLanguage
                        }

                        $fileRelativePackagePath = Get-LocalizedMediaFile @params

                        $imageListings += @{
                            "fileName" = $fileRelativePackagePath;
                            "fileStatus" = "PendingUpload";
                            "imageType" = $assetTypeName;
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
                    $output = "Provided .xml file is not a valid .xml document: $xmlFilePath"
                    Write-Log -Message $output -Level Error
                    throw $output
                }
            }
        }
    }
}

function Convert-TrailersToObject
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

    .PARAMETER MediaRootPath
        A path to the root path containing the new submission's media.  A screenshot
        caption has the potential for relative paths to Desktop, Mobile, and Xbox images.
        Each relative path is appended to MediaRootPath to create a full path to the image.

    .PARAMETER XmlFilePath
        A full path to the localized .xml file to be parsed.

    .PARAMETER MediaFallbackLanguage
        Some apps may not localize all of their metadata media (images, trailers, etc..)
        across all languages.  By default, StoreBroker will look in the PDP langcode's subfolder
        within MediaRootPath for that language's media content.  If the requested filename is
        not found, StoreBroker packaging will fail. If you specify a fallback language here
        (e.g. 'en-us'), then if the requested file isn't found in the PDP language's media
        subfolder, StoreBroker will then look into the fallback language's media subfolder for
        the exactly same-named image, and only fail then if it still cannot be found.
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
        [string] $MediaRootPath,

        [Parameter(
            Mandatory,
            ValueFromPipeline)]
        [string[]] $XmlFilePaths,

        [string] $MediaFallbackLanguage
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

                    Write-Log -Message "Processing [$language]: $xmlFilePath" -Level Verbose
                    # Skip processing if language is marked for exclusion
                    if ($language -in $LanguageExclude)
                    {
                        $out = "Skipping file '$xmlFilePath' because its lang-code '$language' is in the language exclusion list."
                        Write-Log -Message $out -Level Verbose

                        return
                    }

                    $xml = [xml] (Get-Content -Path $xmlFilePath -Encoding UTF8)

                    # ProductDescription node contains the metadata
                    $ProductDescriptionNode = $xml.ProductDescription

                    # Verify xml conforms to schema
                    Test-Xml -XsdFile (Get-XsdPath -NamespaceUri $ProductDescriptionNode.xmlns) -XmlFile $xmlFilePath

                    # Handle trailer content
                    $trailers = $ProductDescriptionNode.Trailers.ChildNodes |
                        Where-Object NodeType -eq Element

                    $trailerListings = @{}
                    foreach ($trailer in $trailers)
                    {
                        $trailerTitle = Get-TextFromXmlElement -Element $trailer.Title
                        $trailerFileName = $trailer.FileName

                        # We start with the fallback language specified on the trailer.
                        # We continue to climb up to find a more generally defined FallbackLanguage
                        # until we hit the ProductDescription node.  If one is still not specified
                        # there, then we'll try using the one specified at the commandline/config file.
                        $requestedFallbackLanguage = (
                            $trailer.FallbackLanguage,
                            $ProductDescriptionNode.Trailers.FallbackLanguage,
                            $ProductDescriptionNode.FallbackLanguage,
                            $MediaFallbackLanguage) |
                                Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                                Select-Object -First 1

                        $params = @{
                            'Filename' = $trailerFileName
                            'MediaRootPath' = $MediaRootPath
                            'Language' = $language
                            'Release' = $ProductDescriptionNode.Release
                            'MediaFallbackLanguage' = $requestedFallbackLanguage
                        }

                        $trailerRelativePackagePath = Get-LocalizedMediaFile @params

                        $requestedFallbackLanguage = (
                            $trailer.Images.Image.FallbackLanguage,
                            $trailer.Images.FallbackLanguage,
                            $trailer.FallbackLanguage,
                            $ProductDescriptionNode.Trailers.FallbackLanguage,
                            $ProductDescriptionNode.FallbackLanguage,
                            $MediaFallbackLanguage) |
                                Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                                Select-Object -First 1

                        $params = @{
                            'Filename' = $trailer.Images.Image.FileName
                            'MediaRootPath' = $MediaRootPath
                            'Language' = $language
                            'Release' = $ProductDescriptionNode.Release
                            'MediaFallbackLanguage' = $requestedFallbackLanguage
                        }

                        $screenshotRelativePackagePath = Get-LocalizedMediaFile @params
                        $screenshotDescription = Get-TextFromXmlElement -Element $trailer.Images.Image

                        $trailerLangCodeListing = [ordered]@{
                            'title' = $trailerTitle
                            'imageList' = @(
                                [ordered]@{
                                    'fileName' = $screenshotRelativePackagePath
                                    'description' = $screenshotDescription
                                }
                            )
                        }

                        $trailerListings[$trailerRelativePackagePath] = @{$language = $trailerLangCodeListing}
                    }

                    Write-Output $trailerListings
                }
                catch [System.InvalidCastException]
                {
                    $output = "Provided .xml file is not a valid .xml document: $xmlFilePath"
                    Write-Log -Message $output -Level Error
                    throw $output
                }
            }
        }
    }
}

function Get-LocalizedMediaFile
{
<#
    .SYNOPSIS
        Finds the appropriately localized media file, given the filename, requested language,
        and an optional fallback language if the requested language does not contain that
        media file.

        The file will be copied to the temporary package path where the package is being
        prepared, and the relative path within that folder will be returned.

    .PARAMETER Filename
        The name of the media file that is being looked for.

    .PARAMETER MediaRootPath
        The root path to the directory where this submission's images are located.

    .PARAMETER Language
        The language of the PDP file that is requesting the localized media file.

    .PARAMETER Release
        The Release value from within an individual PDP file, indicating the sub-folder within
        MediaRootPath that the lang-code subfolders for media files can be found.

    .PARAMETER MediaFallbackLanguage
        Some apps may not localize all of their metadata media (images, trailers, etc..)
        across all languages.  By default, StoreBroker will look in the PDP langcode's subfolder
        within MediaRootPath for that language's media content.  If the requested filename is
        not found, StoreBroker packaging will fail. If you specify a fallback language here
        (e.g. 'en-us'), then if the requested file isn't found in the PDP language's media
        subfolder, StoreBroker will then look into the fallback language's media subfolder for
        the exactly same-named image, and only fail then if it still cannot be found.

    .OUTPUTS
        System.String.  Relative path to the media file as it will be found within the final StoreBroker package.

    .EXAMPLE
        Get-LocalizedMediaFile -Filename 'foo.png' -MediaRootPath 'c:\screenshots\' -Language 'fr-fr' -Release '1712'

        Checks to see if c:\screenshots\1712\fr-fr\foo.png exists.  If it does, copies it to $script:tempFolderPath\Assets\fr-fr\foo.png
        and returns 'Assets\fr-fr\foo.png'.  If it doesn't exist, throws an exception.

    .EXAMPLE
        Get-LocalizedMediaFile -Filename 'foo.png' -MediaRootPath 'c:\screenshots\' -Language 'fr-fr' -Release '1712' -MediaFallbackLanguage 'en-us'

        Checks to see if c:\screenshots\1712\fr-fr\foo.png exists.  If it does, copies it to $script:tempFolderPath\Assets\fr-fr\foo.png
        and returns 'Assets\fr-fr\foo.png'.  If it doesn't exist, checks to see if c:\screenshots\1712\en-us\foo.png exists.  If it does,
        copies it to $script:tempFolderPath\Assets\en-us\foo.png and returns 'Assets\en-us\foo.png'.  If it doesn't, throws an exception.
#>

    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string] $Filename,

        [Parameter(Mandatory)]
        [string] $MediaRootPath,

        [Parameter(Mandatory)]
        [string] $Language,

        [string] $Release,

        [string] $MediaFallbackLanguage
    )

    # This is the partial path where the media file will be located witin the context of the zip file.
    $fileRelativePackagePath = $null

    # The folder where we think the media file should be found.
    $mediaLanguageSourcePath = [System.IO.Path]::Combine($MediaRootPath, $Release, $Language)

    # The folder where we think the media file should be found if using the fallback language.
    $mediaFallbackLanguageSourcePath = $null
    if (-not [string]::IsNullOrEmpty($MediaFallbackLanguage) -and ($MediaFallbackLanguage -ne $Language))
    {
        $mediaFallbackLanguageSourcePath = [System.IO.Path]::Combine($MediaRootPath, $Release, $MediaFallbackLanguage)
        if (-not (Test-Path -Path $mediaFallbackLanguageSourcePath -PathType Container -ErrorAction Ignore))
        {
            Write-Log -Message "A fallback language was specified [$MediaFallbackLanguage], but a folder for that language does not exist [$mediaFallbackLanguageSourcePath], so media fallback support has been disabled." -Level Warning
            $mediaFallbackLanguageSourcePath = $null
        }
    }

    if (Test-Path -Path $mediaLanguageSourcePath -PathType Container -ErrorAction Ignore)
    {
        $image = Get-ChildItem -Recurse -File -Path $mediaLanguageSourcePath -Include $Filename
        $fileRelativePackagePath = [System.IO.Path]::Combine($script:packageImageFolderName, $Language, $Filename)
    }

    if (($null -eq $image) -and ($null -ne $mediaFallbackLanguageSourcePath))
    {
        Write-Log -Message "[$Language] version of $Filename not found.  Using fallback language [$MediaFallbackLanguage] version." -Level Verbose
        $image = Get-ChildItem -Recurse -File -Path $mediaFallbackLanguageSourcePath -Include $Filename
        $fileRelativePackagePath = [System.IO.Path]::Combine($script:packageImageFolderName, $MediaFallbackLanguage, $Filename)
    }

    if ($null -eq $image)
    {
        $output = "Could not find media file [$Filename] in any subdirectory of [$mediaLanguageSourcePath]."
        if ($null -ne $mediaFallbackLanguageSourcePath)
        {
            $output += " Media file also not found in fallback language location [$mediaFallbackLanguageSourcePath]"
        }

        Write-Log -Message $output -Level Error
        throw $output
    }

    if ($image.Count -gt 1)
    {
        $output = "More then one version of [$Filename] has been found for this language. Please ensure only one copy of this media file exists within the language's sub-folders: [$($image.FullName -join ', ')]"
        Write-Log -Message $output -Level Error
        throw $output
    }

    $fileFullPackagePath = Join-Path -Path $script:tempFolderPath -ChildPath $fileRelativePackagePath
    if (-not (Test-Path -PathType Leaf $fileFullPackagePath -ErrorAction Ignore))
    {
        $packageMediaFullPath = Split-Path -Path $fileFullPackagePath -Parent
        if (-not (Test-Path -PathType Container -Path $packageMediaFullPath -ErrorAction Ignore))
        {
            New-Item -ItemType directory -Path $packageMediaFullPath | Out-Null
        }

        Copy-Item -Path $image.FullName -Destination $fileFullPackagePath
    }

    return $fileRelativePackagePath
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

    .PARAMETER MediaRootPath
        The root path to the directory where this submission's images are located.

    .PARAMETER MediaFallbackLanguage
        Some apps may not localize all of their metadata media (images, trailers, etc..)
        across all languages.  By default, StoreBroker will look in the PDP langcode's subfolder
        within MediaRootPath for that language's media content.  If the requested filename is
        not found, StoreBroker packaging will fail. If you specify a fallback language here
        (e.g. 'en-us'), then if the requested file isn't found in the PDP language's media
        subfolder, StoreBroker will then look into the fallback language's media subfolder for
        the exactly same-named image, and only fail then if it still cannot be found.

    .OUTPUTS
        Hashtable  A hastable with each key being a language and the corresponding value, an object
                   containing localized data for the app (Description, Notes, Screenshot captions, etc.)

    .EXAMPLE
        Convert-ListingsMetadata -PDPRootPath 'C:\PDP\' -PDPInclude 'ProductDescription.xml' -MediaRootPath 'C:\AppImages'

        Assumes the folder structure:
        C:\PDP\language1\...\ProductDescription.xml
        C:\PDP\language2\...\ProductDescription.xml
#>
    [CmdletBinding()]
    [OutputType([Hashtable])]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({
            if (Test-Path -PathType Container -Path $_ -ErrorAction Ignore) { $true }
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
        [ValidateScript( {
            if (Test-Path -PathType Container -Path $_ -ErrorAction Ignore) { $true }
            else { throw "'$_' is not a directory or cannot be found." } })]
        [string] $MediaRootPath,

        [string] $MediaFallbackLanguage
    )

    $listings = @{}

    Write-Log -Message "Converting application listings metadata." -Level Verbose

    (Get-ChildItem -File $PDPRootPath -Recurse -Include $PDPInclude -Exclude $PDPExclude).FullName |
        Convert-ListingToObject -PDPRootPath $PDPRootPath -LanguageExclude $LanguageExclude -MediaRootPath $MediaRootPath -MediaFallbackLanguage $MediaFallbackLanguage |
        ForEach-Object { $listings[$_."lang"] = $_."listing" }

    Write-Log -Message "Conversion complete." -Level Verbose

    return $listings
}

function Convert-TrailersMetadata
{
<#
    .SYNOPSIS
        Top-level function for consuming localized metadata about the application's trailers.
        Each language's .xml file, in a subfolder under XmlListingsRootPath, is parsed and
        added to the trailers element within the application's listing metadata.

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

    .PARAMETER MediaRootPath
        The root path to the directory where this submission's images are located.

    .PARAMETER MediaFallbackLanguage
        Some apps may not localize all of their metadata media (images, trailers, etc..)
        across all languages.  By default, StoreBroker will look in the PDP langcode's subfolder
        within MediaRootPath for that language's media content.  If the requested filename is
        not found, StoreBroker packaging will fail. If you specify a fallback language here
        (e.g. 'en-us'), then if the requested file isn't found in the PDP language's media
        subfolder, StoreBroker will then look into the fallback language's media subfolder for
        the exactly same-named image, and only fail then if it still cannot be found.

    .OUTPUTS
        Array   An array of all the trailers and their associated localized content (title, screenshot and description)

    .EXAMPLE
        Convert-TrailersMetadata -PDPRootPath 'C:\PDP\' -PDPInclude 'ProductDescription.xml' -MediaRootPath 'C:\AppImages'

        Assumes the folder structure:
        C:\PDP\language1\...\ProductDescription.xml
        C:\PDP\language2\...\ProductDescription.xml
#>
    [CmdletBinding()]
    [OutputType([Hashtable])]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({
            if (Test-Path -PathType Container -Path $_ -ErrorAction Ignore) { $true }
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
        [ValidateScript( {
            if (Test-Path -PathType Container -Path $_ -ErrorAction Ignore) { $true }
            else { throw "'$_' is not a directory or cannot be found." } })]
        [string] $MediaRootPath,

        [string] $MediaFallbackLanguage
    )

    $trailers = @{}

    Write-Log -Message "Converting application trailers metadata." -Level Verbose

    $dictionaries = (Get-ChildItem -File $PDPRootPath -Recurse -Include $PDPInclude -Exclude $PDPExclude).FullName |
        Convert-TrailersToObject -PDPRootPath $PDPRootPath -LanguageExclude $LanguageExclude -MediaRootPath $MediaRootPath -MediaFallbackLanguage $MediaFallbackLanguage

    # What we just got back is an array of dictionaries, where each dictionary
    # is the trailer data for a single PDP file.  We actually need that merged
    # together into a single dictionary that contains all of the trailer data
    # for the entire set of PDP's that were processed.
    foreach ($dictionary in $dictionaries)
    {
        # ...and then each entry in the dictionary is a different trailer,
        # and its value is another dictionary with a single key (the langcode).
        # The langcode value entry contains the remaining trailer/langcode-specific
        # data (trailer title, screenshot path, screenshot description).
        foreach ($trailer in $dictionary.GetEnumerator())
        {
            $trailerRelativeFilePath = $trailer.Key

            $trailerLangData = $trailer.Value.GetEnumerator() | Select-Object -First 1
            $language = $trailerLangData.Key
            $trailerData = $trailerLangData.Value

            if ($null -eq $trailers[$trailerRelativeFilePath])
            {
                $trailers[$trailerRelativeFilePath] = @{}
            }

            $trailers[$trailerRelativeFilePath][$language] = $trailerData
        }
    }

    # Now that we've normalized the data, we need to convert it into the
    # object format that the JSON schema is expecting (in this case,
    # an array of trailers with multi-nested dictionaries).
    $trailersArray = @()
    foreach ($trailer in $trailers.GetEnumerator())
    {
        # To simplify debugging, we'll ensure that the languages are all sorted
        $trailerAssets = [ordered]@{}
        $trailer.Value.GetEnumerator() |
            Sort-Object -Property Key |
            ForEach-Object { $trailerAssets[$_.Key] = $_.Value }

        $trailersArray += [ordered]@{
            'videoFileName' = $trailer.Key
            'trailerAssets' = $trailerAssets
        }
    }

    Write-Log -Message "Conversion complete." -Level Verbose

    return $trailersArray
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

    .PARAMETER MediaRootPath
        A path to the root path containing the new submission's images.  Currently, an IAP can have
        an optional icon associated with it. Each relative path is appended to MediaRootPath to
        create a full path to the image.

    .PARAMETER XmlFilePath
        A full path to the localized .xml file to be parsed.

    .PARAMETER MediaFallbackLanguage
        Some apps may not localize all of their metadata media (images, trailers, etc..)
        across all languages.  By default, StoreBroker will look in the PDP langcode's subfolder
        within MediaRootPath for that language's media content.  If the requested filename is
        not found, StoreBroker packaging will fail. If you specify a fallback language here
        (e.g. 'en-us'), then if the requested file isn't found in the PDP language's media
        subfolder, StoreBroker will then look into the fallback language's media subfolder for
        the exactly same-named image, and only fail then if it still cannot be found.
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
        [string] $MediaRootPath,

        [Parameter(
            Mandatory,
            ValueFromPipeline)]
        [string[]] $XmlFilePaths,

        [string] $MediaFallbackLanguage
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
                        Write-Log -Message $out -Level Verbose

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

                    # Identify the keys whose values are non-null.
                    # Must be done in two steps because $listing can't be modified
                    # while enumerating its keys.
                    $trimKeys = $listing.Keys |
                        Where-Object { ($null -ne (Get-TextFromXmlElement -Element $listing[$_])) }

                    $trimKeys | ForEach-Object {
                        $listing[$_] = Get-TextFromXmlElement -Element $listing[$_]
                    }

                    # For title specifically, we need to ensure that it's set to $null if there's
                    # no value.  An empty string value is not the same as $null.
                    if ([String]::IsNullOrWhiteSpace($listing['title']))
                    {
                        $listing['title'] = $null
                    }

                    # Handle the icon for the IAP.
                    $imageFileName = $InAppProductDescriptionNode.icon.fileName
                    if (-not [System.String]::IsNullOrWhiteSpace($imageFileName))
                    {

                        # We start with the fallback language specified on an individual asset.
                        # We continue to climb up to find a more generally defined FallbackLanguage
                        # until we hit the ProductDescription node.  If one is still not specified
                        # there, then we'll try using the one specified at the commandline/config file.
                        $requestedFallbackLanguage = (
                            $InAppProductDescriptionNode.icon.FallbackLanguage,
                            $InAppProductDescriptionNode.FallbackLanguage,
                            $MediaFallbackLanguage) |
                                Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                                Select-Object -First 1

                        $params = @{
                            'Filename' = $imageFileName
                            'MediaRootPath' = $MediaRootPath
                            'Language' = $language
                            'Release' = $InAppProductDescriptionNode.Release
                            'MediaFallbackLanguage' = $requestedFallbackLanguage
                        }

                        $fileRelativePackagePath = Get-LocalizedMediaFile @params

                        $iconListing += @{
                            "fileName"     = $fileRelativePackagePath;
                            "fileStatus"   = "PendingUpload";
                        }

                        $listing['icon'] = $iconListing
                    }

                    Write-Output @{ "lang" = $language.ToLowerInvariant(); "listing" = $listing }
                }
                catch [System.InvalidCastException]
                {
                    $output = "Provided .xml file is not a valid .xml document: $xmlFilePath"
                    Write-Log -Message $output -Level Error
                    throw $output
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

    .PARAMETER MediaRootPath
        The root path to the directory where this submission's images are located.

    .PARAMETER MediaFallbackLanguage
        Some apps may not localize all of their metadata media (images, trailers, etc..)
        across all languages.  By default, StoreBroker will look in the PDP langcode's subfolder
        within MediaRootPath for that language's media content.  If the requested filename is
        not found, StoreBroker packaging will fail. If you specify a fallback language here
        (e.g. 'en-us'), then if the requested file isn't found in the PDP language's media
        subfolder, StoreBroker will then look into the fallback language's media subfolder for
        the exactly same-named image, and only fail then if it still cannot be found.

    .OUTPUTS
        Hashtable  A hastable with each key being a language and the corresponding value, an object
                   containing localized data for the app (Title, Description, Icon, etc.)

    .EXAMPLE
        Convert-InAppProductListingsMetadata -PDPRootPath 'C:\PDP\' -PDPInclude 'InAppProductDescription.xml' -MediaRootPath 'C:\IapIcons'

        Assumes the folder structure:
        C:\PDP\language1\...\InAppProductDescription.xml
        C:\PDP\language2\...\InAppProductDescription.xml
#>
    [CmdletBinding()]
    [OutputType([Hashtable])]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({
            if (Test-Path -PathType Container -Path $_ -ErrorAction Ignore) { $true }
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
            if (Test-Path -PathType Container -Path $_ -ErrorAction Ignore) { $true }
            else { throw "'$_' is not a directory or cannot be found." } })]
        [string] $MediaRootPath,

        [string] $MediaFallbackLanguage
    )

    $listings = @{}

    Write-Log -Message "Converting IAP listings metadata." -Level Verbose

    (Get-ChildItem -File $PDPRootPath -Recurse -Include $PDPInclude -Exclude $PDPExclude).FullName |
        Convert-InAppProductListingToObject -PDPRootPath $PDPRootPath -LanguageExclude $LanguageExclude -MediaRootPath $MediaRootPath -MediaFallbackLanguage $MediaFallbackLanguage |
        ForEach-Object { $listings[$_."lang"] = $_."listing" }

    Write-Log -Message "Conversion complete." -Level Verbose

    return $listings
}

function Open-AppPackageContainer
{
<#
    .SYNOPSIS
        Given a path to a .appxbundle, .appxupload, .appx, .msixbundle, .msixupload, or .msix file, unzips that file to a directory
        and returns that directory path.

    .PARAMETER AppPackageContainerPath
        Full path to the .appxbundle, .appxupload, .appx, .msixbundle, .msixupload, or .msix file.

    .OUTPUTS
        System.String.  Full path to the unzipped directory.

    .EXAMPLE
        Open-AppPackageContainer "C:\path\App.appxbundle"

        Unzips contents of App.appxbundle to <env:Temp>\<guid>\App\ and returns that path.

    .EXAMPLE
        Open-AppPackageContainer "C:\path\App.appxupload"

        Same as Example 1 only with a .appxupload file.

    .NOTES
        It is up to the client function to clean the path created by this function.  If it is not
        cleaned, it will be included in the final .zip created by New-SubmissionPackage.
#>
    param(
        [Parameter(Mandatory)]
        [string] $AppPackageContainerPath
    )

    try
    {
        Add-Type -AssemblyName System.IO.Compression.FileSystem

        # .apppackagecontainer can be either .appxbundle, .appxupload, .appx, .msixbundle, .msixupload, or .msix
        # Copy CONTAINER.apppackagecontainer to tempFolderPath\GUID.zip
        $containerZipPathFormat = Join-Path $env:TEMP '{0}.zip'

        do
        {
            $containerZipPath = $containerZipPathFormat -f [System.Guid]::NewGuid()
        }
        while (Test-Path -PathType Leaf -Path $containerZipPath -ErrorAction Ignore)

        Write-Log -Message "Copying (Item: $AppPackageContainerPath) to (Target: $containerZipPath)." -Level Verbose
        Copy-Item -Force -Path $AppPackageContainerPath -Destination $containerZipPath
        Write-Log -Message "Copy complete." -Level Verbose

        # Expand CONTAINER.apppackagecontainer.zip to CONTAINER folder
        $expandedContainerPath = New-TemporaryDirectory

        Write-Log -Message "Unzipping archive (Item: $containerZipPath) to (Target: $expandedContainerPath)." -Level Verbose
        [System.IO.Compression.ZipFile]::ExtractToDirectory($containerZipPath, $expandedContainerPath)
        Write-Log -Message "Unzip complete." -Level Verbose

        return $expandedContainerPath
    }
    catch
    {
        if ((-not [System.String]::IsNullOrEmpty($expandedContainerPath)) -and (Test-Path -Path $expandedContainerPath -ErrorAction Ignore))
        {
            Write-Log -Message "Deleting item: $expandedContainerPath" -Level Verbose
            Remove-Item -Force -Recurse -Path $expandedContainerPath -ErrorAction SilentlyContinue
            Write-Log -Message "Deletion complete." -Level Verbose
        }

        throw
    }
    finally
    {
        if ((-not [System.String]::IsNullOrEmpty($containerZipPath)) -and (Test-Path -Path $containerZipPath -ErrorAction Ignore))
        {
            Write-Log -Message "Deleting item: $containerZipPath" -Level Verbose
            Remove-Item -Force -Recurse -Path $containerZipPath -ErrorAction SilentlyContinue
            Write-Log -Message "Deletion complete." -Level Verbose
        }
    }
}

function Report-UnsupportedFile
{
<#
    .SYNOPSIS
        When we discover an invalid file, raise a new telemetry event.

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
    }
}

function New-ApplicationMetadataTable
{
<#
    .SYNOPSIS
        A simple utility function for creating a consistent metadata hastable.

    .DESCRIPTION
        A simple utility function for creating a consistent metadata hastable.

        The hashtable has keys for
         "version", "architecture", "targetPlatform", "languages",
        "capabilities", "targetDeviceFamilies", "targetDeviceFamiliesEx"
        and "innerPackages"

    .OUTPUTS
        Hashtable    A hashtable with $null values and keys for the properties mentioned
                     in the description.
#>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "", Justification="This doesn't change any system state...just creates a new object.")]
    param()

    $table = @{}
    foreach ($property in $script:applicationMetadataProperties)
    {
        $table[$property] = $null;
    }

    return $table
}

function Get-TargetPlatform
{
<#
    .SYNOPSIS
        Determines the target platform for a given AppxManifest.xml.

    .DESCRIPTION
        Determines the target platform for a given AppxManifest.xml.

        Returns one of "Windows10", "Windows81", "Windows80", "WindowsPhone81", or $null

    .PARAMETER AppPackageManifestPath
        A path to the AppxManifest.xml file to be processed.

    .OUTPUTS
        String    A string identifying the target platform, or $null if it could not be identified.

    .EXAMPLE
        Get-TargetPlatform -AppPackageManifestPath "C:\package\AppxManifest.xml"

        Indentifies the target platform for the given AppxManifest.xml
#>
    param(
        [Parameter(Mandatory)]
        [ValidateScript({
            if (Test-Path -PathType Leaf -Include "AppxManifest.xml" -Path $_ -ErrorAction Ignore) { $true }
            else { throw "$_ cannot be found or is not an AppxManifest.xml." } })]
        [string] $AppPackageManifestPath
    )

    $manifest = [xml] (Get-Content -Path $AppPackageManifestPath -Encoding UTF8)
    $root = $manifest.DocumentElement
    if ($root.xmlns -match "^http://schemas.microsoft.com/appx/manifest/(.*/)?windows10(/.*)?$")
    {
        return "Windows10"
    }

    $minOSVersion = $root.Prerequisites.OSMinVersion
    if ([String]::IsNullOrEmpty($minOSVersion))
    {
        Write-Log -Message "Could not find OSMinVersion in [$AppPackageManifestPath]" -Level Warning
        return $null
    }

    $targetPlatform = "Windows"
    if ($null -ne $root.PhoneIdentity)
    {
        $targetPlatform += "Phone"
    }

    # The Store also supports WindowsPhone70/71/80 but those apps
    # are .xap files which we do not support.
    switch -wildcard ($minOSVersion)
    {
        "6.3.*" { $targetPlatform += "81" }
        "6.2.*" { $targetPlatform += "80" }
        default { return $null }
    }

    return $targetPlatform
}

function Read-AppPackageMetadata
{
<#
    .SYNOPSIS
        Reads various metadata properties about the input .appx or .msix file.

    .DESCRIPTION
        Reads various metadata properties about the input .appx or .msix file.

        The metadata read is "version", "architecture", "targetPlatform", "languages",
        "capabilities", "targetDeviceFamilies", "targetDeviceFamiliesEx"
        and "innerPackages".  Not all of the metadata read is actually passed as
        part of the Store submission; some metadata is used as part of an app flighting
        workflow.

    .PARAMETER AppPackagePath
        A path to the .appx or .msix file to be processed.

    .PARAMETER AppPackageInfo
        If provided, will be updated to maintain information about the app being packaged
        (like AppName and Version) if the information can be determined.

    .OUTPUTS
        Hasthable    A hashtable containing the various metadata values.

    .EXAMPLE
        Read-AppPackageMetadata -AppPackagePath ".\my.appx" -AppPackageInfo ([ref] @())

        Returns a hashtable containing metadata about the .appx file.

    .EXAMPLE
        Read-AppPackageMetadata -AppPackagePath ".\my.msix" -AppPackageInfo ([ref] @())

        Returns a hashtable containing metadata about the .msix file.
#>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({
            if (Test-Path -PathType Leaf -Include ("*.appx", "*.msix") -Path $_ -ErrorAction Ignore) { $true }
            else { throw "$_ cannot be found or is not an .appx nor .msix." } })]
        [string] $AppPackagePath,

        [ref] $AppPackageInfo
    )

    $metadata = New-ApplicationMetadataTable

    try
    {
        $expandedAppPackagePath = Open-AppPackageContainer -AppPackageContainerPath $AppPackagePath

        # Get AppxManifest.xml under the appx or msix root.
        $appPackageManifest = Join-Path -Path $expandedAppPackagePath -ChildPath 'AppxManifest.xml' |
            Get-Item -ErrorAction Ignore |
            Select-Object -ExpandProperty FullName

        if ($null -eq $appPackageManifest)
        {
            Report-UnsupportedFile -Path $AppPackagePath
            throw "`"$AppPackagePath`" is not a proper .appx nor .msix. Could not find an AppxManifest.xml."
        }

        Write-Log -Message "Opening `"$appPackageManifest`"." -Level Verbose
        $manifest = [xml] (Get-Content -Path $appPackageManifest -Encoding UTF8)


        # Processing

        $metadata.version        = $manifest.Package.Identity.Version
        $metadata.architecture   = $manifest.Package.Identity.ProcessorArchitecture
        if ([String]::IsNullOrWhiteSpace($metadata.architecture))
        {
            $metadata.architecture = "neutral"
        }

        $metadata.targetPlatform = Get-TargetPlatform -AppPackageManifestPath $appPackageManifest
        $metadata.name           = $manifest.Package.Identity.Name -creplace '^Microsoft\.', ''

        $metadata.languages = @()
        $metadata.languages += $manifest.Package.Resources.Resource.Language |
            Where-Object { $null -ne $_ } |
            ForEach-Object { $_.ToLower() } |
            Sort-Object -Unique

        $metadata.capabilities = @()
        $metadata.capabilities += $manifest.Package.Capabilities.Capability.Name |
            Where-Object { $null -ne $_ } |
            Sort-Object -Unique

        $metadata.targetDeviceFamiliesEx = @()
        $metadata.targetDeviceFamiliesEx += $manifest.Package.Dependencies.TargetDeviceFamily |
            Where-Object { $null -ne $_.Name } |
            Sort-Object -Property Name -Unique |
            ForEach-Object { [PSCustomObject]@{ 'name' = $_.Name; 'minOSVersion' = $_.MinVersion } }

        $metadata.targetDeviceFamilies = @()
        foreach ($family in $metadata.targetDeviceFamiliesEx)
        {
            $metadata.targetDeviceFamilies += ($script:minVersionFormatString -f $family.Name, $family.minOSVersion)
        }

        # A single .appx or .msix will never have an inner package, but we will still set this property to
        # an empty hashtable so that the value is never $null when translated to JSON
        $metadata.innerPackages = @{}

        # Track the info about this package for later processing.
        $singleAppPackageInfo = @{}
        $singleAppPackageInfo[[StoreBrokerTelemetryProperty]::AppxVersion] = $metadata.version
        $singleAppPackageInfo[[StoreBrokerTelemetryProperty]::AppName] = $metadata.name

        $AppPackageInfo.Value += $singleAppPackageInfo
    }
    finally
    {
        if (-not [String]::IsNullOrWhiteSpace($expandedAppPackagePath))
        {
            Write-Log -Message "Deleting item: $expandedAppPackagePath" -Level Verbose
            Remove-Item -Force -Recurse -Path $expandedAppPackagePath -ErrorAction SilentlyContinue | Out-Null
            Write-Log -Message "Deletion complete." -Level Verbose
        }
    }

    return $metadata
}

function Read-AppPackageUploadMetadata
{
<#
    .SYNOPSIS
        Reads various metadata properties about the input .appxupload or .msixupload.

    .DESCRIPTION
        Reads various metadata properties about the input .appxupload or .msixupload.

        The metadata read is "version", "architecture", "targetPlatform", "languages",
        "capabilities", "targetDeviceFamilies", "targetDeviceFamiliesEx"
        and "innerPackages".  Not all of the metadata read is actually passed as
        part of the Store submission; some metadata is used as part of an app flighting
        workflow.

        As part of processing the .appxupload/.msixupload, the file is opened to read metadata from
        the inner .appx/.msix or .appxbundle/.msixbundle file.  There must be exactly one inner .appx/.msix
        or .appxbundle/.msixbundle.

    .PARAMETER AppPackageUploadPath
        A path to the .appxupload/.msixupload to be processed.

    .PARAMETER AppPackageInfo
        If provided, will be updated to maintain information about the app being packaged
        (like AppName and Version) if the information can be determined.

    .OUTPUTS
        Hasthable    A hashtable containing the various metadata values.

    .EXAMPLE
        Read-AppPackageUploadMetadata -AppPackageUploadPath ".\my.appxupload" -AppPackageInfo ([ref] @())

        Returns a hashtable containing metadata about the inner .appx file.

    .EXAMPLE
        Read-AppPackageUploadMetadata -AppPackageUploadPath ".\my.msixupload" -AppPackageInfo ([ref] @())

        Returns a hashtable containing metadata about the inner .msix file.

    .NOTES
        An .appxupload file is just a .zip containing an .appxsym file and a
        single .appx or .appxbundle.  We only care about the inner .appx or .appxbundle.
#>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({
            if (Test-Path -PathType Leaf -Include ("*.appxupload", "*.msixupload") -Path $_ -ErrorAction Ignore) { $true }
            else { throw "$_ cannot be found or is not an .appxupload nor .msixupload." } })]
        [string] $AppPackageUploadPath,

        [ref] $AppPackageInfo
    )

    try
    {
        $throwFormat = "`"$AppPackageUploadPath`" is not a proper .appxupload nor .msixupload. There must be exactly one {0} inside the file."

        Write-Log -Message "Opening `"$AppPackageUploadPath`"." -Level Verbose
        $expandedContainerPath = Open-AppPackageContainer -AppPackageContainerPath $AppPackageUploadPath

        $appPackageFilePath = (Get-ChildItem -Recurse -Path $expandedContainerPath -Include ("*.appx", "*.msix")).FullName
        if ($null -ne $appPackageFilePath)
        {
            if ($appPackageFilePath.Count -ne 1)
            {
                Report-UnsupportedFile -Path $AppPackageUploadPath

                $out = $throwFormat -f ".appx or .msix"
                Write-Log -Message $out -Level Error
                throw $out
            }
            else
            {
                return Read-AppPackageMetadata -AppPackagePath $appPackageFilePath -AppPackageInfo $AppPackageInfo
            }
        }

        # Could not find an .appx inside. Maybe there is an .appxbundle.
        $appPackageBundleFilePath = (Get-ChildItem -Recurse -Path $expandedContainerPath -Include ("*.appxbundle", "*.msixbundle")).FullName
        if (($null -eq $appPackageBundleFilePath) -or (1 -ne $appPackageBundleFilePath.Count))
        {
            Report-UnsupportedFile -Path $AppPackageUploadPath

            $out = $throwFormat -f ".appx, .appxbundle, .msix, or .msixbundle"
            Write-Log -Message $out -Level Error
            throw $out
        }
        else
        {
            return Read-AppPackageBundleMetadata -AppPackagebundlePath $appPackageBundleFilePath -AppPackageInfo $AppPackageInfo
        }
    }
    finally
    {
        if (-not [String]::IsNullOrWhiteSpace($expandedContainerPath))
        {
            Write-Log -Message "Deleting item: $expandedContainerPath" -Level Verbose
            Remove-Item -Force -Recurse -Path $expandedContainerPath -ErrorAction SilentlyContinue | Out-Null
            Write-Log -Message "Deletion complete." -Level Verbose
        }
    }
}

function Read-AppPackageBundleMetadata
{
<#
    .SYNOPSIS
        Reads various metadata properties about the input .appxbundle or .msixbundle.

    .DESCRIPTION
        Reads various metadata properties about the input .appxbundle or .msixbundle.

        The metadata read is "version", "architecture", "targetPlatform", "languages",
        "capabilities", "targetDeviceFamilies", "targetDeviceFamiliesEx"
        and "innerPackages".  Not all of the metadata read is actually passed as
        part of the Store submission; some metadata is used as part of an app flighting
        workflow.

        As part of processing the .appxbundle/.msixbundle, the file is opened to read metadata from
        the inner .appx/.msix files.

    .PARAMETER AppPackageBundlePath
        A path to the .appxbundle/.msixbundle to be processed.

    .PARAMETER AppPackageInfo
        If provided, will be updated to maintain information about the app being packaged
        (like AppName and Version) if the information can be determined.

    .OUTPUTS
        Hasthable    A hashtable containing the various metadata values.

    .EXAMPLE
        Read-AppPackageBundleMetadata -AppPackageBundlePath ".\my.appxbundle" -AppPackageInfo ([ref] @())

        Returns a hashtable containing metadata about the .appxbundle and .appx files inside
        that bundle.
#>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({
            if (Test-Path -PathType Leaf -Include ("*.appxbundle", "*.msixbundle") -Path $_ -ErrorAction Ignore) { $true }
            else { throw "$_ cannot be found or is not an .appxbundle or .msixbundle." } })]
        [string] $AppPackageBundlePath,

        [ref] $AppPackageInfo
    )

    $metadata = New-ApplicationMetadataTable

    try
    {
        $expandedContainerPath = Open-AppPackageContainer -AppPackageContainerPath $AppPackageBundlePath

        # Get AppxBundleManifest.xml under the AppxMetadata folder.
        $bundleManifestPath = Join-Path -Path $expandedContainerPath -ChildPath 'AppxMetadata\AppxBundleManifest.xml' |
            Get-Item -ErrorAction Ignore |
            Select-Object -ExpandProperty FullName

        if ($null -eq $bundleManifestPath)
        {
            Report-UnsupportedFile -Path $AppPackageBundlePath
            throw "`"$AppPackageBundlePath`" is not a proper .appxbundle nor .msixbundle. Could not find an AppxBundleManifest.xml."
        }

        Write-Log -Message "Opening `"$bundleManifestPath`"." -Level Verbose
        $manifest = [xml] (Get-Content -Path $bundleManifestPath -Encoding UTF8)


        # Processing

        $metadata.version      = $manifest.Bundle.Identity.Version
        $metadata.architecture = "Neutral"  # always 'Neutral' for .appxbundle
        $metadata.name         = $manifest.Bundle.Identity.Name -creplace '^Microsoft\.', ''

        $languages = ($manifest.Bundle.Packages.Package | Where-Object Type -like "resource").Resources.Resource.Language |
            Where-Object { $null -ne $_ } |
            ForEach-Object { $_.ToLower() } |
            Sort-Object -Unique

        $metadata.languages = if ($null -eq $languages) { @() } else { $languages }

        # These properties will be aggregated from the individual .appx files
        $metadata.innerPackages          = @{}
        $metadata.capabilities           = @()
        $metadata.targetDeviceFamilies   = @()
        $metadata.targetDeviceFamiliesEx = @()
        $capabilities                    = @()
        $targetDeviceFamilies            = @()
        $targetDeviceFamiliesEx          = @()

        $applications = ($manifest.Bundle.Packages.ChildNodes | Where-Object Type -like "application").FileName
        foreach ($application in $applications)
        {
            # Usually, the "application" attribute will just be a file that is in the root of the
            # bundle, however sometimes it might be directly referencing a file in a sub-folder.
            # Therefore, we need to split that path apart so that Get-ChildItem can search correctly.
            $searchPath = Join-Path -Path $expandedContainerPath -ChildPath (Split-Path -Path $application -Parent)
            $searchFilename = Split-Path -Path $application -Leaf
            $appPackageFilePath = (Get-ChildItem -Recurse -Path $searchPath -Include $searchFilename).FullName
            Write-Log -Message "Looked for [`"$application`"].  Opening it from [`"$appPackageFilePath`"]." -Indent 2 -Level Verbose
            $appPackageMetadata = Read-AppPackageMetadata -AppPackagePath $appPackageFilePath -AppPackageInfo $AppPackageInfo

            # targetPlatform will always be the values of the last .appx processed.
            $metadata.targetPlatform  = $appPackageMetadata.targetPlatform

            $capabilities            += $appPackageMetadata.capabilities
            $targetDeviceFamilies    += $appPackageMetadata.targetDeviceFamilies
            $targetDeviceFamiliesEx  += $appPackageMetadata.targetDeviceFamiliesEx

            $metadata.innerPackages.$($appPackageMetadata.architecture) = @{
                version                = $appPackageMetadata.version;
                targetDeviceFamiliesEx = $appPackageMetadata.targetDeviceFamiliesEx
                targetDeviceFamilies   = $appPackageMetadata.targetDeviceFamiliesEx | ForEach-Object { $script:minVersionFormatString -f $_.name, $_.minOSVersion }
                languages              = $appPackageMetadata.languages;
                capabilities           = $appPackageMetadata.capabilities;
                targetPlatform         = $appPackageMetadata.targetPlatform;
            }
        }

        # Guarantee uniqueness
        # We use += instead of assignment, in order to guarantee these properties remain Array type.
        #     $m.capabilities = @("foo") | Sort-Object -Unique
        # results in $m.capabilities being a String type instead of Array type.
        $metadata.capabilities           += $capabilities | Sort-Object -Unique
        $metadata.targetDeviceFamilies   += $targetDeviceFamilies | Sort-Object -Unique

        # https://stackoverflow.com/questions/31343752/how-can-you-select-unique-objects-based-on-two-properties-of-an-object-in-powers
        $metadata.targetDeviceFamiliesEx += $targetDeviceFamiliesEx |
            Group-Object -Property name, minOSVersion |
            ForEach-Object { $_.Group | Select-Object -Property name, minOSVersion -First 1 }
    }
    finally
    {
        if (-not [String]::IsNullOrWhiteSpace($expandedContainerPath))
        {
            Write-Log -Message "Deleting item: $expandedContainerPath" -Level Verbose
            Remove-Item -Force -Recurse -Path $expandedContainerPath -ErrorAction SilentlyContinue | Out-Null
            Write-Log -Message "Deletion complete." -Level Verbose
        }
    }

    return $metadata
}

function Get-FormattedFilename
{
<#
    .SYNOPSIS
        Gets the ManifestType_AppName_Version_Architecture formatted filename for the
        specified .appxbundle, .appxupload, .appx, .msixbundle, .msixupload, or .msix.

    .DESCRIPTION
        Gets the ManifestType_AppName_Version_Architecture formatted filename for the
        specified .appxbundle, .appxupload, .appx, .msixbundle, .msixupload, or .msix.

        ManifestType is specified by each .appx/.msix and includes "Desktop", "Mobile", "Universal", "Team".
        AppName is specified in the Identity element of the AppxManifest.xml file.
        Version is specified in the Identity element of the AppxManifest.xml file.
        Architecture is specified in the Identity element of the AppxManifest.xml file.

    .PARAMETER Metadata
        A hashtable with "targetDeviceFamiliesEx", "name", "version", and "architecture".
        If the metadata table corresponds to an .appxbundle or .msixbundle, there will likely be an "innerPackages"
        value with metadata from the inner .appx or .msix files.

    .OUTPUTS
        System.String. The ManifestType_AppName_Version_Architecture string.

    .EXAMPLE
        Get-FormattedFilename @{ name="Maps"; version="2.13.22002.0"; architecture="x86"; targetDeviceFamiliesEx=@(@{ name = "Windows.Desktop"); minOSVersion="1.2.3.0" } }

        Would return something like "Desktop_Maps_2.13.22002.0_x86.appxupload"
#>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateScript(
        {
            $throwFormat = "Invalid metadata table. {0}."
            if ([String]::IsNullOrEmpty($_.name)) { throw ($throwFormat -f "No name") }
            if ([String]::IsNullOrEmpty($_.version)) { throw ($throwFormat -f "No version") }
            if ([String]::IsNullOrEmpty($_.architecture)) { throw ($throwFormat -f "No architecture") }

            return $true
        }
        )]
        [hashtable] $Metadata
    )

    # Categories with several items are joined with a '.' separator
    $architectureTag = $Metadata.architecture
    $version = $Metadata.version
    if ($Metadata.innerPackages.Count -gt 0)
    {
        # For .appxbundle/.msixbundle packages, we will use the architectures from the individual .appx/.msix files.
        # The Keys of the innerPackages object are the supported architectures.
        $architectureTag = ($Metadata.innerPackages.Keys | Sort-Object) -join '.'

        # Grab an arbitrary one and use that version.
        $arch = $Metadata.innerPackages.Keys | Sort-Object | Select-Object -First 1
        $version = $Metadata.innerPackages.$arch.version
    }

    # Simplify 'Windows.Universal' to 'Universal'
    $deviceFamilyCollection = $Metadata.targetDeviceFamiliesEx.Name | ForEach-Object { $_ -replace '^Windows\.', '' }

    $formattedBundleTags = @($Metadata.name, $version, $architectureTag)
    if ($deviceFamilyCollection.Count -gt 0)
    {
        $formattedBundleTags = @(($deviceFamilyCollection | Sort-Object) -join '.') + $formattedBundleTags
    }

    # Categories are joined with a '_' separator
    return $formattedBundleTags -join '_'
}

function Read-ApplicationMetadata
{
<#
    .SYNOPSIS
        Reads metadata used for submission of an .appxbundle, .appxupload, .appx, .msixbundle, .msixupload, or .msix.

    .DESCRIPTION
        Reads metadata used for submission of an .appxbundle, .appxupload, .appx, .msixbundle, .msixupload, or .msix.

        The metadata read is "version", "architecture", "targetPlatform", "languages",
        "capabilities", "targetDeviceFamilies", "targetDeviceFamiliesEx",
        "innerPackages", and "name".  Not all of the metadata read is actually passed as
        part of the Store submission; some metadata is used as part of an app flighting
        workflow.

        After reading the metadata for the input package, this function also creates a
        formatted name for the input package when it is stored in the StoreBroker .zip
        output.

    .PARAMETER AppPackagePath
        The path to the .appxbundle, .appxupload, .appx, .msixbundle, .msixupload, or .msix to process.

    .PARAMETER AppPackageInfo
        If provided, will be updated to maintain information about the app being packaged
        (like AppName and Version) if the information can be determined.

    .EXAMPLE
        Read-ApplicationMetadata -AppPackagePath ".\my.appxbundle" -AppPackageInfo ([ref] @())

        Returns a hashtable containing metadata about the .appxbundle and .appx files inside
        that bundle.

    .EXAMPLE
        Read-ApplicationMetadata -AppPackagePath ".\my.msixbundle" -AppPackageInfo ([ref] @())

        Returns a hashtable containing metadata about the .msixbundle and .msix files inside
        that bundle.

    .OUTPUTS
        Hashtable    A hashtable containing the various metadata that was read.
#>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({
            if (Test-Path -PathType Leaf -Include ($script:extensionsSupportingInspection | ForEach-Object { "*" + $_ }) -Path $_ -ErrorAction Ignore) { $true }
            else { throw "$_ cannot be found or is not a supported extension that supports metadata inspection: $($script:extensionsSupportingInspection -join ", ")." } })]
        [string] $AppPackagePath,

        [ref] $AppPackageInfo
    )

    if ($PSCmdlet.ShouldProcess($AppPackagePath))
    {
        $metadata = $null
        switch -Regex ([System.IO.Path]::GetExtension($AppPackagePath))
        {
            "^\.(appx|msix)bundle$"
            {
                $metadata = Read-AppPackageBundleMetadata -AppPackageBundlePath $AppPackagePath -AppPackageInfo $AppPackageInfo
            }

            "^\.(appx|msix)upload$"
            {
                $metadata = Read-AppPackageUploadMetadata -AppPackageUploadPath $AppPackagePath -AppPackageInfo $AppPackageInfo
            }

            "^\.(appx|msix)$"
            {
                $metadata = Read-AppPackageMetadata -AppPackagePath $AppPackagePath -AppPackageInfo $AppPackageInfo
            }
        }

        $metadata.formattedFileName = Get-FormattedFilename -Metadata $metadata

        return $metadata
    }
}

function Add-AppPackagesMetadata
{
<#
    .SYNOPSIS
        Adds a property to the SubmissionObject with metadata about the
        various .appxbundle, .appxupload, .appx, .msixbundle, .msixupload, or .msix files being submitted.

    .PARAMETER PackagePath
        Array of full paths to the .appxbundle, .appxupload, .appx, .msixbundle, .msixupload, or .msix
        files that will be uploaded as the new submission.

    .PARAMETER SubmissionObject
        A PSCustomObj representing the application submission request body.  This function
        will add a property to this object with metadata about the .appx/.msix files being uploaded.

    .PARAMETER AppPackageInfo
        If provided, will be updated to maintain information about the app being packaged
        (like AppName and Version) if the information can be determined.

    .PARAMETER EnableAutoPackageNameFormatting
        If specified, the packages will be renamed using a consistent naming scheme, which
        embeds the application name, version, as well as targeted platform and architecture.

    .EXAMPLE
        Add-AppPackagesMetadata -PackagePath "C:\App.appxbundle" -SubmissionObject $object

        Adds metadata about "C:\App.appxbundle" to the $object object.

    .EXAMPLE
        $object | Add-AppPackagesMetadata -PackagePath "C:\x86\App_x86.appxbundle"

        Same as Example 1 except the $object object is piped in to the function and the appxbundle
        used is for x86 architecture.
#>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({
            foreach ($path in $_)
            {
                if (-not (Test-Path -PathType Leaf -Include ($script:supportedExtensions | ForEach-Object { "*" + $_ }) -Path $path -ErrorAction Ignore))
                {
                    throw "$path cannot be found or is not a supported extension: $($script:supportedExtensions -join ", ")."
                }
            }

            return $true
        })]
        [string[]] $PackagePath,

        [Parameter(
            Mandatory,
            ValueFromPipeline)]
        [PSCustomObject] $SubmissionObject,

        [ref] $AppPackageInfo,

        [switch] $EnableAutoPackageNameFormatting
    )

    $SubmissionObject | Add-Member -MemberType NoteProperty -Name "applicationPackages" -Value ([System.Array]::CreateInstance([Object], 0))

    foreach ($path in $PackagePath)
    {
        if ($PSCmdlet.ShouldProcess($path))
        {

            Write-Log -Message "Processing [$path]" -Level Verbose

            $appPackageName = Split-Path -Leaf -Path $path

            # We always calculate the formatted name, even if we won't use it, in order to
            # populate $AppxInfo with the additional metadata, but only if the package is
            # one that we can inspect.
            $submissionProperties = @{}
            $packageExtension = [System.IO.Path]::GetExtension($appPackageName)
            if ($packageExtension -in $script:extensionsSupportingInspection)
            {
                $appMetadata =  Read-ApplicationMetadata -AppPackagePath $path -AppPackageInfo $AppPackageInfo
                if ($EnableAutoPackageNameFormatting)
                {
                    $appPackageName = ($appMetadata.formattedFileName + [System.IO.Path]::GetExtension($appPackageName))
                }

                # Finalize the properties to be submitted
                foreach ($property in $script:applicationMetadataProperties)
                {
                    $submissionProperties.$property = $appMetadata.$property
                }
            }

            $submissionProperties.fileName              = $appPackageName
            $submissionProperties.fileStatus            = "PendingUpload"
            $submissionProperties.minimumDirectXVersion = "None"
            $submissionProperties.minimumSystemRam      = "None"

            $appPackageObject = New-Object System.Object | Add-Member -PassThru -NotePropertyMembers $submissionProperties

            if ($script:tempFolderExists)
            {
                $destinationPath = Join-Path -Path $script:tempFolderPath -ChildPath $appPackageName

                Write-Log -Message "Copying (Item: $path) to (Target: $destinationPath)" -Level Verbose
                Copy-Item -Path $path -Destination $destinationPath
                Write-Log -Message "Copy complete." -Level Verbose
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
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "", Justification="Does not cause any change to system state. No value gained from ShouldProcess in this specific instance.")]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject] $SubmissionRequestBody

    )

    # No side-effects.  We'll work off of a copy of the passed-in object
    $requestBody = DeepCopy-Object -InputObject $SubmissionRequestBody

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
        .appx/.msix files being submitted, and some are retrieved from localized metadata.

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

    .PARAMETER MediaRootPath
        Root path to the directory containing release subfolders of images to be packaged.

    .PARAMETER PackagePath
        A list of file paths to be included in the package.

    .PARAMETER AppPackageInfo
        If provided, will be updated to maintain information about the app being packaged
        (like AppName and Version) if the information can be determined.

    .PARAMETER DisableAutoPackageNameFormatting
        By default, the packages will be renamed using a consistent naming scheme, which
        embeds the application name, version, as well as targeted platform and architecture.
        To retain the existing package filenames, specify this switch.

    .PARAMETER MediaFallbackLanguage
        Some apps may not localize all of their metadata media (images, trailers, etc..)
        across all languages.  By default, StoreBroker will look in the PDP langcode's subfolder
        within MediaRootPath for that language's media content.  If the requested filename is
        not found, StoreBroker packaging will fail. If you specify a fallback language here
        (e.g. 'en-us'), then if the requested file isn't found in the PDP language's media
        subfolder, StoreBroker will then look into the fallback language's media subfolder for
        the exactly same-named image, and only fail then if it still cannot be found.

    .OUTPUTS
        PSCustomObject  An object representing the full application submission request.

    .NOTES
        It is expected that at least one path is missing from the map as 'PackagePath'
        is mutually exclusive with the remaining three path types.

    .EXAMPLE
        Get-SubmissionRequestBody "C:\App\Appx.appxupload" (Get-Content $ConfigPath -Encoding UTF8 | ConvertFrom-Json)

        Retrieves the submission request generated using the config file at $ConfigPath and the
        appxupload located at "C:\App\Appx.appxupload".

    .EXAMPLE
        (Get-Content $ConfigPath -Encoding UTF8 | ConvertFrom-Json) | Get-SubmissionRequestBody -PackagePath "C:\Appx_x86.appxbundle", "C:\Appx_arm.appxbundle" -Release MarchRelease

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

        [string] $MediaRootPath,

        [string[]] $PackagePath,

        [ref] $AppPackageInfo,

        [switch] $DisableAutoPackageNameFormatting,

        [string] $MediaFallbackLanguage
    )

    # Add static properties and metadata about packaged binaries.
    $submissionRequestBody = $ConfigObject.appSubmission

    if ($PackagePath.Count -gt 0)
    {
        $submissionRequestBody | Add-AppPackagesMetadata -PackagePath $PackagePath -AppPackageInfo $AppPackageInfo -EnableAutoPackageNameFormatting:(-not $DisableAutoPackageNameFormatting)
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
            if (Test-Path -PathType Container -Path $pathWithRelease -ErrorAction Ignore)
            {
                $listingsPath = $pathWithRelease
            }
            else
            {
                $out = @()
                $out += "'$pathWithRelease' is not a valid directory or cannot be found."
                $out += "Check the values of '$script:s_PDPRootPath' and '$script:s_Release' and try again."

                $newLineOutput = ($out -join [Environment]::NewLine)
                Write-Log -Message $newLineOutput -Level Error
                throw $newLineOutput
            }
        }

        $listingsResources = @{
            $script:s_PDPRootPath = $listingsPath;
            $script:s_PDPInclude = $PDPInclude;
            $script:s_PDPExclude = $PDPExclude;
            $script:s_LanguageExclude = $LanguageExclude;
            $script:s_MediaRootPath = $MediaRootPath;
            $script:s_MediaFallbackLanguage = $MediaFallbackLanguage;
        }

        $submissionRequestBody.listings = Convert-ListingsMetadata @listingsResources

        $submissionRequestBody | Add-Member -MemberType NoteProperty -Name "trailers" -Value (New-Object System.Object)

        # PowerShell will convert an array of a single object back to a single object.
        # We need to force it to stay as an array, since the Trailers node in the JSON
        # is an array of trailers.
        $submissionRequestBody.trailers = @(Convert-TrailersMetadata @listingsResources)
    }

    $submissionRequestBody = Remove-DeprecatedProperties -SubmissionRequestBody $submissionRequestBody

    $submissionRequestBody | Add-Member -Name $script:schemaPropertyName -Value $script:appSchemaVersion -MemberType NoteProperty

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

    .PARAMETER MediaRootPath
        Root path to the directory containing release subfolders of images to be packaged.

    .PARAMETER MediaFallbackLanguage
        Some apps may not localize all of their metadata media (images, trailers, etc..)
        across all languages.  By default, StoreBroker will look in the PDP langcode's subfolder
        within MediaRootPath for that language's media content.  If the requested filename is
        not found, StoreBroker packaging will fail. If you specify a fallback language here
        (e.g. 'en-us'), then if the requested file isn't found in the PDP language's media
        subfolder, StoreBroker will then look into the fallback language's media subfolder for
        the exactly same-named image, and only fail then if it still cannot be found.

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

        [string] $MediaRootPath,

        [string] $MediaFallbackLanguage
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
            if (Test-Path -PathType Container -Path $pathWithRelease -ErrorAction Ignore)
            {
                $listingsPath = $pathWithRelease
            }
            else
            {
                $out = @()
                $out += "'$pathWithRelease' is not a valid directory or cannot be found."
                $out += "Check the values of '$script:s_PDPRootPath' and '$script:s_Release' and try again."

                $newLineOutput = ($out -join [Environment]::NewLine)
                Write-Log -Message $newLineOutput -Level Error
                throw $newLineOutput
            }
        }

        $listingsResources = @{
            $script:s_PDPRootPath = $listingsPath;
            $script:s_PDPInclude = $PDPInclude;
            $script:s_PDPExclude = $PDPExclude;
            $script:s_LanguageExclude = $LanguageExclude;
            $script:s_MediaRootPath = $MediaRootPath;
            $script:s_MediaFallbackLanguage = $MediaFallbackLanguage;
        }

        $submissionRequestBody.listings = Convert-InAppProductListingsMetadata @listingsResources
    }

    $submissionRequestBody | Add-Member -Name $script:schemaPropertyName -Value $script:iapSchemaVersion -MemberType NoteProperty

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
        "MediaRootPath", "MediaFallbackLanguage", "PackagePath", "OutPath", and "OutName",
        each with validated values.

    .EXAMPLE
        Resolve-PackagePaths -ConfigObject (Get-Config $ConfigPath) -ParamMap @{"PackagePath"=$null;"OutPath"=$null;"OutPath"=$null;"Release"=$null}

        Attempts to validate the "PackagePath", "OutPath", "OutName", and "Release" parameters by
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

    # 'PDPRootPath' and 'MediaRootPath' are optional.
    # Check if there is a runtime or config value.
    foreach ($param in $script:s_PDPRootPath, $script:s_MediaRootPath)
    {
        if ([String]::IsNullOrWhiteSpace($ParamMap[$param]))
        {
            $configVal = $ConfigObject.packageParameters.$param
            if (-not [String]::IsNullOrWhiteSpace($configVal))
            {
                $ParamMap[$param] = $configVal
                Write-Log -Message ($fromConfig -f $param, $configVal) -Level Verbose
            }
        }

        # Check if user specified a path but the directory does not exist
        $ParamMap[$param] = $ParamMap[$param] | Where-Object { -not [String]::IsNullOrWhiteSpace($_) }
        if (-not [String]::IsNullOrWhiteSpace($ParamMap[$param]))
        {
            # Resolve path parameters to full paths. Necessary in case a path contains '.' or '..'
            $ParamMap[$param] = Resolve-UnverifiedPath -Path $ParamMap[$param]

            if (-not (Test-Path -PathType Container -Path $ParamMap[$param] -ErrorAction Ignore))
            {
                $out = "$($param): `"$($ParamMap[$param])`" is not a directory or cannot be found."

                Write-Log -Message $out -Level Error
                throw $out
            }
        }
    }

    if (($SkipValidation -inotcontains $script:s_PDPRootPath) -and ($SkipValidation -inotcontains $script:s_MediaRootPath))
    {
        # If either 'PDPRootPath' or 'MediaRootPath' is present, both must be present
        if ((-not [String]::IsNullOrWhiteSpace($ParamMap[$script:s_PDPRootPath])) -xor
            (-not [String]::IsNullOrWhiteSpace($ParamMap[$script:s_MediaRootPath])))
        {
            $out = @()
            $out += "Only one of '$script:s_PDPRootPath' and '$script:s_MediaRootPath' was specified."
            $out += "If one of these parameters is specified, then both must be specified."

            $newLineOutput = ($out -join [Environment]::NewLine)
            Write-Log -Message $newLineOutput -Level Error
            throw $newLineOutput
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
                $output = ($out -f $script:s_OutPath)
                Write-Log -Message $output -Level Error
                throw $output
            }
            else
            {
                $ParamMap[$script:s_OutPath] = $configVal
                Write-Log -Message ($fromConfig -f $script:s_OutPath, $configVal) -Level Verbose
            }
        }

        # Resolve path parameters to full paths. Necessary in case a path contains '.' or '..'
        $ParamMap[$script:s_OutPath] = Resolve-UnverifiedPath -Path $ParamMap[$script:s_OutPath]
    }

    if ($SkipValidation -inotcontains $script:s_OutName)
    {
        # 'OutName' is mandatory.
        if ([System.String]::IsNullOrWhiteSpace($ParamMap[$script:s_OutName]))
        {
            $configVal = $ConfigObject.packageParameters.OutName
            if ([System.String]::IsNullOrWhiteSpace($configVal))
            {
                $output = ($out -f $script:s_OutName)
                Write-Log -Message $output -Level Error
                throw $output
            }
            else
            {
                $ParamMap[$script:s_OutName] = $configVal
                Write-Log -Message ($fromConfig -f $script:s_OutName, $configVal) -Level Verbose
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
            Write-Log -Message ($fromConfig -f $script:s_Release, $configVal) -Level Verbose
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
                Write-Log -Message ($fromConfig -f $param, ($configVal -join ', ')) -Level Verbose
            }
        }

        # Make sure we don't have null/empty strings
        $ParamMap[$param] = $ParamMap[$param] | Where-Object { -not [String]::IsNullOrWhiteSpace($_) }
    }

    # Set 'PDPInclude' default if empty
    if ($ParamMap[$script:s_PDPInclude].Count -eq 0)
    {
        $ParamMap[$script:s_PDPInclude] = @("*.xml")
        Write-Log -Message "`tUsing default value: $script:s_PDPInclude = `"*.xml`"" -Level Verbose
    }

    if ($SkipValidation -inotcontains $script:s_PackagePath)
    {
        # 'PackagePath' is mandatory.
        if ($ParamMap[$script:s_PackagePath].Count -eq 0)
        {
            $packagePaths = @()
            $validExtensions = $script:supportedExtensions | ForEach-Object { "*" + $_ }
            foreach ($path in $ConfigObject.packageParameters.PackagePath)
            {
                if ((Test-Path -PathType Leaf -Include $validExtensions -Path $path) -and ($path -notin $packagePaths))
                {
                    $packagePaths += $path
                }
                elseif ([System.String]::IsNullOrWhiteSpace($env:TFS_DropLocation))
                {
                    $out = @()
                    $out += "`"$path`" is not a file or cannot be found."
                    $out += "See the `"$script:s_PackagePath`" object in the config file."

                    $newLineOutput = ($out -join [Environment]::NewLine)
                    Write-Log -Message $newLineOutput -Level Error
                    throw $newLineOutput
                }
                else
                {
                    $path = Join-Path $env:TFS_DropLocation $path
                    if ((Test-Path -PathType Leaf -Include $validExtensions -Path $path -ErrorAction Ignore) -and ($path -notin $packagePaths))
                    {
                        $packagePaths += $path
                    }
                    elseif (Test-Path -PathType Container -Path $path -ErrorAction Ignore)
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
                        $out += "See the `"$script:s_PackagePath`" object in the config file."

                        $newLineOutput = ($out -join [Environment]::NewLine)
                        Write-Log -Message $newLineOutput -Level Error
                        throw $newLineOutput
                    }
                }
            }

            $ParamMap[$script:s_PackagePath] = $packagePaths
            $quotedVals = $packagePaths | ForEach-Object { "`"$_`"" }
            Write-Log -Message ($fromConfig -f $script:s_PackagePath, ($quotedVals -join ', ')) -Level Verbose
        }

        # Resolve PackagePath to a list of full paths.
        $ParamMap[$script:s_PackagePath] = $ParamMap[$script:s_PackagePath] | ForEach-Object { Resolve-UnverifiedPath -Path $_ }
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
            Write-Log -Message ($fromConfig -f $script:s_DisableAutoPackageNameFormatting, $configVal) -Level Verbose
        }
    }

    # 'MediaFallbackLanguage' is optional.
    # Look for a value but do not fail if none is found.
    if ([String]::IsNullOrWhiteSpace($ParamMap[$script:s_MediaFallbackLanguage]))
    {
        $configVal = $ConfigObject.packageParameters.MediaFallbackLanguage
        if (-not [String]::IsNullOrWhiteSpace($configVal))
        {
            $ParamMap[$script:s_MediaFallbackLanguage] = $configVal
            Write-Log -Message ($fromConfig -f $script:s_MediaFallbackLanguage, $configVal) -Level Verbose
        }
    }

    return $ParamMap
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

        The Git repo for this module can be found here: https://aka.ms/StoreBroker

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

    .PARAMETER Force
        If specified, will overwrite the output files if they already exist.

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
        [ValidateScript({if (Test-Path -Path $_ -PathType Leaf -ErrorAction Ignore) { $true } else { throw "$_ cannot be found." }})]
        [string] $MasterJsonPath,

        [Parameter(Mandatory=$true)]
        [ValidateScript({if (Test-Path -Path $_ -PathType Leaf -ErrorAction Ignore) { $true } else { throw "$_ cannot be found." }})]
        [string] $AdditionalJsonPath,

        [Parameter(Mandatory=$true)]
        [string] $OutJsonPath,

        [switch] $AddPackages,

        [switch] $Force
    )

    # Fix the paths
    $MasterJsonPath = Resolve-UnverifiedPath -Path $MasterJsonPath
    $AdditionalJsonPath = Resolve-UnverifiedPath -Path $AdditionalJsonPath

    # Determine the paths to the zip files for these json files
    $masterZipPath = Join-Path (Split-Path $MasterJsonPath -Parent) "$([System.IO.Path]::GetFileNameWithoutExtension($MasterJsonPath)).zip"
    $additionalZipPath = Join-Path (Split-Path $AdditionalJsonPath -Parent) "$([System.IO.Path]::GetFileNameWithoutExtension($AdditionalJsonPath)).zip"
    $outZipPath = Join-Path (Split-Path $OutJsonPath -Parent) "$([System.IO.Path]::GetFileNameWithoutExtension($OutJsonPath)).zip"

    # It the user isn't using -Force, we need to ensure that the target json/zip files don't already exist.
    if (-not $Force)
    {
        $errorMessage = "[{0}] already exists.  Choose a different name, or specify the -Force switch to overwrite it."

        if (Test-Path -Path $OutJsonPath -PathType Leaf -ErrorAction Ignore)
        {
            $output = $errorMessage -f $OutJsonPath
            Write-Log -Message $output -Level Error
            throw $output
        }

        if (Test-Path -Path $outZipPath -PathType Leaf -ErrorAction Ignore)
        {
            $output = $errorMessage -f $outZipPath
            Write-Log -Message $output -Level Error
            throw $output
        }
    }

    Add-Type -AssemblyName System.IO.Compression.FileSystem

    # Make sure that these zip files actually exist.
    foreach ($zipFile in ($masterZipPath, $additionalZipPath))
    {
        if (-not (Test-Path -Path $zipFile -PathType Leaf -ErrorAction Ignore))
        {
            throw "Could not find [$zipFile].  We expect the .json and .zip to have the same base name."
        }
    }

    # Warn the user if they didn't specify anything to actually get merged in.
    # At the moment, the only switch supported is AddPackages, but this may change over time.
    if (-not $AddPackages)
    {
        Write-Log -Level Warning -Message @(
            "You have not specified any `"modification`" switch for joining the packages.",
            "This means that the new package payload will be identical to the Master [$MasterJsonPath].",
            "If this was not your intention, please read-up on the documentation for this command:",
            "     Get-Help Join-PackagePayload -ShowWindow")
    }

    # Unpack the zips
    # out zip content will be based off of master, so we can just consider master's zip as "out"
    $outUnpackedZipPath = New-TemporaryDirectory
    if ($PSCmdlet.ShouldProcess($masterZipPath, "Unzip"))
    {
        Write-Log -Message "Unzipping archive [$masterZipPath] to [$outUnpackedZipPath]" -Level Verbose
        [System.IO.Compression.ZipFile]::ExtractToDirectory($masterZipPath, $outUnpackedZipPath)
        Write-Log -Message "Unzip complete." -Level Verbose
    }

    $additionalUnpackedZipPath = New-TemporaryDirectory
    if ($PSCmdlet.ShouldProcess($additionalZipPath, "Unzip"))
    {
        Write-Log -Message "Unzipping archive [$additionalZipPath] to [$additionalUnpackedZipPath]" -Level Verbose
        [System.IO.Compression.ZipFile]::ExtractToDirectory($additionalZipPath, $additionalUnpackedZipPath)
        Write-Log -Message "Unzip complete." -Level Verbose
    }

    # out json content will be based off of master, so we can just consider master's json as "out"
    $outJsonContent = (Get-Content -Path $MasterJsonPath -Encoding UTF8) | ConvertFrom-Json
    $additionalJsonContent = (Get-Content -Path $AdditionalJsonPath -Encoding UTF8) | ConvertFrom-Json

    if ($AddPackages)
    {
        # We copy over all package changes from the "AdditionalJson", including package removals,
        # package uploads and specified retention of existing packages.
        Write-Log -Message "Adding applicationPackages from [$AdditionalJsonPath] to [$OutJsonPath]" -Level Verbose
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
                if (Test-Path -Path $destPath -PathType Leaf -ErrorAction Ignore)
                {
                    $output = "A package called [$($package.fileName)] already exists in the Master zip file."
                    Write-Log -Message $output -Level Error
                    throw $output
                }

                $sourcePath = Join-Path $additionalUnpackedZipPath $package.fileName
                Write-Log -Message "Copying [$sourcePath] to [$destPath]" -Level Verbose
                Copy-Item -Path $sourcePath -Destination $destPath
                Write-Log -Message "Copy complete." -Level Verbose
            }
        }
    }

    # Zip up out directory to $outZipPath
    Out-DirectoryToZip -Path $outUnpackedZipPath -Destination $outZipPath

    # Output the merged json
    if ($PSCmdlet.ShouldProcess($OutJsonPath, "Create json"))
    {
        Write-Log -Message "Writing merged JSON file: [$OutJsonPath]." -Level Verbose

        $outJsonContent |
            ConvertTo-Json -Depth $script:jsonConversionDepth -Compress |
            Out-File -Encoding utf8 -FilePath $OutJsonPath

        Write-Log -Message "Write complete." -Level Verbose
    }

    # Clean up the temp directories
    Write-Log -Message "Cleaning up temp directories..." -Level Verbose
    Remove-Item -Path $outUnpackedZipPath -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $additionalUnpackedZipPath -Recurse -Force -ErrorAction SilentlyContinue
    Write-Log -Message "Cleaning up temp directories complete." -Level Verbose
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

        The .appxbundle, .appxupload, and .appx files are given via the [-PackagePath] parameter.

        In the process of creating the JSON, the packaging tool also copies any specified
        images and .appx files to a .zip file.

        The .json and .zip files generated by this tool are given the common name specified by
        the [-OutName] parameter.

        The Git repo for this module can be found here: https://aka.ms/StoreBroker

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

    .PARAMETER MediaRootPath
        Your store screenshots must be placed with this structure:
            <MediaRootPath>\<Release>\<lang-code>\...\img.png

        The 'Release' that will be used is NOT the value specified to StoreBroker,
        it is the 'Release' value found in the corresponding PDP file.

    .PARAMETER PackagePath
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

    .PARAMETER MediaFallbackLanguage
        Some apps may not localize all of their metadata media (images, trailers, etc..)
        across all languages.  By default, StoreBroker will look in the PDP langcode's subfolder
        within MediaRootPath for that language's media content.  If the requested filename is
        not found, StoreBroker packaging will fail. If you specify a fallback language here
        (e.g. 'en-us'), then if the requested file isn't found in the PDP language's media
        subfolder, StoreBroker will then look into the fallback language's media subfolder for
        the exactly same-named image, and only fail then if it still cannot be found.

    .EXAMPLE
        New-SubmissionPackage -ConfigPath 'C:\Config\StoreBrokerConfig.json' -OutPath 'C:\Out\Path\' -OutName 'Upload' -Release MarchRelease -PackagePath 'C:\bin\App.appxbundle'

        This example creates the submission request body and .zip file for the architecture-neutral
        '.appxbundle' located at 'C:\bin\App.appxbundle'.  Two files will be placed under 'C:\Out\Path\',
        'Upload.json' and 'Upload.zip'

    .EXAMPLE
        New-SubmissionPackage -ConfigPath 'C:\Config\StoreBrokerConfig.json' -OutPath 'C:\Out\Path\' -OutName 'Upload' -Release MarchRelease -PackagePath 'C:\bin\App.appxbundle' -Verbose

        This example is the same except it specifies Verbose logging and the function will output a
        detailed report of its actions.

    .EXAMPLE
        New-SubmissionPackage -ConfigPath 'C:\Config\StoreBrokerConfig.json' -OutPath 'C:\Out\Path\' -OutName 'Upload' -Release MarchRelease -PackagePath 'C:\bin\x86\App_x86.appxupload', 'C:\Other\Path\Arm\App_arm.appxupload'

        This example is the same except it specifies an x86 and Arm build.  Multiple files to
        include can be passed to 'PackagePath' by separating with a comma.
#>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({
            if (Test-Path -PathType Leaf -Path $_ -ErrorAction Ignore) { return $true }
            else { throw "ConfigPath is not a file or cannot be found: [$_]." } })]
        [string] $ConfigPath,

        [ValidateScript({
            if (Test-Path -PathType Container -Path $_ -ErrorAction Ignore) { return $true }
            else { throw "PDPRootPath is not a directory or cannot be found: [$_]." } })]
        [string] $PDPRootPath,

        [string] $Release,

        [string[]] $PDPInclude,

        [string[]] $PDPExclude,

        [string[]] $LanguageExclude,

        [ValidateScript({
            if (Test-Path -PathType Container $_ -ErrorAction Ignore) { return $true }
            else { throw "MediaRootPath is not a directory or cannot be found: [$_]." } })]
        [Alias('ImagesRootPath')]
        [string] $MediaRootPath,

        [ValidateScript({
            foreach ($path in $_)
            {
                if (-not (Test-Path -PathType Leaf -Include ($script:supportedExtensions | ForEach-Object { "*" + $_ }) -Path $path -ErrorAction Ignore))
                {
                    throw "$_ cannot be found or is not a supported extension: $($script:supportedExtensions -join ", ")."
                }
            }

            return $true
        })]
        [string[]] $PackagePath,

        [string] $OutPath,

        [string] $OutName,

        [switch] $DisableAutoPackageNameFormatting,

        [string] $MediaFallbackLanguage
    )

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    try
    {
        Add-Type -AssemblyName System.IO.Compression.FileSystem

        # Preamble before printing invocation parameters
        Write-Log -Message "New-SubmissionPackage invoked with parameters:" -Level Verbose
        Write-Log -Message "`t$script:s_ConfigPath = `"$ConfigPath`"" -Level Verbose

        # Check the value of each parameter and add to parameter hashtable if not null.
        # Resolve-PackageParameters will take care of validating the values, we only need
        # to avoid splatting null values as this will generate a runtime exception.
        # Log the value of each parameter.
        $validationSet = $script:s_PDPRootPath, $script:s_Release, $script:s_PDPInclude, $script:s_PDPExclude, $script:s_LanguageExclude, $script:s_MediaRootPath, $script:s_PackagePath, $script:s_OutPath, $script:s_OutName, $script:s_DisableAutoPackageNameFormatting, $script:s_MediaFallbackLanguage
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
                Write-Log -Message "`t$param = $($quotedVals -join ', ')" -Level Verbose
            }
        }

        # Convert the Config.json
        $config = Get-Config -ConfigPath $ConfigPath `
                             -MinSupportedVersion $script:minAppConfigSchemaVersion `
                             -MaxSupportedVersion $script:maxAppConfigSchemaVersion

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
                                   (Test-Path -PathType Container -Path $script:tempFolderPath -ErrorAction Ignore)

        # Get the submission request object
        $resourceParams = $script:s_PDPRootPath, $script:s_Release, $script:s_PDPInclude, $script:s_PDPExclude, $script:s_LanguageExclude, $script:s_MediaRootPath, $script:s_PackagePath, $script:s_DisableAutoPackageNameFormatting, $script:s_MediaFallbackLanguage

        # Note: PSScriptAnalyzer falsely flags this next line as PSUseDeclaredVarsMoreThanAssignment due to:
        # https://github.com/PowerShell/PSScriptAnalyzer/issues/699
        $params = Get-Variable -Name $resourceParams -ErrorAction SilentlyContinue |
                  ForEach-Object { $m = @{} } { $m[$_.Name] = $_.Value } { $m } # foreach begin{} process{} end{}

        $AppPackageInfo = @()
        $submissionBody = Get-SubmissionRequestBody -ConfigObject $config -AppPackageInfo ([ref]$AppPackageInfo) @params

        Write-SubmissionRequestBody -JsonObject $submissionBody -OutFilePath (Join-Path $OutPath ($OutName + '.json'))

        # Zip the contents of the temporary directory. Then delete the temporary directory.
        if ($script:tempFolderExists)
        {
            $zipPath = Join-Path -Path $OutPath -ChildPath ($OutName + '.zip')

            Out-DirectoryToZip -Path $script:tempFolderPath -Destination $zipPath
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

        if (-not [String]::IsNullOrWhiteSpace($global:SBStoreBrokerClientName))
        {
            $telemetryProperties[[StoreBrokerTelemetryProperty]::ClientName] = $global:SBStoreBrokerClientName
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

        if (-not [String]::IsNullOrWhiteSpace($global:SBStoreBrokerClientName))
        {
            $telemetryProperties[[StoreBrokerTelemetryProperty]::ClientName] = $global:SBStoreBrokerClientName
        }

        Set-TelemetryException -Exception $_.Exception -ErrorBucket "New-SubmissionPackage" -Properties $telemetryProperties
        Write-Log -Exception $_ -Level Error

        throw
    }
    finally
    {
        if ($script:tempFolderExists)
        {
            Write-Log -Message "Deleting temporary directory: $script:tempFolderPath" -Level Verbose
            Remove-Item -Force -Recurse $script:tempFolderPath -ErrorAction SilentlyContinue
            Write-Log -Message "Deleting temporary directory complete." -Level Verbose
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

        The Git repo for this module can be found here: https://aka.ms/StoreBroker

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

    .PARAMETER MediaRootPath
        Your icons must be placed with this structure:
            <MediaRootPath>\<Release>\<lang-code>\...\icon.png

        The 'Release' that will be used is NOT the value specified to StoreBroker,
        it is the 'Release' value found in the corresponding PDP file.

    .PARAMETER OutPath
        Full path to a directory where the Packaging Tool can write the .json submission request
        body and .zip package to upload.

    .PARAMETER OutName
        Common name to give to the .json and .zip files outputted by the Packaging Tool.

    .PARAMETER MediaFallbackLanguage
        Some apps may not localize all of their metadata media (images, trailers, etc..)
        across all languages.  By default, StoreBroker will look in the PDP langcode's subfolder
        within MediaRootPath for that language's media content.  If the requested filename is
        not found, StoreBroker packaging will fail. If you specify a fallback language here
        (e.g. 'en-us'), then if the requested file isn't found in the PDP language's media
        subfolder, StoreBroker will then look into the fallback language's media subfolder for
        the exactly same-named image, and only fail then if it still cannot be found.

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
        [ValidateScript({
            if (Test-Path -PathType Leaf -Path $_ -ErrorAction Ignore) { $true }
            else { throw "ConfigPath is not a file or cannot be found: [$_]." } })]
        [string] $ConfigPath,

        [ValidateScript({
            if (Test-Path -PathType Container -Path $_ -ErrorAction Ignore) { return $true }
            else { throw "PDPRootPath is not a directory or cannot be found: [$_]." } })]
        [string] $PDPRootPath,

        [string] $Release,

        [string[]] $PDPInclude,

        [string[]] $PDPExclude,

        [string[]] $LanguageExclude,

        [ValidateScript({
            if (Test-Path -PathType Container $_ -ErrorAction Ignore) { return $true }
            else { throw "MediaRootPath is not a directory or cannot be found: [$_]." } })]
        [Alias('ImagesRootPath')]
        [string] $MediaRootPath,

        [string] $OutPath,

        [string] $OutName,

        [string] $MediaFallbackLanguage
    )

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    try
    {
        Add-Type -AssemblyName System.IO.Compression.FileSystem

        # Preamble before printing invocation parameters
        Write-Log -Message "New-InAppProductSubmissionPackage invoked with parameters:" -Level Verbose
        Write-Log -Message "`t$script:s_ConfigPath = `"$ConfigPath`"" -Level Verbose

        # Check the value of each parameter and add to parameter hashtable if not null.
        # Resolve-PackageParameters will take care of validating the values, we only need
        # to avoid splatting null values as this will generate a runtime exception.
        # Log the value of each parameter.
        $validationSet = $script:s_PDPRootPath, $script:s_Release, $script:s_PDPInclude, $script:s_PDPExclude, $script:s_LanguageExclude, $script:s_MediaRootPath, $script:s_OutPath, $script:s_OutName, $script:s_MediaFallbackLanguage
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
                Write-Log -Message "`t$param = $($quotedVals -join ', ')" -Level Verbose
            }
        }

        # Convert the Config.json
        $config = Get-Config -ConfigPath $ConfigPath `
                             -MinSupportedVersion $script:minIapConfigSchemaVersion `
                             -MaxSupportedVersion $script:maxIapConfigSchemaVersion

        # Check that all parameters are provided or specified in the config
        $validatedParams = Resolve-PackageParameters -ConfigObject $config -ParamMap $packageParams -SkipValidation @($script:s_DisableAutoPackageNameFormatting, $script:s_PackagePath)

        # Assign final, validated params
        $validationSet |
            Where-Object { $null -ne $validatedParams[$_] } |
            ForEach-Object { Set-Variable -Name $_ -Value $validatedParams[$_] -ErrorAction SilentlyContinue }

        # Create a temp directory to work in
        $script:tempFolderPath = New-TemporaryDirectory

        # It may not actually exist due to What-If support.
        $script:tempFolderExists = (-not [System.String]::IsNullOrEmpty($script:tempFolderPath)) -and
                                   (Test-Path -PathType Container -Path $script:tempFolderPath -ErrorAction Ignore)

        # Get the submission request object
        $resourceParams = $script:s_PDPRootPath, $script:s_Release, $script:s_PDPInclude, $script:s_PDPExclude, $script:s_LanguageExclude, $script:s_MediaRootPath, $script:s_MediaFallbackLanguage

        # Note: PSScriptAnalyzer falsely flags this next line as PSUseDeclaredVarsMoreThanAssignment due to:
        # https://github.com/PowerShell/PSScriptAnalyzer/issues/699
        $params = Get-Variable -Name $resourceParams -ErrorAction SilentlyContinue |
                  ForEach-Object { $m = @{} } { $m[$_.Name] = $_.Value } { $m } # foreach begin{} process{} end{}

        $submissionBody = Get-InAppProductSubmissionRequestBody -ConfigObject $config @params

        Write-SubmissionRequestBody -JsonObject $submissionBody -OutFilePath (Join-Path -Path $OutPath -ChildPath ($OutName + '.json'))

        # Zip the contents of the temporary directory.  Then delete the temporary directory.
        if ($script:tempFolderExists)
        {
            $zipPath = Join-Path -Path $OutPath -ChildPath ($OutName + '.zip')

            Out-DirectoryToZip -Path $script:tempFolderPath -Destination $zipPath
        }

        # Record the telemetry for this event.
        $stopwatch.Stop()
        $telemetryMetrics = @{ [StoreBrokerTelemetryMetric]::Duration = $stopwatch.Elapsed.TotalSeconds }

        Set-TelemetryEvent -EventName New-InAppProductSubmissionPackage -Metrics $telemetryMetrics
    }
    catch
    {
        Set-TelemetryException -Exception $_.Exception -ErrorBucket "New-InAppProductSubmissionPackage"
        Write-Log -Exception $_ -Level Error

        throw
    }
    finally
    {
        if ($script:tempFolderExists)
        {
            Write-Log -Message "Deleting temporary directory: $script:tempFolderPath" -Level Verbose
            Remove-Item -Force -Recurse $script:tempFolderPath -ErrorAction SilentlyContinue
            Write-Log -Message "Deleting temporary directory complete." -Level Verbose
        }
    }
}
