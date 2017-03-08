# StoreBroker PowerShell Module
## Usage

#### Table of Contents

*   [General Guidance](#general-guidance)
    *   [Help Documentation](#help-documentation)
    *   [Formatting Results](#formatting-results)
    *   [Logging](#logging)
    *   [Additional Configuration](#additional-configuration)
    *   [Common Switches](#common-switches)
    *   [Accessing the Portal](#accessing-the-portal)
*   [Creating Your Application Payload](#creating-your-application-payload)
*   [Creating A New Application Submission](#creating-a-new-application-submission)
    *    [The Easy Way](#the-easy-way)
    *    [Manual Submissions](#manual-submissions)
    *    [Related Commands](#related-commands)
*   [Monitoring A Submission](#monitoring-a-submission)
    *   [Status Progression](#status-progression)
*   [Flighting](#flighting)
    *   [Flighting Overview](#flighting-overview)
    *   [Flighting Commands](#flighting-commands)
*   [In App Products](#in-app-products)
    *   [IAP Overview](#iap-overview)
    *   [Creating Your IAP Payload](#creating-your-iap-payload)
    *   [IAP Commands](#iap-commands)
*   [Using INT vs PROD](#using-int-vs-prod)
*   [Telemetry](#telemetry)
*   [FAQ](#faq)

----------

## General Guidance

### Help Documentation

Once loaded, usage is straight-forward for PowerShell users.

To see all of the available Commands, simply run:

    (Get-Module StoreBroker).ExportedCommands

All Commands are fully documented, so to understand one better, simply run **Get-Help** on it.
For instance:

    Get-Help Get-Applications -ShowWindow

or

    Get-Help Get-Applications -Full

### Formatting Results

By default, the `Get-*` commands will simply return raw JSON results that can be used for your
own post-processing.  If you'd prefer to simply see pretty-printed results, just pipe the result
into the corresponding `Format-*` command.

### Logging

All commands will log to the console, as well as to a log file, by default.
The logging is affected by three global variables.  The pre-existing values of these
variables will be honored if they already exist, otherwise they will be created (with defaults)
when the module is loaded.

 **`$global:SBLogPath`** - [string] The logfile. Defaults to
   `$env:USERPROFILE\Documents\StoreBroker.log`
    
 **`$global:SBLoggingEnabled`** [bool] Defaults to `$true`. To disable file-based logging,
    set to `$false`

 **`$global:SBUseUTC`** [bool] Defaults to `$false`. If `$false`, times are logged in local time.
    When `$true`, times are logged using UTC (and those timestamps will end with a Z per the
    [W3C standard](http://www.w3.org/TR/NOTE-datetime))

> **PowerShell Tip**
>
> If you wish to always use a different value for these, set the new values in your PowerShell
> profile. By default, the full path to your profile is automatically stored by PowerShell in
> `$profile`. From a **PowerShell console** run `notepad $profile`. If Notepad informs you that
> the file doesn't exist, let Notepad create the profile for you. Then, just add your updated
> assignments to it.

### Additional Configuration

There are some additional optional configurations that can be made with StoreBroker if the
situation requires it.  Most users will likely never need to touch these.  The pre-existing
values of these variables will be honored if they already exist, otherwise they will be created
(with defaults) when the module is loaded.

 **`$global:SBWebRequestTimeoutSec`** - [int] Number of seconds to use for the timeout of the
   internal `Invoke-WebRequest` call. Defaults to `0` (indefinite)

### Common Switches

All commands support the `-Verbose` switch in the event that you want fine-grained detail
on what is currently happening.  Verbose logging will always be in the log file...it will only
be visibile in the console window though if you specify the `-Verbose` switch.

All commands also support the `-WhatIf` switch (along with the corresponding `-Confirm` switch.)

### Accessing the Portal

Sometimes, you just want to look at the webpage instead of the commandline.  For quick access
to the appropriate page on the dev portal for what you're looking for, make use of

    Open-DevPortal -AppId <appId> [-SubmissionId <submissionId> [-ShowFlight]]

 * If you just specify `AppId`, you'll be taken directly to that app page within the dev portal.
 * If you also specify `SubmissionId`, you can view that specific submission in the dev portal
  (the submission id can be for an app submission or a flight submission).
 * If you specify `-ShowFlight` (which is only valid if you also provide a submission id), then
   you'll be taken to the page where you can view/edit the flight that the flight submission is
   associated with.

## Creating Your Application Payload

In StoreBroker, a "payload" is a combination of a json file and a zip file.  The **json** file
has the entire content of a Windows Store Submission.  This content _could_ be submitted as-is,
but usually only selected portions of it are "patched" into a new submission.  The **zip** file
usually has the appx files and screenshots, although depending on how you create your payload,
one of those might be missing.

To create your payload, you need to have the following (which you should already have from
following the instructions in [SETUP.md](SETUP.md):
 * [StoreBroker config file](SETUP.md#getting-your-config)
 * [PDP files](SETUP.md#getting-your-pdps)
 * Screenshots
 * Packages (.appx / .appxbundle / .appxupload)

> In order to use New-SubmissionPackage, it is highly recommended that you read the documentation
> (`Get-Help New-SubmissionPackage -Full`) and read the documentation in the configuration file.

Generating the submission request JSON/zip package is done with

    New-SubmissionPackage -ConfigPath <config-path> -PDPRootPath <path> [[-Release] <string>] -PDPInclude <filename> [-PDPExclude <filename>] -ImagesRootPath <path> -AppxPath <full-path>[, <additional-path>]+ -OutPath <output-dir> -OutName <output-name>  

> Items in brackets ('[]') are optional.

The `-Release` parameter is technically optional, depending on how you choose to store your PDP
files. For more info, run:

    Get-Help New-SubmissionPackage -Parameter PdpRootPath
    Get-Help New-SubmissionPackage -Parameter Release
    
> If one of your parameters does not change often, you can specify a value in the config file and
> leave out this parameter at runtime. In this case, you should specify the remaining parameters
> to `New-SubmissionPackage` with their parameter names.  As an example, it is possible to leave
> out `OutPath` but if you don't specify the remaining parameters by name, then the value of the
> next parameter, `OutName`, will be mapped to the `OutPath` parameter, causing a failure.
    
As part of its input, `New-SubmissionPackage` expects a configuration file, which you should
have [already created](SETUP.md#getting-your-config).

## Creating A New Application Submission

> When you create a new application, you are *actually* cloning the currently published
> submission and modifying it to represent how you want the new submission to look (just like
> in Dev Center).  This is why the primary function that you'll use is called
> `Update-ApplicationSubmission`.

Be ready with your [AppId](SETUP.md#getting-your-appid) before you continue.

### The Easy Way

We can't assume that you always have all of the information for the submission that you are making,
nor can we assume that you want to change *everything* about a submission every time.
There may be times when you only want to modify the Listing metadata for the application, or other
times when you only want to add new packages to an existing submission.  It's also possible
that you want to use this tool to update your listing, but your app is old and has packages that
span multiple releases/platforms (e.g. Windows 8, Windows 8.1, Windows Phone 8, Windows Phone 8.1,
Windows 10 Universal), and you only want to have to provide the packages to be added, as opposed
to needing to provide every package during every update.

This is why when you want to create a new submission, it actually clones the existing published
submission and then patches/modifies it to become the new submission.  Because of this, **you must
specify one or more switches to indicate _exactly_ what you want modified in the submission in
order for anything to be changed.**

The basic syntax looks of the command looks like this:

    Update-ApplicationSubmission -AppId <appId> -SubmissionDataPath ".\submission.json" -PackagePath ".\package.zip" -AutoCommit -Force

While most of those parameters are straight-forward, the last two deserve explanation:

 * **`-Force`** - You can only have one "pending" (e.g. in-progress) submission at any given
   time.  Using `-Force` tells the command to delete any pending submission before continuing.
   If you want to continue working with an existing pending submission, you can instead provide
   the existing pending submission with the **`-SubmissionId`** paramter, as noted below.

 * **`-AutoCommit`** - The submission will not start the certification process until you "commit"
   it.  This switch says that the submission should automatically be committed once it has finished
   replacing the submission content and uploading the package.  If you don't specify this, you'll
   have to manually call the `Complete-ApplicationSubmission` command later on.

> An important thing to note though, is that if you run that exact command above, the resulting
> submission will be **identical** to the currently published submission, because you didn't tell
> `Update-ApplicationSubmission` what you specifically wanted to modify.

> If for some reason you have an existing pending submission that you want to update (as opposed
> to cloning the existing published submission), use `-SubmissionId` to specify it, and that
> will be used instead of creating a new cloned submission.

The following key switches can be added in any order or combination, and they will indicate what
content from the .json that you are providing needs to be added to or replaced within the
cloned submission:

 * **`-AddPackages`** - This will add any packages from your json to the cloned submission.
   _This switch is mutually exclusive with `ReplacePackages`._
   > Please note: The result of this action is that you may end up with "redundant" packages
   > (packages for older versions of your app that will never be sent to users since a newer
   > one now exists.)  To clean these up at a later time, refer to the [FAQ](#faq).

 * **`-ReplacePackages`** - Causes any existing packages in the submission to be removed, and only
   the packages that are listed in SubmissionDataPath will be in the final, patched submission.
   _This switch is mutually exclusive with `AddPackages`._
   > **WARNING:** Use this switch with care.  If you use this switch and your StoreBroker
   > payload doesn't have all the packages for all the OS versions & platforms that you currently
   > support (and want to continue to support), then you risk making your app unavailable to some
   > of your users.   

 * **`-UpdateListings`** - This will replace the cloned submission's listings metadata with yours
   (the localized content from the PDP's), deleting any existing screenshots along the way.  This
   will only effect the Windows 10 listings.  The `platformOverrides` listings for previous OS
   versions will simply be automatically carried over from the cloned submission.

 * **`-UpdatePublishModeAndVisibility`** - This will change the `targetPublishMode`,
   `targetPublishDate`, and `visibility` of the cloned submission to that which is specified
   in your json.  Without doing this, keep in mind that your new submission will publish the same
   way as your previous submission (be that immediately, manual or time based).

 * **`-UpdatePricingAndAvailability`** - This will change the `pricing`,
   `allowTargetFutureDeviceFamilies`, `allowMicrosoftDecideAppAvailabilityToFutureDeviceFamilies`,
   and `enterpriseLicensing` of the cloned submission to that which is specified in your json.

 * **`-UpdateAppProperties`** - This will change the `applicationCategory`,
   `hardwarePreferences`, `hasExternalInAppProducts`, `meetAccessibilityGuidelines`,
   `canInstallOnRemovableMedia`, `automaticBackupEnabled`, and `isGameDvrEnabled` of
   the cloned submission to that which is specified in your json.

 * **`-UpdateNotesForCertification`** - This will change the `notesForCertification` field of
   the cloned submission to that which is specified in your json.

In addition to those switches, there are additional optional parameters that you can provide to
fully override the publication and visibility of your app submission.

 * **`TargetPublishMode`** - Indicates how the submission should be published.  Setting this to any
   value other than `Default` will override the usage of `-UpdatePublishModeAndVisibility`.
     * **`Default`** - Uses the same setting as the previous submission. **This is the default.**
     * **`Manual`** - Requires you to click a button in the Dev Portal after certification completes.
     * **`Immediate`** - Publishes immediately after certification.
     * **`SpecificDate`** - Choose a date when you want it to be published.
       Specify with `TargetPublishDate`

 * **`TargetPublishDate`** - The specific date/time that the submission should be published. To use
   this, you must specify `TargetPublishMode` as `SpecificDate`.  Using this value will override
   any value that might have been set by `-UpdatePublishModeAndVisibility`.  Users should provide this in
   local time and it will be converted automatically to UTC.

 * **`Visibility`** - Indicates the store visibility of the app once the submission has been
   published. Setting this to any value other than `Default` will override the usage of
   `-UpdatePublishModeAndVisibility`.
     * **`Default`** - Uses the same setting as the previous submission. **This is the default.**
     * **`Public`** - Anyone can find your app in the Store.
     * **`Private`** - Hide this app in the Store. Customers with a direct link to the app's
       listing can still download it, except on Windows 8 and Windows 8.1.
     * **`Hidden`** - Hide this app and prevent acquisition. Customers with a promotional code can
       still download it on Windows 10 devices.

You can control mandatory updates with the following parameters

 * **`-IsMandatoryUpdate`** - Indicates whether you want to treat the packages in the submission
   as mandatory packages for self-installing app updates.  For more information, refer to the
   [Store documentation](https://docs.microsoft.com/en-us/windows/uwp/packaging/self-install-package-updates).

 * **`MandatoryUpdateEffectiveDate`** - The date/time when the packges in this submission become mandatory.
   This value will be ignored if `-IsMandatoryUpdate` is not also provided. Users should provide this in
   local time and it will be converted automatically to UTC.

You can also leverage gradual rollouts to limit the percentage of users who will be given the packages within
this submission.

 * **`PackageRolloutPercentage`** - _[0 - 100]_.  If specified, the packages in this submission will only
   be rolled out to this percentage of your users.  You can later update this percentage by calling
   `Update-ApplicationSubmissionPackageRollout`, and can complete the gradual rollout by either
   finalizing it with `Complete-ApplicationSubmissionPackageRollout` (which will make the packages available
   to all of your users) or `Stop-ApplicationSubmissionPackageRollout` (which will halt any new users from
   getting the packages in this submission).

   > Changing the percentage to 100 is not the same as Finalizing the package rollout.  For more information
   > on this topic, refer to the [Store documentation](https://docs.microsoft.com/en-us/windows/uwp/publish/gradual-package-rollout).

* **`ExistingPackageRolloutAction`** _[NoAction, Halt, Finalize]_ You can't create a new submission if
  the current pending submission is currently using package rollout.  In that scenario, prior to calling
  this command, you can manually call `Complete-ApplicationSubmissionPackageRollout` or
  `Stop-ApplicationSubmissionPackageRollout`, or you can just sepecify this paramter and the action it
  should take, and it will do that for you automatically prior to cloning the submission.

> Due to the nature of how the Store API works, you won't see any of your changes in the
> dev portal until your submission has entered into certification.  It doesn't have to _complete_
> certification for you to see your changes, but it does have to enter certification first.
> If it's important for you to verify your changes in the dev portal prior to publishing,
> consider publishing with the "Manual" targetPublishMode by setting that value in your
> config file and then additionally specifying the `-UpdatePublishModeAndVisibility` switch
> when calling Update-ApplicationSubmission, or by specifying `-TargetPublishMode Manual`.
> By using the "Manual" submission mode, you will be forced to use the UI to complete the
> publication of your submission once it has passed certification.

**Return Values**:
`Update-ApplicationSubmission` returns back two values to you at its completion:
the new submission id, and the UploadURL.  You can use that UploadUrl to upload your submission's
.zip with `Upload-SubmissionPackage`, in the event that you didn't specify the `PackagePath`
or want to upload it again.

### Manual Submissions

As indicated above, everything that you need to do to update a submission can be accomplished
with a single command.  However, should one choose to do so, you can perform all of those steps
manually.

 * Clone the existing published submission so that you can generate an update.
 
          $sub = New-ApplicationSubmission -AppId <appId> [-Force]

    * By using the `-Force` switch, it will call `Remove-ApplicationSubmission` behind the
      scenes if it finds that there's an existing pending submission for your app.

 * Read in the content of the json file from your `New-SubmissionPackage` payload:
 
          $json = (Get-Content .\submission.json -Encoding UTF8) | ConvertFrom-Json

 * If you need to update any content for the cloned submission, here is where you'd "patch in"
   applicable values from `$json` into `$sub`.

    * For example, here's how you can change a simple content that has a single value:

             $sub.hardwarePreferences = $json.hardwarePreferences

    * For nested content, you will need to ensure that all nested values are applied. The easiest way to do this
      is to inspect the json and then manually assign the nested values. For a more generic way, you can implement
      a function similar to `DeepCopy-Object` in Helpers.ps1.

             $sub.allowTargetFutureDeviceFamilies.Xbox = $json.allowTargetFutureDeviceFamilies.Xbox
             $sub.allowTargetFutureDeviceFamilies.Team = $json.allowTargetFutureDeviceFamilies.Team
             ... repeat for all nested values ...

 * Send the updated submission content so that the API knows what should be updated:

          Set-ApplicationSubmission -AppId $appId -UpdatedSubmission $sub

 * If you're updating screenshots or packages, you'll need to upload the supporting .zip file:

          Set-SubmissionPackage -PackagePath <pathToYourZip> -UploadUrl ($sub.fileUploadUrl)

 * Tell the API that you're done with the submission and to start validation / certification:

          Complete-ApplicationSubmission -AppId $appId -SubmissionId ($sub.id)

The `-AutoCommit` switch should not be confused with publishing of the submission.  A submission
won't enter into certification until it has been "committed", and a submission can only be committed
once.  In general, you probably always want to `-AutoCommit`.  If you choose to leave out the
`-AutoCommit` switch, you will need to manually call `Complete-ApplicationSubmission` in order
for your submission to enter into the Store certification process.

> All of the commands referenced above will work for app and flight submissions equally.
> If using them for flight submissions, just be sure to also include the FlightId parameter.

### Related Commands

In addition to the commands above, there are some other commands that you may find useful along the way.

#### Gradual Rollout Commands

If you're not familiar with package rollout, it might be helpful to read more about it
in the [Store documentation](https://docs.microsoft.com/en-us/windows/uwp/publish/gradual-package-rollout).

To view the current package rollout status:

    Get-ApplicationSubmissionPackageRollout -AppId <appId> -SubmissionId <submissionId>

To update the current package rollout percentage:

    Update-ApplicationSubmissionPackageRollout -AppId <appId> -SubmissionId <submissionId> -Percentage <percentage>

To halt the current package rollout:

    Stop-ApplicationSubmissionPackageRollout -AppId <appId> -SubmissionId <submissionId>

To finalize the current package rollout:

    Complete-ApplicationSubmissionPackageRollout -AppId <appId> -SubmissionId <submissionId>

## Monitoring A Submission

Once you've committed a new submission, an unknown amount of time must pass for it to go through
initial validation and eventually through certification.  Any time along the way, the Store may
have warnings and/or errors that you may need to act on, but you wouldn't know it unless you
actively check the submission.

To ease this pain, you can use `Start-SubmissionMonitor` to automatically check
for status changes on your behalf.  You can even have it email you whenever the status changes,
just in case you're away from the computer when the status changes.

The basic syntax looks like this:

    Start-SubmissionMonitor -AppId <appId> -SubmissionId <submissionId>

This will just start a loop that checks every 60 seconds to see if the status has changed for
this submission.  All changes will be printed to the console window.  The monitoring will
automatically end when the submission enters a failed state or enters the final state that
the current `targetPublishMode` allows for.

> There are other parameters that can be passed-in as well if you want to use this to monitor
> a Flight (`-FlightId`) or IAP (In-App Purchase) (`-IapId`) submission.

If you want to have it also email you, you must first configure StoreBroker for your email system:

  * **`$global:SBNotifyDefaultDomain`** - [string] The default domain name to append to any
    incomplete email address.
  * **`$global:SBNotifyDefaultFrom`** - [string] Default sender email address.
    If note specified, defaults to the logged-in user's username.
  * **`$global:SBNotifySmtpServer`** - [string] The SMTP Server to be used.
  * **`$global:SBNotifyCredential`** - [PSCredential] The credentials needed to send mail through
    that SMTP Server. Defaults to $null (to use domain credentials)

> **PowerShell Tip**
>
> If you plan on using the email functionality of `Start-SubmissionMonitor`, it will likely be more
> convenient for you to set the these values in your PowerShell profile so that they're always
> correctly configured  By default, the full path to your profile is automatically stored by
> PowerShell in `$profile`. From a **PowerShell console** run `notepad $profile`. If Notepad
> informs you that the file doesn't exist, let Notepad create the profile for you. Then, just add
> your updated assignments to it.

Then you can add a list of one or more email addresses for it to notify

    Start-SubmissionMonitor -AppId <appId> -SubmissionId <submissionId> -EmailNotifyTo <emailAddress>

Multiple email addresses are separated by a comma

    Start-SubmissionMonitor -AppId <appId> -SubmissionId <submissionId> -EmailNotifyTo <emailAddress1>,<emailAddress2>

### Status Progression

 The following explains the common progression of a submission by status:

  * **`PendingCommit`** - Submission created but not yet "Committed"
  * **`CommitStarted`** - Either `-AutoCommit` was used on the submission, or you manually
    called `Commit-ApplicationSubmission`
  * **`PreProcessing`** - Getting ready to enter certification.
  * **`Certification`** - Certification has started.  _Once it hits this stage_, you will be able
    to see the changes your submission has made in the DevPortal.  Prior to this stage, the
    Dev Portal is out-of-sync with the API.
  * **`Release`** - It passed certification and can now be published.  If you are using the
    `Manual` or `SpecificDate` publish modes, this is where it will stay until you either
    click the button in the Dev Portal, or the date specified arrives.
  * **`PendingPublication`** - Preparing to publish the update to the store.
  * **`Publishing`** - Getting the update published to all content servers.
  * **`Published`** - All actions have completed.  The update is now live.


## Flighting

### Flighting Overview

There are three main concepts to understand with flighting:
  * Flight Group
  * Flight Submission
  * Flight

A *Flight Group* is just a name given to a collection of MSA's.

A *Flight Submission* is similar to an application submission, but it has much less metadata.
The only data currently associated with it is its set of packages and its publish mode and date.

A *Flight* is a specially named grouping that associates zero or more Flight Groups with a
specific Flight Submission.  An application can have multiple Flights, and these are given a
priority ordering (so that it's deterministic what Flight Submission package an end-user will get
if they are in one or more Flight Groups that are associated with more than one Flight.

### Flighting Commands

The most common thing a user will do around flighting with StoreBroker is to release an update
to a Flight that already exists.  Doing so mirrors how you do so with a normal app submission
update.

The basic syntax looks of the command looks like this:

    Update-ApplicationFlightSubmission -AppId <appId> -FlightId <flightId> -SubmissionDataPath ".\submission.json" -PackagePath ".\package.zip" -AutoCommit -Force

While most of those parameters are straight-forward, the last two deserve explanation:

 * **`-Force`** - You can only have one "pending" (e.g. in-progress) submission at any given
   time.  Using `-Force` tells the command to delete any pending submission before continuing.
   If you want to continue working with an existing pending submission, you can instead provide
   the existing pending submission with the **`-SubmissionId`** paramter, as noted below.

 * **`-AutoCommit`** - The submission will not start the certification process until you "commit"
   it.  This switch says that the submission should automatically be committed once it has finished
   replacing the submission content and uploading the package.  If you don't specify this, you'll
   have to manually call the `Complete-ApplicationFlightSubmission` command later on.

> An important thing to note though, is that if you run that exact command above, the resulting
> submission will be **identical** to the currently published submission, because you didn't tell
> `Update-ApplicationFlightSubmission` what you specifically wanted to modify.

> If for some reason you have an existing pending submission that you want to update (as opposed
> to cloning the existing published submission), use `-SubmissionId` to specify it, and that
> will be used instead of creating a new cloned submission.  That parameter 

The following key switches can be added in any order or combination, and they will indicate what
content from the .json that you are providing needs to be added to or replaced within the
cloned submission:

 * **`-AddPackages`** - This will add any packages from your json to the cloned submission.
   _This switch is mutually exclusive with `ReplacePackages`._
   > Please note: The result of this action is that you may end up with "redundant" packages
   > (packages for older versions of your app that will never be sent to users since a newer
   > one now exists.)  To clean these up at a later time, refer to the [FAQ](#faq).

 * **`-ReplacePackages`** - Causes any existing packages in the submission to be removed, and only
   the packages that are listed in SubmissionDataPath will be in the final, patched submission.
   _This switch is mutually exclusive with `AddPackages`._
   > **WARNING:** Use this switch with care.  If you use this switch and your StoreBroker
   > payload doesn't have all the packages for all the OS versions & platforms that you currently
   > support (and want to continue to support), then those users will end up getting your app
   > from a different Flight or the public submission.

 * **`-ReplacePackages`** - Causes any existing packages in the submission to be removed, and only
   the packages that are listed in `SubmissionDataPath` will be in the final, patched submission.
   This switch is mutually exclusive with `-AddPackages`.

 * **`-UpdatePublishMode`** - This will change the `targetPublishMode` and `targetPublishDate`
   of the cloned submission to that which is specified in your json.  Without doing this, keep in
   mind that your new submission will publish the same way as your previous submission (be that
   immediately, manual or time based).

 * **`-UpdateNotesForCertification`** - This will change the notesForCertification field of
   the cloned submission to that which is specified in your json.

In addition to those switches, there are additional optional parameters that you can provide to
fully override the publication of your app's flight submission.

 * **`TargetPublishMode`** - Indicates how the submission should be published.  Setting this to any
   value other than `Default` will override the usage of `-UpdatePublishMode`.
     * **`Default`** - Uses the same setting as the previous submission.  **This is the default.**
     * **`Manual`** - Requires you to click a button in the Dev Portal after certification completes.
     * **`Immediate`** - Publishes immediately after certification.
     * **`SpecificDate`** - Choose a date when you want it to be published.  Specify with
       `TargetPublishDate`

 * **`TargetPublishDate`** - The specific date/time that the submission should be published. To use
   this, you must specify `TargetPublishMode` as `SpecificDate`.  Using this value will override
   any value that might have been set by `-UpdatePublishMode`.  Users should provide this in
   local time and it will be converted automatically to UTC.

You can control mandatory updates with the following parameters

 * **`-IsMandatoryUpdate`** - Indicates whether you want to treat the packages in the submission
   as mandatory packages for self-installing app updates.  For more information, refer to the
   [Store documentation](https://docs.microsoft.com/en-us/windows/uwp/packaging/self-install-package-updates).

 * **`MandatoryUpdateEffectiveDate`** - The date/time when the packges in this submission become mandatory.
   This value will be ignored if `-IsMandatoryUpdate` is not also provided. Users should provide this in
   local time and it will be converted automatically to UTC.

You can also leverage gradual rollouts to limit the percentage of users who will be given the packages within
this submission.

 * **`PackageRolloutPercentage`** - _[0 - 100]_.  If specified, the packages in this submission will only
   be rolled out to this percentage of your users.  You can later update this percentage by calling
   `Update-ApplicationFlightSubmissionPackageRollout`, and can complete the gradual rollout by either
   finalizing it with `Complete-ApplicationFlightSubmissionPackageRollout` (which will make the packages available
   to all of your users) or `Stop-ApplicationFlightSubmissionPackageRollout` (which will halt any new users from
   getting the packages in this submission).

   > Changing the percentage to 100 is not the same as Finalizing the package rollout.  For more information
   > on this topic, refer to the [Store documentation](https://docs.microsoft.com/en-us/windows/uwp/publish/gradual-package-rollout).

* **`ExistingPackageRolloutAction`** _[NoAction, Halt, Finalize]_ You can't create a new submission if
  the current pending submission is currently using package rollout.  In that scenario, prior to calling
  this command, you can manually call `Complete-ApplicationFlightSubmissionPackageRollout` or
  `Stop-ApplicationFlightSubmissionPackageRollout`, or you can just sepecify this paramter and the action it
  should take, and it will do that for you automatically prior to cloning the submission.

> Due to the nature of how the Store API works, you won't see any of your changes in the
> dev portal until your submission has entered into certification.  It doesn't have to _complete_
> certification for you to see your changes, but it does have to enter certification first.
> If it's important for you to verify your changes in the dev portal prior to publishing,
> consider publishing with the "Manual" targetPublishMode by setting that value in your
> config file and then additionally specifying the `-UpdatePublishMode` switch
> when calling Update-ApplicationFlightSubmission, or by specifying `-TargetPublishMode Manual`.
> By using the "Manual" submission mode, you will be forced to use the UI to complete the
> publication of your submission once it has passed certification.

`Update-ApplicationFlightSubmission` is a convenience method that wraps a number of individual
commands into a single command.  If you want to understand exactly what it does, refer to the
previous section on ["manual submissions."](#manual-submissions) (similar methods exist for Flight
submissions).

**Return Values**:
`Update-ApplicationFlightSubmission` returns back two values to you at its completion:
the new submission id, and the UploadURL.  You can use that UploadUrl to upload your submission's
.zip with `Upload-SubmissionPackage` in the event that you didn't specify the `PackagePath`
or want to upload it again.

#### Other Common Flight-related Tasks:

##### Viewing Application Flights

View all the flights assigned to a given app:

    Get-ApplicationFlights -AppId <appId> | Format-ApplicationFlights

View the details of a specific flight

    Get-ApplicationFlight -AppId <appId> -FlightId <flightId> | Format-ApplicationFlight


##### Creating and/or Removing Flights

> At this time, there is no way to interact with **Flight Groups** via the Submission API (and thus
> not via StoreBroker).  If you need to reference a `FlightGroupId`, you'll need to get it from the
> URL when viewing it in the dev portal.  You can currently use `Get-FlightGroups` to directly
> navigate to that page in the dev portal UI.

To create a new flight:

    New-ApplicationFlight -AppId <appId> -FriendlyName <name> [-RankHigherThan <name>] [-Groupids <id>]

If you don't specify the friendly name of an existing flight to rank this higher than, it will be
ranked highest of all current flights.

> You cannot edit existing Flights (names, ranking, flight groups) via the API (and thus not
> via StoreBroker).  To do so, use `Open-DevPortal` to quickly navigate to the Flight edit page.

To delete a flight:

    Remove-ApplicationFlight -AppId <appId> -FlightId <flightId>


##### Flight Submissions

To view an existing flight submission:

    Get-ApplicationFlightSubmission -AppId <appId> -FlightId <flightId> -SubmissionId <submissionId> | Format-ApplicationFlightSubmission

To delete a flight submission:

    Remove-ApplicationFlightSubmission -AppId <appId> -FlightId <flightId> -SubmissionId <submissionId>

To monitor a flight submission:
Follow the same steps for [monitoring an application submission](#monitoring-a-submission), but
just be sure to _also include_ the **`-FlightId`** in the cmdlet parameters.

##### Gradual Rollout

If you're not familiar with package rollout, it might be helpful to read more about it
in the [Store documentatin](https://docs.microsoft.com/en-us/windows/uwp/publish/gradual-package-rollout).

To view the current package rollout status:

    Get-ApplicationFlightSubmissionPackageRollout -AppId <appId> -FlightId <flightId> -SubmissionId <submissionId>

To update the current package rollout percentage:

    Update-ApplicationFlightSubmissionPackageRollout -AppId <appId> -FlightId <flightId> -SubmissionId <submissionId> -Percentage <percentage>

To halt the current package rollout:

    Stop-ApplicationFlightSubmissionPackageRollout -AppId <appId> -FlightId <flightId> -SubmissionId <submissionId>

To finalize the current package rollout:

    Complete-ApplicationFlightSubmissionPackageRollout -AppId <appId> -FlightId <flightId> -SubmissionId <submissionId>

## In App Products

### IAP Overview

In-App Products (IAP's) are additional features that are offered to users of your apps.
In the Store, IAP's are considered siblings to Applications, as opposed to children,
because the same IAP can be associated with more than one Application.

### Creating Your IAP Payload

> These instructions very closely mirror those for [Creating Your Application Payload](#creating-your-application-payload),
> by design.

In StoreBroker, a "payload" is a combination of a json file and a zip file.  The **json** file
has the entire content of a Windows Store Submission.  This content _could_ be submitted as-is,
but usually only selected portions of it are "patched" into a new submission.  The **zip** file
usually has the icons for the localized listings, although depending on how you create your payload,
those might be missing.

To create your payload, you need to have the following (which you should already have from
following the instructions in [SETUP.md](SETUP.md):
 * [StoreBroker config file](SETUP.md#getting-your-iap-config)
 * [PDP files](SETUP.md#getting-your-iap-pdps)
 * Icons (if you use them in your listing)

> In order to use New-InAppProductSubmissionPackage, it is highly recommended that you read the
> documentation (`Get-Help New-InAppProductSubmissionPackage -Full`) and read the
> documentation in the configuration file.

Generating the submission request JSON/zip package is done with

    New-InAppProductSubmissionPackage -ConfigPath <config-path> -PDPRootPath <path> [[-Release] <string>] -PDPInclude <filename> [-PDPExclude <filename>] -ImagesRootPath <path> -OutPath <output-dir> -OutName <output-name>  

> Items in brackets ('[]') are optional.

The `-Release` parameter is technically optional, depending on how you choose to store your PDP
files. For more info, run:

    Get-Help New-InAppProductSubmissionPackage -Parameter PdpRootPath
    Get-Help New-InAppProductSubmissionPackage -Parameter Release
    
> If one of your parameters does not change often, you can specify a value in the config file and
> leave out this parameter at runtime. In this case, you should specify the remaining parameters
> to `New-InAppProductSubmissionPackage` with their parameter names.  As an example, it is
> possible to leave out `OutPath` but if you don't specify the remaining parameters by name,
> then the value of the next parameter, `OutName`, will be mapped to the `OutPath` parameter,
> causing a failure.
    
As part of its input, `New-InAppProductSubmissionPackage` expects a configuration file, which
you should have [already created](SETUP.md#getting-your-iap-config).

### IAP Commands

You'll find the layout of these commands to mimic those for Applications and Flights.
For every Get-* command there is a corresponding Format-* command that you can leverage.

> All IAP commands use the fully-spelled-out "InAppProduct".  Even though PowerShell supports tab
> completion at the commandline, aliases also exist for all of these commands as well.  Any time
> you see a command that has the phrase "InAppProduct", there exists an alias for that same command
> that replaces that phrase with "Iap" (e.g. Get-InAppProducts -> Get-Iaps).

The basic syntax looks of the update command looks like this:

    Update-InAppProductSubmission -IapId <iapId> -SubmissionDataPath ".\submission.json" -PackagePath ".\package.zip" -AutoCommit -Force

> An important thing to note though, is that if you run that exact command above, the resulting
> submission will be **identical** to the currently published submission, because you didn't tell
> `Update-InAppProductSubmission` what you specifically wanted to modify.

> If for some reason you have an existing pending submission that you want to update (as opposed
> to cloning the existing published submission), use `-SubmissionId` to specify it, and that
> will be used instead of creating a new cloned submission.  That parameter 

The following key switches can be added in any order or combination, and they will indicate what
content from the .json that you are providing needs to be added to or replaced within the
cloned submission:

 * **`-UpdateListings`** - This will update the Title and Description for each language listing,
   as well as update the icon if specified.

 * **`-UpdatePublishModeAndVisibility`** - This will change the `targetPublishMode`,
   `targetPublishDate` and `visibility` of the cloned submission to that which is specified
   in your json.  Without doing this, keep in mind that your new submission will publish the same
   way as your previous submission (be that immediately, manual or time based).

 * **`-UpdatePricingAndAvaibility`** - This will change your base pricing, market-specific pricing,
   and sales pricing info.

 * **`-UpdateProperties`** - This will update the product lifetime, content type, keywords, and tag.

> It is only ever necessary to supply the `PackagePath` if you are using `-UpdateListings` and
> those listings have icons.

In addition to those switches, there are additional optional parameters that you can provide to
fully override the publication and visibility of your IAP submission.

 * **`TargetPublishMode`** - Indicates how the submission should be published.  Setting this to any
   value other than `Default` will override the usage of `-UpdatePublishModeAndVisibility`.
     * **`Default`** - Uses the same setting as the previous submission. **This is the default.**
     * **`Manual`** - Requires you to click a button in the Dev Portal after certification completes.
     * **`Immediate`** - Publishes immediately after certification.
     * **`SpecificDate`** - Choose a date when you want it to be published.  Specify with
       `TargetPublishDate`

 * **`TargetPublishDate`** - The specific date/time that the submission should be published. To use
   this, you must specify `TargetPublishMode` as `SpecificDate`.  Using this value will
   override any value that might have been set by `-UpdatePublishModeAndVisibility`.  Users should
   provide this in local time and it will be converted automatically to UTC.

 * **`Visibility`** - Indicates the store visibility of the app once the submission has been
   published.  Setting this to any value other than `Default` will override the usage of
   `-UpdatePublishModeAndVisibility`.
     * **`Default`** - Uses the same setting as the previous submission. **This is the default.**
     * **`Public`** - Anyone can find your app in the Store.
     * **`Private`** - Hide this app in the Store. Customers with a direct link to the app's
       listing can still download it, except on Windows 8 and Windows 8.1.
     * **`Hidden`** - Hide this app and prevent acquisition. Customers with a promotional code can
       still download it on Windows 10 devices.

> Due to the nature of how the Store API works, you won't see any of your changes in the
> dev portal until your submission has entered into certification.  It doesn't have to _complete_
> certification for you to see your changes, but it does have to enter certification first.
> If it's important for you to verify your changes in the dev portal prior to publishing,
> consider publishing with the "Manual" targetPublishMode by setting that value in your
> config file and then additionally specifying the `-UpdatePublishModeAndVisibility` switch
> when calling Update-InAppProductSubmissionm, or by specifying `-TargetPublishMode Manual`.
> By using the "Manual" submission mode, you will  be forced to use the UI to complete the
> publication of your submission once it has passed certification.

`Update-InAppProductSubmission` is a convenience method that wraps a number of individual
commands into a single command.  If you want to understand exactly what it does, refer to the
previous section on ["manual submissions"](#manual-submissions) for applications (similarly-named
methods exist for IAP submissions).

**Return Values**:
`Update-InAppProductSubmission` returns back two values to you at its completion:
the new submission id, and the UploadURL.  You can use that UploadUrl to upload your submission's
.zip with `Upload-SubmissionPackage` in the event that you didn't specify the `PackagePath`
or want to upload it again.

#### Other Common IAP-related Tasks:

##### Viewing IAP's

View all the IAP's available in the dev account:

    Get-InAppProducts | Format-InAppProducts

View all the IAP's that a specific app offers:

    Get-ApplicationInAppProducts -AppId <appId> | Format-ApplicationInAppProducts


##### Creating and/or Removing IAP's

To create a new IAP:

    New-InAppProduct -ProductId <productId> -ProductType <productType> -ApplicationIds <applicationIds>

where
 * **`<productId>`** is a unique name that you provide to refer to this IAP in this API and in your
   actual application sourcecode.
 * **`<productType>`** is either `Consumable` for a "Developer managed consumable", or
   `Durable` for a "durable managed consumable".  Please note that at this time, although the
   Developer Web Portal supports the creation of "Store Managed Consumables", the Store Submission
   API _does not_.  For more information on these types, see the online
   [documentation](http://go.microsoft.com/fwlink/?LinkId=787042).
 * **`<applicationIds>`** is a comma-separated list of ApplicationIds that should be able to offer
   this IAP.

To delete an IAP:

    Remove-InAppProduct -IapId <iapId>


##### IAP Submissions

To view an existing IAP submission:

    Get-InAppProductSubmission -IapId <iapId> -SubmissionId <submissionId> | Format-InAppProductSubmission

To delete an IAP submission:

    Remove-InAppProductSubmission -IapId <iapId> -SubmissionId <submissionId>

To monitor an IAP submission:
Follow the steps in [monitoring a submission](#monitoring-a-submission), and be sure to include
**`-IapId`** in the function parameters _instead of_ **`-AppId`**.

## Using INT vs PROD

> This option is only available for Microsoft employees using the official Microsoft
> Azure Active Directory (AAD).

By default, any operation that you perform will be working against the PROD (production / public)
store server (meaning, anything that you do will affect the real world store deployment).

If you want to try using this module in the INT (internal / testing) environment (meaning that
the changes you make will never be seen by the outside world), then simply set this global session
variable before performing any operation:

    $global:SBUseInt = $true

The effect of that value will last for the duration of your session (until you close your
console window) or until you change its value to `$false`.

Just so that it's absolutely clear that operations you're performing are against INT, every API
call will output a reminder to that effect, along with a reminder on how to return to using PROD.

----------

## Telemetry

In order to track usage, gauge performance and identify areas for improvement, telemetry is
employed during execution of commands within this module (via Application Insights).  This data
is retained for a period of no more than 30 days.  For more information, refer to the
[Privacy Policy](../README.md#privacy-policy).

> You may notice some needed assemblies for communicating with Application Insights being
> downloaded on first run of a StoreBroker command within each PowerShell session.  The
> [automatic dependency downloads](SETUP.md#automatic-dependency-downloads) section of the setup
> documentation describes how you can avoid having to always re-download the telemetry assemblies
> in the future.

We request that you always leave the telemetry feature enabled, but a situation may arise where
it must be disabled for some reason.  In this scenario, you can disable telemetry by setting
the following global variable:

    $global:SBDisableTelemetry = $true

The effect of that value will last for the duration of your session (until you close your
console window), or until you change its value back to its default of `$false`.

The following type of information is collected:
 * Every major command executed (to gauge usefulness of the various commands)
 * Switches used for submission updates
 * AppId / FlightId / IapId / SubmissionId / ProductId / App Name / Appx version
 * Error codes / information

The following information is also collected, but the reported information is only reported
in the form of an SHA512 Hash (to protect PII (personal identifiable information):
 * Username
 * PackagePath
 * Invalid appx file paths

The hashing of the above items can be disabled (meaning that the plaint-text data will be reported
instead of the _hash_ of the data) by setting

    $global:SBDisablePiiProtection = $true

Similar to `SBDisableTelemetry`, the effect of this value will only last for the duration of
your session (until you close your console window), or until you change its value back to its
default of `$false`.

Finally, the Application Insights Key that the telemetry is reported to is exposed as

    $global:SBApplicationInsightsKey

It is requested that you do not change this value, otherwise the telemetry will not be reported to
us for analysis.  We expose it here for complete transparency.

> **PowerShell Tip**
>
> To save any of your configuration preferences so that they are always applied with every new
> PowerShell console window, you can add them to your PowerShell profile.  By default, the full path
> to your profile is automatically stored by PowerShell in `$profile`. From a **PowerShell console**
> run `notepad $profile`. If Notepad informs you that the file doesn't exist, let Notepad create
> the profile for you. Then, just add the relevant settings to your profile.

----------

## FAQ

*  **How do you remove packages from your app's current submission since StoreBroker doesn't do
  this automatically?**

   The Submission API does not provide enough information for StoreBroker to safely replace
   existing packages with your new ones, so it always _adds_ the packages to your submission
   (hence, the name of the switch: `-AddPackages`). If you want to clean these up from the
   commandline, jsut do the following:

        $appId = <yourAppId>
        $sub = New-ApplicationSubmission -AppId $appId  -Force
        for ($i = 0; $i -lt $sub.applicationPackages.Count; $i++) { Write-Host "`$sub.applicationPackages[$i] :" -ForegroundColor Yellow; $sub.applicationPackages[$i] }

    > At that point, you'll see all the packages in your current submisssion,
    > and the index that they're at. For any package that you want to delete, just do the following:

        $sub.applicationPackages[<index>].FileStatus = 'PendingDelete'

    > After you've updated all the packages that you want, just run the following commands:

        Set-ApplicationSubmission -AppId $appId -UpdatedSubmission $sub
        Commit-ApplicationSubmission -AppId $appId -SubmissionId ($sub.id)

* **Does StoreBroker support adding region-specific listings for languages that the app itself
  doesn't directly support? (e.g. Can I specify a listing in French, even if my app is English-only)?**

   * Yes.  All you need to do is supply a PDP (and screenshots) for that language, and
     `New-SubmissionPackage` will take care of the rest.  One thing to be aware of though is the
     name of the app for the Store listing.  The "title" for an app typically comes from the
     `DisplayName` property in the package's AppxManifest file.  This title has to be "reserved"
     in the Store for your app (via _App Management_ -> _Manage App Names_).  The PDP XML file has
     an `AppStoreName`  property that you can set a value for if you wish to override that
     default value from the package, or if your package doesn't have a localized `DisplayName`
     property in the required language.

* **I don't have the same set of screenshots for every region.  What should I do?**

   * Since the PDP is all about localization, it specifies _captions_, and captions
     then have attributes for the screenshots that they go to.  You define this set of
     captions (along with the rest of the PDP) in English, and then it gets localized
     to all the languages that you want it localized for.  If different languages need
     a different set of captions (e.g. screenshots), then that means that you simply
     need to have multiple English PDP files, and localize the different English PDP's into
     the right set of languages appropriate for that content. 

* **What I submit to the Store is the result of multiple builds.  How can I submit the results
  in a single submission?**

   * Keep in mind that the listing metadata (the PDP content) can't differ between Windows 10
     releases -- you only have one Windows 10 PDP listing, but then you can have multiple packages
     for the app, each one targeting a different min-version of the OS.  With this as a base
     understanding, the suggested approach is that you configure all of your builds to run
     `New-SubmissionPackage` with the right setup to handle the PDP. That means that any
     individual build's payload could potentially be released to the Store.

     We offer an additional command that can be used to combine two payload into a single payload
     (and if you have more than two, just daisy chain the output from one as the input to the next).
    
            Join-SubmissionPackage -MasterJsonPath <path> -AdditionalJsonPath <path> -OutJsonPath <path> -AddPackages
     
     As you'll recall, a payload is a json/zip pair.  The <path> specified in each of these
     parameters is the path to the json file, and the .zip file is determined from that same base
     name.  The resulting output will be identitical to the json/zip pair provided for
     MasterJsonPath, except that it will also include the packages that were defined in
     AdditionalJsonPath and its zip.  This payload can then be provided to StoreBroker
     for submission to the Store as a single submission.

* **Can I have different screenshots for different platforms?**

   * Yes.  Since the PDP is localization-centric, it tracks _captions_, and each caption _must_
     be associated with one or more platfrom-specific screenshots in order to be used at all.
     A caption will only be used for a specific platform if there is an attribute for that platform
     on the caption (`DesktopImage`, `MobileImage`, `XboxImage`, `SurfaceHubImage`, `HoloLensImage`)
     and the screenshot it references can be found.  You can use the same caption for multiple
     platforms (useful if your app has the same "view" on multiple platforms), and you can specify
     a caption that only references a subset of your app's platforms (useful if a "view" is only
     available on a specific subset of platforms). Therefore, it's possible that you can have a
     different number of screenshots in the store for your app, depending on the platform accessing
     the Store.  If you need to have a different set of screenshots based on language/locale,
     see the earlier FAQ on that very question.

----------
