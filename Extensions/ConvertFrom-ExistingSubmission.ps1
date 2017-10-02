# Copyright (C) Microsoft Corporation.  All rights reserved.

<#
    .SYNOPSIS
        Script for converting an existing submission in the Store to the March 2016 PDP schema.

    .DESCRIPTION
        Script for converting an existing submission in the Store to the March 2016 PDP schema.

        The Git-repo for the StoreBroker module can be found here: http://aka.ms/StoreBroker

    .PARAMETER AppId
        The ID of the application that the PDP's will be getting created for.
        The most recent submission for this application will be used unless a SubmissionId is
        explicitly specified.

    .PARAMETER SubmissionId
        The ID of the application submission that the PDP's will be getting created for.
        The most recent submission for AppId will be used unless a value for this parameter is
        provided.

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
        .\ConvertFrom-ExistingSubmission -AppId 0ABCDEF12345 -Release "March Release" -OutPath "C:\NewPDPs"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $AppId,

    [string] $SubmissionId = $null,

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
$script:LocIdFormat = "App_{0}"
$script:CommentFormat = " _locComment_text=`"{{MaxLength={0}}} {1}`" "

# Used by child nodes, will be formatted, appended with "{0}`"", and then formatted again.
# Because of formatting twice, need to quadruple normal curly-braces.
$script:CommentFormatN = " _locComment_text=`"{{{{MaxLength={0}}}}} {1} "
$script:CommentFormatNClose = "{0}`" "

# Used by parant nodes to describe the type/quantity of children.
$script:SectionCommentFormat = " Valid length: {0} character limit, up to {1} elements "
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
            Write-Log $out -Level Warning
        }
    }
}

