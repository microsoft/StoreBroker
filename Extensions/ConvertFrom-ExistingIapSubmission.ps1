# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

<#
    .SYNOPSIS
        Script for converting an existing In-AppProduct (IAP) submission in the Store
        to the January 2017 PDP schema.

    .DESCRIPTION
        Script for converting an existing In-AppProduct (IAP) submission in the Store
        to the January 2017 PDP schema.

        The Git-repo for the StoreBroker module can be found here: http://aka.ms/StoreBroker

    .PARAMETER IapId
        The ID of the IAP that the PDP's will be getting created for.
        The most recent submission for this IAP will be used unless a SubmissionId is
        explicitly specified.

    .PARAMETER SubmissionId
        The ID of the application submission that the PDP's will be getting created for.
        The most recent submission for IapId will be used unless a value for this parameter is
        provided.

    .PARAMETER SubmissionId
        The submission object that you want to convert, which was previously retrieved.

    .PARAMETER Release
        The release to use.  This value will be placed in each new PDP and used in conjunction with '-OutPath'.
        Some examples could be "1601" for a January 2016 release, "March 2016", or even just "1".

    .PARAMETER PdpFileName
        The name of the PDP file that will be generated for each region.

    .PARAMETER OutPath
        The output directory.
        This script will create two subfolders of OutPath:
           <OutPath>\PDPs\<Release>\
           <OutPath>\Images\<Release>\
        Each of these sub-folders will have region-specific subfolders for their file content.

    .EXAMPLE
        .\ConvertFrom-ExistingIapSubmission -IapId 0ABCDEF12345 -Release "March Release" -OutPath "C:\NewPDPs"

        Converts the data from the last published submission for IapId 0ABCDEF12345.  The generated files
        will use the default name of "PDP.xml" and be located in lang-code specific sub-directories within
        c:\NewPDPs.

    .EXAMPLE
        .\ConvertFrom-ExistingIapSubmission -IapId 0ABCDEF12345 -SubmissionId 1234567890123456789 -Release "March Release" -PdpFileName "InAppProductDescription.xml" -OutPath "C:\NewPDPs"

        Converts the data from submission 1234567890123456789 for IapId 0ABCDEF12345 (which might be a
        published or pending submission).  The generated files will be named "InAppProductDescription.xml" and
        will be located in lang-code specific sub-directories within c:\NewPDPs.

    .EXAMPLE
        .\ConvertFrom-ExistingIapSubmission -Submission $sub -Release "March Release" -OutPath "C:\NewPDPs"

        Converts the data from a submission object that was captured earlier in your PowerShell session.
        It might have come from Get-InAppProductSubmission, or it might have been generated some other way.
        This method of running the script was created more for debugging purposes, but others may find it
        useful. The generated files will use the default name of "PDP.xml" and be located in lang-code
        specific sub-directories within c:\NewPDPs.
#>
[CmdletBinding(
    SupportsShouldProcess,
    DefaultParametersetName = "UseApi")]
param(
    [Parameter(
        Mandatory,
        ParameterSetName = "UseApi",
        Position = 0)]
    [string] $IapId,

    [Parameter(
        ParameterSetName = "UseApi",
        Position = 1)]
    [string] $SubmissionId = $null,

    [Parameter(
        Mandatory,
        ParameterSetName = "ProvideSubmission",
        Position = 0)]
    [PSCustomObject] $Submission = $null,

    [Parameter(Mandatory)]
    [string] $Release,

    [string] $PdpFileName = "PDP.xml",

    [Parameter(Mandatory)]
    [string] $OutPath
)

# Import Write-Log
$rootDir = Split-Path -Path $PSScriptRoot -Parent
$helpers = "$rootDir\StoreBroker\Helpers.ps1"
if (-not (Test-Path -Path $helpers -PathType Leaf))
{
    throw "Script execution requires Helpers.ps1 which is part of the git repo.  Please execute this script from within your cloned repo."
}
. $helpers

