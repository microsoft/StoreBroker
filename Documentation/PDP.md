# StoreBroker PowerShell Module
## PDP (Product Description Page) Files


----------
#### Table of Contents

*   [Overview](#overview)
*   [Sections](#sections)
    *   [AppStoreName](#appstorename)
    *   [Screenshots and Captions](#screenshots-and-captions)
        *   [Folder Structure](#folder-structure)
    *   [Additional Assets](#additional-assets)
        *   [Trailers](#trailers)
    *   [Icons](#icons)
    *   [Fallback Language Support](#fallback-language-support)
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

**For Application Submissions**
 * AppStoreName
 * Keywords
 * Description
 * ShortDescription
 * ShortTitle
 * SortTitle
 * VoiceTitle
 * DevStudio
 * ReleaseNotes
 * ScreenshotCaptions
 * AdditionalAssets
 * AppFeatures
 * RecommendedHardware
 * MinimumHardware
 * CopyrightAndTrademark
 * AdditionalLicenseTerms
 * WebsiteURL
 * SupportContactInfo
 * PrivacyPolicyURL
 * Trailers

**For In-App Product (IAP) ("add-on") Submissions**
 * Title
 * Description
 * Icon

These should map fairly clearly to the sections you're already familiar with in the DevPortal.
For additional requirements on number of elements or length of individual elements, refer to
the schema (or sample file).

### AppStoreName

> The `AppStoreName` property in the PDP file is often a source of confusion for users, so it's recommended
> that you pay close attention this expanded explanation below.

`AppStoreName` maps to the
[`DisplayName`](https://docs.microsoft.com/en-us/uwp/schemas/appxpackage/uapmanifestschema/element-displayname)
property from your application's AppxManifest.xml file.  The Store will automatically grab this for every language
that your application has a listing for, meaining that in most scenarios, you never need to provide a value within
the PDP.  The only time you should ever specify a value for this in the PDP, is if you will be providing a listing
for a language that your application isn't explicitly being localized to.

If you provide this value in a PDP for a language that your application already has a `DisplayName` value for,
your submission will eventually fail after it has been committed because of this name conflict.

**Re-stated again**, you can _only_ successfully provide the `AppStoreName` if _that PDP language_ does not have
a corresponding `DisplayName` entry within your application package.

If you're in the scenario where you _do_ need to do this for _some_ languages, you'll likely want to follow the
[FAQ](./USAGE.md#faq) ("Does StoreBroker support adding region-specific listings for languages that the app itself
doesn't directly support?") which explains how to use mulitple PDP's within your project, each localized to a
different set of languages.  In that scenario, you'd have a PDP with the `AppStoreName` uncommented and localized,
but only for the set of languages that needs it; a different PDP would be used for the other languages, and in that
other PDP, the `AppStoreName` would remain empty/commented-out.

### Screenshots and Captions

> Only relevant for Application submissions

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

### Additional Assets

> Only relevant for Application submissions

There are three different types of images that can be used for a listing:
  1. Screenshots (these have captions)
  2. Additional Assets (these are images that have no concept of captions)
  3. Trailer screenshots (which also don't have captions, but are tied to trailers)

In the [previous section](#screenshots-and-captions), we talked about screenshots
(and their captions).  Now we will talk about #2 (Additional Assets).

You can learn more about the specifics of these different images and how they're used by referring to the
[dev portal's online documentation](https://docs.microsoft.com/en-us/windows/uwp/publish/app-screenshots-and-images),
and the related [API documentation](https://docs.microsoft.com/en-us/windows/uwp/monetize/manage-app-submissions#image-object).

To define these assets, there is a top-level element called `AdditionalAssets` (which
is a sibling to `ScreenshotCaptions`).  It can contain any (or all) of the following
elements:

 * `StoreLogo9x16`
 * `StoreLogoSquare`
 * `Icon`
 * `PromotionalArt16x9`
 * `PromotionalArtwork2400X1200`
 * `XboxBrandedKeyArt`
 * `XboxTitledHeroArt`
 * `XboxFeaturedPromotionalArt`
 * `SquareIcon358X358`
 * `BackgroundImage1000X800`
 * `PromotionalArtwork414X180`

These elements do not have any InnerText/content -- they only have a single attribute
called `FileName` which should reference the .png file for that image type.

Similar to Screenshots, there is full [fallback language support](#fallback-language-support).
You can add the `FallbackLanguage` attribute on an individual element to only affect that one
image type, or you can add it to `AdditionalAssets` to affect them all (or to
`ProductDescription` to affect all asset types).

#### Trailers

> Only relevant for Application submissions

You can learn more about the specifics of trailers and how they're used by referring to the
[dev portal's online documentation](https://docs.microsoft.com/en-us/windows/uwp/publish/app-screenshots-and-images#trailers).

A single trailer consists of the following information:
  * trailer filename
  * trailer title (localizable)
  * trailer screenshot filename (only one permitted)
  * trailer screenshot description (metadata only, never seen be a user)

From an authoring perspective, it looks like this (with loc comment/attributes removed for brevity):

    <Trailers>
        <Trailer FileName="trailer1.mp4">
            <Title>This is the trailer's title</Title>
            <Images>
               <Image FileName="trailer1screenshot.png">The user will never see this text</Image>
            </Images>
        </Trailer>
    </Trailers>

While companies may or may not provide localized screenshots per region, most companies will only
ever produce their trailers for a limited number of different languages/regions, and re-use
those same trailers across most other locales.  Therefore, it is highly advised that you leverage
[fallback language support](#fallback-language-support) when authoring your trailers
so that trailers are propery re-used, thus reducing the size of the final package that needs
to be uploaded to the Store.

### Icons

> Only relevant for In-App Product (IAP) ("add-on") submissions

Unlike screenshots, icons have no associated captions with them.  However, it is possible that
your IAP may need to use a different icon based on the region (maybe a different symbol or color
is needed based on that region's culture), and so the icon is part of the PDP.

The only thing that can be specified for the Icon is the filename of that icon.  It is expected
that the filename will be found within the defined [folder structure](#folder-structure).

### Fallback Language Support

PDP files are language-specific, and as we saw in the [Folder Structure](#folder-structure) section,
any screenhots or icons that are referenced by a PDP are only searched for within that same language's
media sub-folder within `ImagesRootPath`.

There are situations however where you might want to share an image/media file across more than one language.
For instance: maybe you want all Spanish language PDP's to use the images from `es-es`.
Both `New-SubmissionPackage` and `New-InAppProductSubmissionPackage` support a `MediaFallbackLanguage` parameter
which lets you specify the language where StoreBroker should look if any of the referenced media files cannot
be found in the language-specific images/media folder.

For screenshot and icons, you can specify a `FallbackLanguage` attribute whose value would be a lang-code
(ex. `en-US`, `es-es`, etc...).  For icons, the attribute is directly on the `<Icon />` element.  For
screenshots, the attribute is available on both the `<ScreenshotCaptions />` _and_ `<Caption />` elements.
It can be set on either, or both, of those elements.  If specified on both, the value in the `<Caption />`
node value will win, since it is the more-specific value.

Similarly, there is support for `AdditionalAsset` images (on the individual element nodes as well as on
the `AdditionalAsset` node itself), and for trailers on the `Trailers`, `Trailer`, `Images` and `Image`
elements).

You can also set `FallbackLanguage` at the root element (`ProductDescription` or `InAppProductDescription`)
to affect every media type.

As usual, StoreBroker will first search for any media files referenced by that element in that PDP's
langcode-specific images/media sub-folder.  If not found, it will then look in the fallback language's
images/media sub-folder.  Only then will StoreBroker fail if the file still cannot be found.

The key to remember is that this behaves in a "fallback" fashion, similar to language localization, and not
as an override.  StoreBroker will always attempt to use the language-specific version of the file unless
it can't be found.

> Specifying the `FallbackLanguage` attribute will override the `MediaFallbackLanguage` parameter/config value
> for `New-SubmissionPackage` and `New-InAppProductSubmissionPackage` for that specific media element.
> There can only be _one_ fallback language for any given media file.  So, at most, StoreBroker will search
> for a given media file twice (original language and fallback language) before failing the packaging action.

----------

## Schemas and Samples

At this time, StoreBroker has two PDP schemas in use:

### Application Submissions
 * **Uri**: `http://schemas.microsoft.com/appx/2012/ProductDescription`
 * **XSD**: [PDP\ProductDescription.xsd](../PDP/ProductDescription.xsd)
 * **Sample XML**: [PDP\ProductDescription.xml](../PDP/ProductDescription.xml)

### In-App Product (IAP) ("add-on") Submissions
 * **Uri**: `http://schemas.microsoft.com/appx/2012/InAppProductDescription`
 * **XSD**: [PDP\InAppProductDescription.xsd](../PDP/InAppProductDescription.xsd)
 * **Sample XML**: [PDP\InAppProductDescription.xml](../PDP/InAppProductDescription.xml)

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
