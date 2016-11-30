# StoreBroker PowerShell Module
## PDP (Product Description Page) Files


----------
#### Table of Contents

*   [Overview](#overview)
*   [Sections](#sections)
    *   [Screenshots and Captions](#screenshots-and-captions)
        *   [Folder Structure](#folder-structure)
*   [Schemas And Samples](#schemas-and-samples)
*   [Loc Attributes and Comments](#loc-attributes-and-comments)
    *   [Marking A String To Not Be Localized](#marking-a-string-to-not-be-localized)

----------


## Overview

One of the biggest benefits of using StoreBroker and the Windows Store Submission API
to update your submission, is the ease with which they can update all of the listing
metadata (descriptions, features, screenshots and captions, etc...) across every language
that you have localized metadata for.

StoreBroker uses an XML file format that we refer to as "PDP" (Product Description Page)
to store all of this metadata, making it easy for localization systems to parse and
localize the relevant content.

> There is no requirement that you adopt the PDP XML file format that we are discussing here.
> `New-SubmissionPackage` generates the .json and .zip files ("the payload") that the other
> commands interact with, and it is the only part of StoreBroker that has knowledge of PDP
> files.  If you are already using some other file format for the localization of this
> metadata content, but you want to use StoreBroker, then you will have to write the necessary
> code to generate the payload.  Refer to the
> [Submission API Documentation](https://msdn.microsoft.com/en-us/windows/uwp/monetize/manage-app-submissions)
> for more information on this.

----------

## Sections

The main sections that you'll find in the PDP (depending on which schema version is in use)
are as follows:

 * Keywords
 * Description
 * ReleaseNotes
 * ScreenshotCaptions
 * AppFeatures
 * RecommendedHardware
 * CopyrightAndTrademark
 * AdditionalLicenseTerms
 * WebsiteURL
 * SupportContactInfo
 * PrivacyPolicyURL

These should map fairly clearly to the sections you're already familiar with in the DevPortal.
For additional requirements on number of elements or length of individual elements, refer to
the schema (or sample file).

### Screenshots and Captions

It's worth a little bit of additional time to explain how screenshots and captions work.

The DevPortal has different screenshot sections per platform, and you need to specify a caption
for each image that you upload.  That makes sense from the DevPortal perspective where it wants
to be as declarative and flexible as possible for you to author how you want your content displayed.

That approach doesn't make as much sense from a localization perspective, because you likely
use a similar set of screenshots across all platforms, and those screenshots would share the
same localized caption.

Since the PDP file is all about localizing text, it puts the _captions_ first, and you then associate
screenshots to those captions by filename.  There are five different platforms currently supported
for screenshots:

 * DesktopImage
 * MobileImage
 * XboxImage
 * SurfaceHubImage
 * HoloLensImage

You need to specify one or more platform image attributes for each caption (otherwise, there's no
reason to bother localizing the caption).  The value of the attribute is the name of the screenshot
that will be found in [screenshot folder structure](#folder-structure).

#### Folder Structure

A key attribute to be aware of is the `Release` attribute that is part of the primary
`ProductDescription` node.  The value for `Release` is directly used by `New-SubmissionPackage`
to find the screenshots referenced by the PDP.

The expected folder structure layout for screenshots is as follows:

    <ImagesRootPath>\<Release>\<lang-code>\...\img.png

where:
 * `ImagesRootPath`: specified in your config file or at the commandline
 * `Release`: this is the attribute being discussed
 * `lang-code`: the langCode for the language matching that of the PDP
 * `...`: any number of sub-folders ... we don't care about these...at this point, we're just
    looking recusively for the specific filename
 * `img.png`: the filename that you specified in the caption's platform-specific image attribute


----------

## Schemas and Samples

At this time, StoreBroker only has a single PDP schema in use:

 * **Uri**: `http://schemas.microsoft.com/appx/2012/ProductDescription`
 * **XSD**: [PDP\ProductDescription.xsd](..\PDP\ProductDescription.xsd)
 * **Sample XML**: [PDP\ProductDescription.xml](..\PDP\ProductDescription.xml)

----------

## Loc Attributes and Comments

If you reviewed the schema or the sample, you may have noticed some attributes named `_locID`
or comments with the string `_locComment_text` in them. Those are there to assist with
localization systems that don't send the raw file to localizers, but rather send a parsed
representation of the file.

The `_locID_` attribute is designed to give a unique ID (within the file) that localization
systems can use to refer to the string.  The `_locComment_text` comment is designed to be
shown next to the localization string to give context to the localizers on how the string is
being used, and can contain special instructions in brackets that give explicit guidance on
requirements for the way that a string must be localized (ex: `{MaxLength=100}` would indicate
that the final localized string can't exceed 100 characters).

### Marking A String To Not Be Localized

In some situations, you may not want a certain string to be localized (ex: an email address or URL);
this might be obvious to a human localizer, but likely not to an automated localization system.
A common scenario where this might be an issue is if you use automated localization for
[pseudolocalization](https://en.wikipedia.org/wiki/Pseudolocalization) purposes.

The recommended way to indicate this in your PDP file is to modify that element's `_locComment_text`.
Just change the part in the brackets (`{MaxLength=xxx}`) to instead say `{Locked}`. So, if it
originally looked like this:

    <!-- _locComment_text="{MaxLength=200} App Feature 1" -->

change it to look like this:

    <!-- _locComment_text="{Locked} App Feature 1" -->

And then modify your localization system to recognize the comment for that element to indicate that
it should not be localized.  You should additionally publish this information to your localizers
so that it can be quite explicit to them as well when they should/shouldn't localize a certain
string.