function Add-ToChildren
{
<#
    .SYNOPSIS
        Adds comments and attributes to every child of the Parent element.

    .DESCRIPTION
        Adds comments and attributes to every child of the Parent element.

        Each comment and attribute is applied to each child.

        Comments and attribute values may use a format item, eg "{0}",
        but only the "0" index is valid.  In other words, any number of "{0}"
        is fine but "{1}", "{2}", etc., is not.  When, the comment/attribute is
        applied, it will be formatted with the index of the child, starting from
        one (this can be changed by the 'CountFrom' parameter).

    .PARAMETER Parent
        The Parent XmlElement.

    .PARAMETER Comment
        An array of comments to add to each child. A comment may have any number of
        "{0}" format items but cannot have "{1}", "{2}", etc.

    .PARAMETER Attribute
        A hashtable where the keys are the attribute names and the values are the attribute values.
        A attribute value may have any number of "{0}" format items but cannot have "{1}", "{2}", etc.

    .PARAMETER ChildNodeType
        Only children of the input type will be modified.  Default is [System.Xml.XmlNodeType]::Element.

    .PARAMETER CountFrom
        The number to start enumerating from when labeling child nodes with an index.
        Default is one (1).

    .EXAMPLE
        PS C:\>$xml = [xml] (Get-Content $filePath)
        PS C:\>$root = $xml.DocumentElement
        PS C:\>Add-ToChildren -Parent $root -Comment "Static comment", "Child number {0}" -Attribute @{ "ID"="{0}" }

        For every child of $root, adds the input comments and attributes. After the function returns, the first child
        would have the new comment "Static comment", the new comment "Child number 1" and the new attribute "ID"="1".
#>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "", Justification="More accurately reflects the likely outcome.")]
    param(
        [Parameter(Mandatory)]
        [System.Xml.XmlElement] $Parent,

        [string[]] $Comment,

        [hashtable] $Attribute,

        [System.Xml.XmlNodeType] $ChildNodeType = [System.Xml.XmlNodeType]::Element,

        [Int32] $CountFrom = 1
    )

    $Parent.ChildNodes |
        Where-Object NodeType -eq $ChildNodeType |
        ForEach-Object {
            $elem = $_

            $comments = @()
            foreach ($text in ($Comment | Where-Object { -not [String]::IsNullOrWhiteSpace($_) }))
            {
                $comments += $text -f $CountFrom
            }

            $attribs = @{}
            foreach ($keyval in ($Attribute.GetEnumerator() | Where-Object { -not [String]::IsNullOrWhiteSpace($_.Value) }))
            {
                $attribs[$keyval.Key] = $keyval.Value -f $CountFrom
            }

            $params = @{ "Element" = $elem }

            if ($comments.Count -gt 0)
            {
                $params["Comment"] = $comments
            }

            if ($attribs.Keys.Count -gt 0)
            {
                $params["Attribute"] = $attribs
            }

            Add-ToElement @params
            $CountFrom++ 
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

function Add-AppStoreName
{
<#
    .SYNOPSIS
        Creates the AppStoreName node.

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

    $elementName = "AppStoreName"
    $elementNode = Ensure-RootChild -Xml $Xml -Element $elementName

    # These comments get added in reverse order.
    $comment = $elementNode.OwnerDocument.CreateComment(" $($Listing.title) ")
    $elementNode.PrependChild($comment) | Out-Null

    $comment = $elementNode.OwnerDocument.CreateComment(' Uncomment this next line if you wish to specify one explicitly instead. ')
    $elementNode.PrependChild($comment) | Out-Null

    $comment = $elementNode.OwnerDocument.CreateComment(' This is optional.  AppStoreName is typically extracted from your package''s AppxManifest DisplayName property. ')
    $elementNode.PrependChild($comment) | Out-Null

    # Add comment to parent
    $maxChars = 200
    $paramSet = @{
        "Element" = $elementNode;
        "Attribute" = @{ $script:LocIdAttribute = $script:LocIdFormat -f $elementName };
        "Comment" = $script:CommentFormat -f $maxChars, "App $elementName";
    }

    Add-ToElement @paramSet
}

function Add-Keywords
{
<#
    .SYNOPSIS
        Creates the keyword nodes

    .PARAMETER Xml
        The XmlDocument to modify.

    .PARAMETER Listing
        The base listing from the submission for a specific Lang.
#>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "", Justification="This is the existing name of the section within the PDP.")]
    param(
        [Parameter(Mandatory)]
        [System.Xml.XmlDocument] $Xml,

        [Parameter(Mandatory)]
        [PSCustomObject] $Listing
    )

    $elementName = "Keywords"
    $elementNode = Ensure-RootChild -Xml $Xml -Element $elementName
    foreach ($keyword in $Listing.keywords)
    {
        $child = $Xml.CreateElement("Keyword", $xml.productDescription.NamespaceURI)
        $child.InnerText = $keyword
        $elementNode.AppendChild($child) | Out-Null
    }

    # Add comment to parent
    $maxChars = 30
    $maxChildren = 7
    $paramSet = @{
        "Element" = $elementNode;
        "Comment" = $script:SectionCommentFormat -f $maxChars, $maxChildren;
    }

    Add-ToElement @paramSet

    # Add comment to children
    $maxChars = 30
    $paramSet = @{
        "Parent" = $elementNode;
        "Attribute" = @{ $script:LocIdAttribute = ($script:LocIdFormat -f "keyword") + "{0}" };
        "Comment" = ($script:CommentFormatN -f $maxChars, "App keyword") + $script:CommentFormatNClose;
    }

    Add-ToChildren @paramSet
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
    $maxChars = 10000
    $paramSet = @{
        "Element" = $elementNode;
        "Attribute" = @{ $script:LocIdAttribute = $script:LocIdFormat -f $elementName };
        "Comment" = $script:CommentFormat -f $maxChars, "App $elementName";
    }

    Add-ToElement @paramSet
}

function Add-ReleaseNotes
{
<#
    .SYNOPSIS
        Creates the release notes node

    .PARAMETER Xml
        The XmlDocument to modify.

    .PARAMETER Listing
        The base listing from the submission for a specific Lang.
#>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "", Justification="This is the existing name of the section within the PDP.")]
    param(
        [Parameter(Mandatory)]
        [System.Xml.XmlDocument] $Xml,

        [Parameter(Mandatory)]
        [PSCustomObject] $Listing
    )

    $elementName = "ReleaseNotes"
    $elementNode = Ensure-RootChild -Xml $Xml -Element $elementName
    $elementNode.InnerText = $Listing.releaseNotes

    # Add comment to parent
    $maxChars = 1500
    $paramSet = @{
        "Element" = $elementNode;
        "Attribute" = @{ $script:LocIdAttribute = $script:LocIdFormat -f $elementName };
        "Comment" = $script:CommentFormat -f $maxChars, "App Release Note";
    }

    Add-ToElement @paramSet
}

function Add-ScreenshotCaptions
{
<#
    .SYNOPSIS
        Creates the caption nodes and associates the related images as attributes to those captions.

    .PARAMETER Xml
        The XmlDocument to modify.

    .PARAMETER Listing
        The base listing from the submission for a specific Lang.

    .OUTPUTS
        [String[]] Array of image names that the captions reference
#>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "", Justification="This is the existing name of the section within the PDP.")]
    param(
        [Parameter(Mandatory)]
        [System.Xml.XmlDocument] $Xml,

        [Parameter(Mandatory)]
        [PSCustomObject] $Listing
    )

    $imageNames = @()

    $imageAttributeMap = @{
        "Screenshot" = "DesktopImage"
        "MobileScreenshot" = "MobileImage"
        "XboxScreenshot" = "XboxImage"
        "SurfaceHubScreenshot" = "SurfaceHubImage"
        "HoloLensScreenshot" = "HoloLensImage"
    }

    # Group the images together by captions (so that we only have one caption element for the
    # same caption text)
    $captionImageMap = [ordered]@{}
    $noCaptionImages = @()
    $Listing.images |
        ForEach-Object {
            $imageType = $_.imageType
            $fileName = Split-Path -Path ($_.fileName) -Leaf
            $description = $_.description
            if (-not $imageAttributeMap.Contains($imageType))
            {
                Write-Warning "Image [$fileName] of type [$imageType] defined for [$Lang] listing, but is not supported by PDP converter. Skipping adding of the image to PDP."
                return # acts like a "continue" in a ForEach-Object
            }

            if ([String]::IsNullOrEmpty($description))
            {
                $noCaptionImages += @{ $imageType = $fileName }
                return
            }

            if ($null -eq $captionImageMap[$description])
            {
                $captionImageMap[$description] = @{}
            }
                        
            ($captionImageMap[$description])[$imageType] = $fileName
        }

    # Create ScreenshotCaptions node if it does not exist
    $elementName = "ScreenshotCaptions"
    $elementNode = Ensure-RootChild -Xml $Xml -Element $elementName

    # Now, we'll create a new caption node for each known unique caption, setting an attribute
    # for any imagetype that has a screenshot using that caption
    foreach ($caption in $captionImageMap.Keys)
    {
        $child = $Xml.CreateElement("Caption", $xml.productDescription.NamespaceURI)
        $child.InnerText = $caption

        foreach ($screenshotType in $captionImageMap.$caption.Keys)
        {
            $imageName = $captionImageMap.$caption[$screenshotType]
            $child.SetAttribute($imageAttributeMap[$screenshotType], $imageName)
            $imageNames += $imageName
        }

        $elementNode.AppendChild($child) | Out-Null
    }

    # Now we'll create new caption nodes for images that had no captions
    foreach ($image in $noCaptionImages)
    {
        $child = $Xml.CreateElement("Caption", $xml.productDescription.NamespaceURI)
        $imageName = $image.Values[0]
        $child.SetAttribute($imageAttributeMap[$image.Keys[0]], $imageName)
        $elementNode.AppendChild($child) | Out-Null
        $imageNames += $imageName
    }

    # Add comments to parent
    $paramSets = @()
    $paramSets += @{
        "Element" = $elementNode;
        "Comment" = " Valid attributes: any of DesktopImage, MobileImage, XboxImage, SurfaceHubImage, and HoloLensImage "
    }

    $maxChars = 200
    $maxChildren = 9
    $paramSets += @{
        "Element" = $elementNode;
        "Comment" = "${script:SectionCommentFormat}per platform "-f $maxChars, $maxChildren;
    }

    foreach ($paramSet in $paramSets)
    {
        Add-ToElement @paramSet
    }

    # Add comment to children
    $maxChars = 200
    $paramSet = @{
        "Parent" = $elementNode;
        "Attribute" = @{ $script:LocIdAttribute = ($script:LocIdFormat -f "caption") + "{0}" };
        "Comment" = ($script:CommentFormatN -f $maxChars, "Screenshot caption") + $script:CommentFormatNClose;
    }

    Add-ToChildren @paramSet

    return $imageNames
}

function Add-AppFeatures
{
<#
    .SYNOPSIS
        Creates the app features nodes

    .PARAMETER Xml
        The XmlDocument to modify.

    .PARAMETER Listing
        The base listing from the submission for a specific Lang.
#>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "", Justification="This is the existing name of the section within the PDP.")]
    param(
        [Parameter(Mandatory)]
        [System.Xml.XmlDocument] $Xml,

        [Parameter(Mandatory)]
        [PSCustomObject] $Listing
    )

    $elementName = "AppFeatures"
    $elementNode = Ensure-RootChild -Xml $Xml -Element $elementName
    foreach ($feature in $Listing.features)
    {
        $child = $Xml.CreateElement("AppFeature", $xml.productDescription.NamespaceURI)
        $child.InnerText = $feature
        $elementNode.AppendChild($child) | Out-Null
    }

    # Add comment to parent
    $maxChars = 200
    $maxChildren = 20
    $paramSet = @{
        "Element" = $elementNode;
        "Comment" = $script:SectionCommentFormat -f $maxChars, $maxChildren;
    }

    Add-ToElement @paramSet

    # Add comment to children
    $maxChars = 200
    $paramSet = @{
        "Parent" = $elementNode;
        "Attribute" = @{ $script:LocIdAttribute = ($script:LocIdFormat -f "feature") + "{0}" };
        "Comment" = ($script:CommentFormatN -f $maxChars, "App Feature") + $script:CommentFormatNClose;
    }

    Add-ToChildren @paramSet
}

function Add-RecommendedHardware
{
<#
    .SYNOPSIS
        Creates the recommended hardware nodes

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

    $elementName = "RecommendedHardware"
    $elementNode = Ensure-RootChild -Xml $Xml -Element $elementName
    foreach ($recommendation in $Listing.recommendedHardware)
    {
        $child = $Xml.CreateElement("Recommendation", $xml.productDescription.NamespaceURI)
        $child.InnerText = $recommendation
        $elementNode.AppendChild($child) | Out-Null
    }

    # Add comment to parent
    $maxChars = 200
    $maxChildren = 11
    $paramSet = @{
        "Element" = $elementNode;
        "Comment" = $script:SectionCommentFormat -f $maxChars, $maxChildren;
    }

    Add-ToElement @paramSet

    # Add comment to children
    $maxChars = 200
    $paramSet = @{
        "Parent" = $elementNode;
        "Attribute" = @{ $script:LocIdAttribute = ($script:LocIdFormat -f "RecommendedHW") + "{0}" };
        "Comment" = ($script:CommentFormatN -f $maxChars, "App Recommended Hardware") + $script:CommentFormatNClose;
    }

    Add-ToChildren @paramSet
}

function Add-CopyrightAndTrademark
{
<#
    .SYNOPSIS
        Creates the CopyrightAndTrademark node

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

    $elementName = "CopyrightAndTrademark"
    $elementNode = Ensure-RootChild -Xml $Xml -Element $elementName
    $elementNode.InnerText = $Listing.copyrightAndTrademarkInfo

    # Add comment to parent
    $maxChars = 200
    $paramSet = @{
        "Element" = $elementNode;
        "Attribute" = @{ $script:LocIdAttribute = $script:LocIdFormat -f "CopyrightandTrademark" };
        "Comment" = $script:CommentFormat -f $maxChars, "Copyright and Trademark";
    }

    Add-ToElement @paramSet
}

function Add-AdditionalLicenseTerms
{
<#
    .SYNOPSIS
        Creates the AdditionalLicenseTerms node

    .PARAMETER Xml
        The XmlDocument to modify.

    .PARAMETER Listing
        The base listing from the submission for a specific Lang.
#>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "", Justification="This is the existing name of the section within the PDP.")]
    param(
        [Parameter(Mandatory)]
        [System.Xml.XmlDocument] $Xml,

        [Parameter(Mandatory)]
        [PSCustomObject] $Listing
    )

    $elementName = "AdditionalLicenseTerms"
    $elementNode = Ensure-RootChild -Xml $Xml -Element $elementName
    $elementNode.InnerText = $Listing.licenseTerms

    # Add comment to parent
    $maxChars = 10000
    $paramSet = @{
        "Element" = $elementNode;
        "Attribute" = @{ $script:LocIdAttribute = $script:LocIdFormat -f $elementName };
        "Comment" = $script:CommentFormat -f $maxChars, "Additional License Terms";
    }

    Add-ToElement @paramSet
}

function Add-WebsiteUrl
{
<#
    .SYNOPSIS
        Creates the WebsiteURL node

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

    $elementName = "WebsiteURL"
    $elementNode = Ensure-RootChild -Xml $Xml -Element $elementName
    $elementNode.InnerText = $Listing.websiteUrl

    # Add comment to parent
    $maxChars = 2048
    $paramSet = @{
        "Element" = $elementNode;
        "Attribute" = @{ $script:LocIdAttribute = $script:LocIdFormat -f $elementName };
        "Comment" = $script:CommentFormat -f $maxChars, $elementName;
    }

    Add-ToElement @paramSet
}

function Add-SupportContact
{
<#
    .SYNOPSIS
        Creates the SupportContact node

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

    $elementName = "SupportContactInfo"
    $elementNode = Ensure-RootChild -Xml $Xml -Element $elementName
    $elementNode.InnerText = $Listing.supportContact

    # Add comment to parent
    $maxChars = 2048
    $paramSet = @{
        "Element" = $elementNode;
        "Attribute" = @{ $script:LocIdAttribute = $script:LocIdFormat -f $elementName };
        "Comment" = $script:CommentFormat -f $maxChars, "Support Contact Info";
    }

    Add-ToElement @paramSet
}

function Add-PrivacyPolicy
{
<#
    .SYNOPSIS
        Creates the PrivacyPolicy node

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

    $elementName = "PrivacyPolicyURL"
    $elementNode = Ensure-RootChild -Xml $Xml -Element $elementName
    $elementNode.InnerText = $Listing.privacyPolicy

    # Add comment to parent
    $maxChars = 2048
    $paramSet = @{
        "Element" = $elementNode;
        "Attribute" = @{ $script:LocIdAttribute = $script:LocIdFormat -f "PrivacyURL" };
        "Comment" = $script:CommentFormat -f $maxChars, "Privacy Policy URL";
    }

    Add-ToElement @paramSet
}

function ConvertFrom-Listing
{
<#
    .SYNOPSIS
        Converts a base listing for an existing submission into a PDP file that conforms with
        the March 2016 PDP schema.

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
        [String[]] Array of image names that the captions reference

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
    <ProductDescription language="en-us"
        xmlns="http://schemas.microsoft.com/appx/2012/ProductDescription"
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xml:lang="{0}"
        Release="{1}"/>', $Lang, $Release))

    Add-AppStoreName -Xml $Xml -Listing $Listing    
    Add-Keywords -Xml $Xml -Listing $Listing
    Add-Description -Xml $Xml -Listing $Listing
    Add-ReleaseNotes -Xml $Xml -Listing $Listing
    $imageNames = Add-ScreenshotCaptions -Xml $xml -Listing $Listing
    Add-AppFeatures -Xml $Xml -Listing $Listing
    Add-RecommendedHardware -Xml $Xml -Listing $Listing
    Add-CopyrightAndTrademark -Xml $Xml -Listing $Listing
    Add-AdditionalLicenseTerms -Xml $Xml -Listing $Listing
    Add-WebsiteUrl -Xml $Xml -Listing $Listing
    Add-SupportContact -Xml $Xml -Listing $Listing
    Add-PrivacyPolicy -Xml $Xml -Listing $Listing

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

    $output = @()
    $output += "You now need to find all of your images and place them here: <ImagesRootPath>\$Release\<langcode>\..."
    $output += "  where <ImagesRootPath> is the path defined in your config file,"
    $output += "  and <langcode> is the same langcode for the directory of the PDP file referencing those images."
    Write-Log $($output -join [Environment]::NewLine)

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
        $output = @()
        $output += "It appears that you don't have consistent images across all languages."
        $output += "While StoreBroker supports this scenario, some localization systems may"
        $output += "not support this without additional work.  Please refer to the FAQ in"
        $output += "the documentation for more info on how to best handle this scenario."
        Write-Log $($output -join [Environment]::NewLine) -Level Warning

        $output = @()
        $output += "The currently referenced image filenames, per langcode, are as follows:"
        foreach ($langCode in ($LangImageNames.Keys.GetEnumerator() | Sort-Object))
        {
            $output += " * [$langCode]: " + ($LangImageNames.$langCode -join ", ")
        }
    
        Write-Log $($output -join [Environment]::NewLine)
    }
    else
    {
        $output = @()
        $output += "Every language that has a PDP references the following images:"
        $output += "`t$($seenImages -join `"`n`t`")"
        Write-Log $($output -join [Environment]::NewLine)
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

    if ([String]::IsNullOrEmpty($SubmissionId))
    {
        $app = Get-Application -AppId $AppId
        $SubmissionId = $app.lastPublishedApplicationSubmission.id
    }

    $sub = Get-ApplicationSubmission -AppId $AppId -SubmissionId $SubmissionId

    $langImageNames = @{}
    $langs = ($sub.listings | Get-Member -type NoteProperty)
    $pdpsGenerated = 0
    $langs |
        ForEach-Object {
            $lang = $_.Name
            Write-Log "Creating PDP for $lang" -Level Verbose
            Write-Progress -Activity "Generating PDP" -Status $lang -PercentComplete $(($pdpsGenerated / $langs.Count) * 100)
            try
            {
                $imageNames = ConvertFrom-Listing -Listing ($sub.listings.$lang.baseListing) -Lang $lang -Release $Release -PdpRootPath $OutPath -FileName $PdpFileName
                $langImageNames[$lang] = $imageNames
                $pdpsGenerated++
            }
            catch
            {
                Write-Log "Error creating [$lang] PDP: $($Error[0].Exception.Message )" -Level Error
                throw
            }
        }

    Write-Log "PDP's have been created here: $OutPath"
    Show-ImageFileNames -LangImageNames $langImageNames -Release $Release
}




# Script body
$OutPath = Resolve-UnverifiedPath -Path $OutPath

# function Main invocation
Main