#region Comment Constants
$script:LocIdAttribute = "_locID"
$script:LocIdFormat = "Iap_{0}"
$script:CommentFormat = " _locComment_text=`"{{MaxLength={0}}} {1}`" "
#endregion Comment Constants

function Add-ToElement
{
<#
    .SYNOPSIS
        Adds an arbitrary number of comments and attributes to an XmlElement.

    .PARAMETER Element
        The XmlElement to be modified.

    .PARAMETER Comment
        An array of comments to add to the element.

    .PARAMETER Attribute
        A hashtable where the keys are the attribute names and the values are the attribute values.

    .NOTES
        If a provided attribute already exists on the Element, the Element will NOT be modified.
        It will ONLY be modified if the Element does not have that attribute.

    .EXAMPLE
        PS C:\>$xml = [xml] (Get-Content $filePath)
        PS C:\>$root = $xml.DocumentElement
        PS C:\>Add-ToElement -Element $root -Comment "Comment1", "Comment2" -Attribute @{ "Attrib1"="Val1"; "Attrib2"="Val2" }

        Adds two comments and two attributes to the root element of the XML document.

#>
    param(
        [Parameter(Mandatory)]
        [System.Xml.XmlElement] $Element,

        [string[]] $Comment,

        [hashtable] $Attribute
    )

    if ($Comment.Count -gt 1)
    {
        # Reverse 'Comment' array in order to preserve order because of nature of 'Prepend'
        # Input array is modified in place, no need to capture result
        [Array]::Reverse($Comment)
    }

    foreach ($text in $Comment)
    {
        if (-not [String]::IsNullOrWhiteSpace($text))
        {
            $elem = $Element.OwnerDocument.CreateComment($text)
            $Element.PrependChild($elem) | Out-Null
        }
    }

    foreach ($key in $Attribute.Keys)
    {
        if ($null -eq $Element.$key)
        {
            $Element.SetAttribute($key, $Attribute[$key])
        }
        else
        {
            $out = "For element $($Element.LocalName), did not create attribute '$key' with value '$($Attribute[$key])' because the attribute already exists."
            Write-Log -Message $out -Level Warning
        }
    }
}

function Ensure-RootChild
{
<#
    .SYNOPSIS
        Creates the specified element as a child of the XML root node, only if that element does not exist already.

    .PARAMETER Xml
        The XmlDocument to (potentially) modify.

    .PARAMETER Element
        The name of the element to existence check.

    .OUTPUTS
        XmlElement. Returns a reference to the (possibly newly created) element requested.

    .EXAMPLE
        PS C:\>$xml = [xml] (Get-Content $filePath)
        PS C:\>Ensure-RootChild -Xml $xml -Element "SomeElement"

        $xml.DocumentElement.SomeElement now exists and is an XmlElement object.
#>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseApprovedVerbs", "", Justification="Best description for purpose")]
    param(
        [Parameter(Mandatory)]
        [System.Xml.XmlDocument] $Xml,

        [Parameter(Mandatory)]
        [string] $Element
    )

    # ProductDescription node
    $root = $Xml.DocumentElement

    if ($root.GetElementsByTagName($Element).Count -eq 0)
    {
        $elem = $Xml.CreateElement($Element, $Xml.DocumentElement.NamespaceURI)
        $root.AppendChild($elem) | Out-Null
    }

    return $root.GetElementsByTagName($Element)[0]
}

function Add-Title
{
<#
    .SYNOPSIS
        Creates the Title node.

    .PARAMETER Xml
        The XmlDocument to modify.

    .PARAMETER Listing
        The base listing from the submission for a specific Lang.
#>
    param(
        [Parameter(Mandatory)]
        [System.Xml.XmlDocument] $Xml,

        [Parameter(Mandatory)]
        [PSCustomObject] $Listing
    )

    $elementName = "Title"
    $elementNode = Ensure-RootChild -Xml $Xml -Element $elementName
    $elementNode.InnerText = $Listing.title

    # Add comment to parent
    $maxChars = 100
    $paramSet = @{
        "Element" = $elementNode;
        "Attribute" = @{ $script:LocIdAttribute = ($script:LocIdFormat -f $elementName) };
        "Comment" = @(
            " [required] ",
            ($script:CommentFormat -f $maxChars, "IAP $elementName"))
    }

    Add-ToElement @paramSet
}

function Add-Description
{
<#
    .SYNOPSIS
        Creates the description node

    .PARAMETER Xml
        The XmlDocument to modify.

    .PARAMETER Listing
        The base listing from the submission for a specific Lang.
#>
    param(
        [Parameter(Mandatory)]
        [System.Xml.XmlDocument] $Xml,

        [Parameter(Mandatory)]
        [PSCustomObject] $Listing
    )

    $elementName = "Description"
    $elementNode = Ensure-RootChild -Xml $Xml -Element $elementName
    $elementNode.InnerText = $Listing.description

    # Add comment to parent
    $maxChars = 200
    $paramSet = @{
        "Element" = $elementNode;
        "Attribute" = @{ $script:LocIdAttribute = ($script:LocIdFormat -f $elementName) };
        "Comment" = @(
            " [optional] ",
            ($script:CommentFormat -f $maxChars, "IAP $elementName"))
    }

    Add-ToElement @paramSet
}

function Add-Icon
{
<#
    .SYNOPSIS
        Creates the icon node.

    .PARAMETER Xml
        The XmlDocument to modify.

    .PARAMETER Listing
        The base listing from the submission for a specific Lang.

    .OUTPUTS
        [String] The path specified for the icon (if available)

    .NOTES
        This function is implemented a bit differently than the others.
        Icon is an optional element, but if it's specified, the Filename attribute must
        be included with a non-empty value.  This is fine if the Listing has an icon defined,
        but if it doesn't, then we want to include the element, but commented out so that users
        know later what they need to add if they wish to include an icon at some future time.
        We will create/add the icon node the way we do in all other cases so that we have its XML,
        but if we then determine that there is no icon for that listing, we'll convert the element
        to its XML string representation that we can add as a comment, and then remove the actual
        node.
#>
    param(
        [Parameter(Mandatory)]
        [System.Xml.XmlDocument] $Xml,

        [Parameter(Mandatory)]
        [PSCustomObject] $Listing
    )

    # For this element, we want the comment above, rather than inside, the element.
    $comment = $Xml.CreateComment(' [optional] Specifying an icon is optional. If provided, the icon must be a 300 x 300 png file. ')
    $Xml.DocumentElement.AppendChild($comment ) | Out-Null

    $iconFilename = $Listing.icon.fileName

    $elementName = "Icon"
    [System.Xml.XmlElement] $elementNode = Ensure-RootChild -Xml $Xml -Element $elementName

    $paramSet = @{
        "Element" = $elementNode;
        "Attribute" = @{ 'Filename' = $iconFilename };
    }

    Add-ToElement @paramSet

    if ($null -eq $iconFilename)
    {
        # We'll just comment this out for now since it's not being used.
        # We do a tiny bit of extra processing to remove the unnecessary xmlns attribute that
        # is added to the node when we get the OuterXml.
        $iconElementXml = $elementNode.OuterXml -replace 'xmlns="[^"]+"', ""
        $comment = $Xml.CreateComment(" $iconElementXml ")
        $Xml.DocumentElement.RemoveChild($elementNode) | Out-Null
        $Xml.DocumentElement.AppendChild($comment ) | Out-Null
    }

    return $iconFilename
}

function ConvertFrom-Listing
{
<#
    .SYNOPSIS
        Converts a base listing for an existing submission into a PDP file that conforms with
        the January 2017 PDP schema.

    .PARAMETER Listing
        The base listing from the submission for the indicated Lang.

    .PARAMETER Lang
        The language / region code for the PDP (e.g. "en-us")

    .PARAMETER Release
        The release to use.  This value will be placed in each new PDP.
        Some examples could be "1601" for a January 2016 release, "March 2016", or even just "1".

    .PARAMETER PdpRootPath
        The root / base path that all of the language sub-folders will go for the PDP files.

    .PARAMETER FileName
        The name of the PDP file that will be generated.

    .OUTPUTS
        [String[]] Array of image names that the PDP references

    .EXAMPLE
        ConvertFrom-Listing -Listing ($sub.listings."en-us".baseListing) -Lang "en-us" -Release "1701" -PdpRootPath "C:\PDPs\" -FileName "PDP.xml"

        Converts the given "en-us" base listing to the current PDP schema,
        and saves it to "c:\PDPs\en-us\PDP.xml"
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject] $Listing,

        [Parameter(Mandatory)]
        [string] $Lang,

        [Parameter(Mandatory)]
        [string] $Release,

        [Parameter(Mandatory)]
        [string] $PdpRootPath,

        [Parameter(Mandatory)]
        [string] $FileName
    )

    $xml = [xml]([String]::Format('<?xml version="1.0" encoding="utf-8"?>
    <InAppProductDescription language="en-us"
        xmlns="http://schemas.microsoft.com/appx/2012/InAppProductDescription"
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xml:lang="{0}"
        Release="{1}"/>', $Lang, $Release))

    Add-Title -Xml $Xml -Listing $Listing
    Add-Description -Xml $Xml -Listing $Listing
    $icon = Add-Icon -Xml $Xml -Listing $Listing

    $imageNames = @()
    $imageNames += $icon

    # Save XML object to file
    $filePath = Ensure-PdpFilePath -PdpRootPath $PdpRootPath -Lang $Lang -FileName $FileName
    $xml.Save($filePath)

    # Post-process the file to ensure CRLF (sometimes is only LF).
    $content = Get-Content -Encoding UTF8 -Path $filePath
    $content -join [Environment]::NewLine | Out-File -Force -Encoding utf8 -FilePath $filePath

    return $imageNames
}

function Ensure-PdpFilePath
{
<#
    .SYNOPSIS
        Ensures that the containing folder for a PDP file that will be generated exists so that
        it can successfully be written.

    .DESCRIPTION
        Ensures that the containing folder for a PDP file that will be generated exists so that
        it can successfully be written.

    .PARAMETER PdpRootPath
        The root / base path that all of the language sub-folders will go for the PDP files.

    .PARAMETER Lang
        The language / region code for the PDP (e.g. "en-us")

    .PARAMETER FileName
        The name of the PDP file that will be generated.

    .EXAMPLE
        Ensure-PdpFilePath -PdpRootPath "C:\PDPs\" -Lang "en-us" -FileName "PDP.xml"

        Ensures that the path c:\PDPs\en-us\ exists, creating any sub-folder along the way as
        necessary, and then returns the path "c:\PDPs\en-us\PDP.xml"

    .OUTPUTS
        [String] containing the full path to the PDP file.
#>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseApprovedVerbs", "", Justification="Best description for purpose")]
    param(
        [Parameter(Mandatory)]
        [string] $PdpRootPath,

        [string] $Lang,

        [string] $FileName
    )

    $dropFolder = Join-Path -Path $PdpRootPath -ChildPath $Lang
    if (-not (Test-Path -PathType Container -Path $dropFolder))
    {
        New-Item -Force -ItemType Directory -Path $dropFolder | Out-Null
    }

    return (Join-Path -Path $dropFolder -ChildPath $FileName)
}

function Show-ImageFileNames
{
<#
    .SYNOPSIS
        Informs the user what the image filenames are that they need to make available to StoreBroker.

    .DESCRIPTION
        Informs the user what the image filenames are that they need to make available to StoreBroker.

    .PARAMETER LangImageNames
        A hashtable, indexed by langcode, containing an array of image names that the listing
        for that langcode references.

    .PARAMETER Release
        The release name that was added to the PDP files.

    .EXAMPLE
        Show-ImageFileNames -LangImageNames $langImageNames -Release "1701"
#>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "", Justification="The most common scenario is that there will be multiple images, not a singular image.")]
    param(
        [Parameter(Mandatory)]
        [hashtable] $LangImageNames,

        [Parameter(Mandatory)]
        [string] $Release
    )

    # If there are no screenshots, nothing to do here
    if ($LangImageNames.Count -eq 0)
    {
        return
    }

    # If there are no images being used at all, then we can also early return
    $imageCount = 0
    foreach ($lang in $LangImageNames.GetEnumerator())
    {
        $imageCount += $lang.Value.Count
    }

    if ($imageCount.Count -eq 0)
    {
        return
    }

    Write-Log -Message @(
        "You now need to find all of your images and place them here: <ImagesRootPath>\$Release\<langcode>\...",
        "  where <ImagesRootPath> is the path defined in your config file,",
        "  and <langcode> is the same langcode for the directory of the PDP file referencing those images.")

    # Quick analysis to help teams out if they need to do anything special with their PDP's

    $langs = $LangImageNames.Keys | ConvertTo-Array
    $seenImages = $LangImageNames[$langs[0]]
    $imagesDiffer = $false
    for ($i = 1; ($i -lt $langs.Count) -and (-not $imagesDiffer); $i++)
    {
        if (($LangImageNames[$langs[$i]].Count -ne $seenImages.Count))
        {
            $imagesDiffer = $true
            break
        }

        foreach ($image in $LangImageNames[$langs[$i]])
        {
            if ($seenImages -notcontains $image)
            {
                $imagesDiffer = $true
                break
            }
        }
    }

    # Now show the user the image filenames
    if ($imagesDiffer)
    {
        Write-Log -Level Warning -Message @(
            "It appears that you don't have consistent images across all languages.",
            "While StoreBroker supports this scenario, some localization systems may",
            "not support this without additional work.  Please refer to the FAQ in",
            "the documentation for more info on how to best handle this scenario.")

        $output = @()
        $output += "The currently referenced image filenames, per langcode, are as follows:"
        foreach ($langCode in ($LangImageNames.Keys.GetEnumerator() | Sort-Object))
        {
            $output += " * [$langCode]: " + ($LangImageNames.$langCode -join ", ")
        }

        Write-Log -Message $output
    }
    else
    {
        Write-Log -Message @(
            "Every language that has a PDP references the following images:",
            "`t$($seenImages -join `"`n`t`")")
    }
}

# function Main is invoked at the bottom of the file
function Main
{
    [CmdletBinding()]
    param()

    if ($null -eq (Get-Module StoreBroker))
    {
        $message = "The StoreBroker module is not available in this PowerShell session.  Please import the module, authenticate correctly using Set-StoreBrokerAuthentication, and try again."
        throw $message
    }

    $sub = $Submission
    if ($null -eq $sub)
    {
        if ([String]::IsNullOrEmpty($SubmissionId))
        {
            $iap = Get-InAppProduct -IapId $IapId
            $SubmissionId = $iap.lastPublishedInAppProductSubmission.id
            if ([String]::IsNullOrEmpty($SubmissionId))
            {
                $SubmissionId = $iap.pendingInAppProductSubmission.id
                Write-Log -Message "No published submission exists for this In-App Product.  Using the current pending submission." -Level Warning
            }
        }

        $sub = Get-InAppProductSubmission -IapId $IapId -SubmissionId $SubmissionId
    }

    $langImageNames = @{}
    $langs = ($sub.listings | Get-Member -type NoteProperty)
    $pdpsGenerated = 0
    $langs |
        ForEach-Object {
            $lang = $_.Name
            Write-Log -Message "Creating PDP for $lang" -Level Verbose
            Write-Progress -Activity "Generating PDP" -Status $lang -PercentComplete $(($pdpsGenerated / $langs.Count) * 100)
            try
            {
                $imageNames = ConvertFrom-Listing -Listing ($sub.listings.$lang) -Lang $lang -Release $Release -PdpRootPath $OutPath -FileName $PdpFileName
                $langImageNames[$lang] = $imageNames
                $pdpsGenerated++
            }
            catch
            {
                Write-Log -Message "Error creating [$lang] PDP:" -Exception $_ -Level Error
                throw
            }
        }

    if ($pdpsGenerated -gt 0)
    {
        Write-Log -Message "PDP's have been created here: $OutPath"
        Show-ImageFileNames -LangImageNames $langImageNames -Release $Release
    }
    else
    {
        Write-Log -Level Warning -Message @(
            "No PDPs were generated.",
            "Please verify that this existing In-App Product has one or more language listings that this extension can convert,",
            "otherwise you can start fresh using the sample PDP\InAppProductDescription.xml as a starting point.")
    }
}




# Script body
$OutPath = Resolve-UnverifiedPath -Path $OutPath

# function Main invocation
Main
