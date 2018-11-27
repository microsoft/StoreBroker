# StoreBroker PowerShell Module
## Installation and Setup


----------
#### Table of Contents

*   [Overview](#overview)
*   [Installation](#installation)
    *   [ExecutionPolicy](#executionpolicy)
    *   [Choosing a Folder](#choosing-a-folder)
    *   [Get the Module](#get-the-module)
        *   [Using Git](#using-git)
        *   [Using NuGet](#using-nuget)
        *   [Downloading a Zip](#downloading-a-zip)
*   [Automatic Dependency Downloads](#automatic-dependency-downloads)
*   [Setup](#setup)
    *   [Prerequisites](#prerequisites)
    *   [Authentication](#authentication)
        *   [Getting Credentials](#getting-credentials)
        *   [Direct Authentication](#direct-authentication)
        *   [Authenticating With The Proxy](#authenticating-with-the-proxy)
    *   [Getting Your AppId](#getting-your-appid)
    *   [Getting Your PDPs](#getting-your-pdps)
        *   [Collecting Your Screenshots](#collecting-your-screenshots)
    *   [Getting Your Config](#getting-your-config)
*   [IAP Setup](#iap-setup)
    *   [Getting Your IapId](#getting-your-iapid)
    *   [Getting Your IAP PDPs](#getting-your-iap-pdps)
        *   [Collecting Your Icons](#collecting-your-icons)
    *   [Getting Your IAP Config](#getting-your-iap-config)
*   [Other Convenience Changes](#other-convenience-changes)
*   [Using StoreBroker](#using-storebroker)

----------


## Overview

This information has been moved from the primary [README.md](../README.md) since users are less
likely need to need to refer to this information again once it's been followed, unlike the rest
of the README content.

This page is rather long, but only because we go into great detail at each step to help avoid any
potential confusion. At a high level, all you're doing is:

  1. Downloading the module
  2. Getting your credentials
  3. Authenticating with those credentials
  4. Auto-generating your PDP files.
  5. Auto-generating your config file and then making some minor changes to it.

----------

## Installation

The following section describes how to configure your system for use with StoreBroker,
and lists the available options for installing the module contents.

### ExecutionPolicy

Update the `PowerShell ExecutionPolicy` to be `RemoteSigned` (which means
that PowerShell scripts that are local to your machine don't need to be signed in order to execute).
From an **Administrator** PowerShell console, run the following command:

    Set-ExecutionPolicy RemoteSigned -Force

### Choosing a Folder

You need to choose a folder that you're going to store the module in.  We recommend choosing to
use a **new sub-folder** within one of the folders in your `$env:PSModulePath`.  By default,
even if the folder doesn't exist yet,
`Join-Path -Path ([System.Environment]::GetFolderPath('MyDocuments')) -ChildPath 'WindowsPowerShell\Modules'`
is one of those folders -- this is the one that we'd recommend that you use.  If it doesn't exist yet, just
go ahead and create it:

    New-Item -Type Directory -Force -Path (Join-Path -Path ([System.Environment]::GetFolderPath('MyDocuments')) -ChildPath 'WindowsPowerShell\Modules\StoreBroker')

If you follow that advice, then the module will automatically be available in any PowerShell
console session implicitly.  If you choose to store the module somewhere else, then you will need
to run `Import-Module -Force <folder>\StoreBroker` in each new console window before any
StoreBroker command will work.

> The actual module code for StoreBroker is stored in a sub-folder called "StoreBroker", hence the
> reason that you'd have to specify the extra "\StoreBroker" in the path of the
> `Import-Module` command.  When storing the module within a `$env:PSModulePath` folder, PowerShell
> just figures that out for you.

### Get The Module

There are currently three options for installing the StoreBroker module.
We recommend the Git option, as it is the simplest for staying up-to-date with StoreBroker changes.

#### Using Git

Assuming you already have `git` on your machine, just run:

    git clone https://github.com/Microsoft/StoreBroker.git <folderFromStep2>

You'll then want to update your PowerShell profile to just run a `git pull` on that folder
every time you open your console window in order to keep it up to date.

> Your PowerShell Profile is a ps1 script that PowerShell automatically runs every time a
> new PowerShell console window is opened.

    notepad $profile

That will open your profile.  If it doesn't exist, accept Notepad's prompts to create the file.
From there, just add the following:

    Push-Location -Path "<folderFromStep2>"
    git pull
    Pop-Location

#### Using NuGet

Assuming you have the NuGet command-line utility
[installed](https://dist.nuget.org/index.html) on your machine:

    Push-Location -Path "<folderFromStep2>"
    nuget install Microsoft.Windows.StoreBroker
    Move-Item -Path ".\Microsoft.Windows.StoreBroker.*" -Destination ".\StoreBroker"

This will install the lastest available version of the StoreBroker module as a directory named
`Microsoft.Windows.StoreBroker.<version>`, then rename that directory to `StoreBroker`.

> The StoreBroker NuGet package contains *only* the scripts needed to use StoreBroker. For
> any documentation, get started with [the README.md](../README.md).

> Note that the NuGet package installation option is a *snapshot* of the StoreBroker module,
> and is more difficult to keep up-to-date. To sync your local module with the newest package,
> you will need to delete the folder created above and follow the installation instructions
> again.

#### Downloading A Zip

Download the following file to get a snapshot of the current state of the module:

  https://github.com/Microsoft/StoreBroker/archive/master.zip

Unzip that to the `<folderFromStep2>`.

Because you downloaded the file the zip, you may have to "unblock" the contents and tell your
operating system that you trust the zip's contents:

    Get-ChildItem -Recurse -File -Path "<folderFromStep2>" | ForEach-Object { Unblock-File -Path $_.FullName }

> For more information on `Unblock-File`, review [its documentation](https://technet.microsoft.com/en-us/library/hh849924.aspx)

> Note that the ZIP installation option is a *snapshot* of the StoreBroker module,
> and is more difficult to keep up-to-date. To sync your local module with the newest package,
> you will need to delete the folder created above and follow the installation instructions
> again.

----------

## Automatic Dependency Downloads

There isn't a real action required at this point for this step -- this is more for your awareness.

StoreBroker has a dependency on dll's from the following NuGet packages:

**For uploading/downloading packages**

    WindowsAzure.Storage v8.1.1: Microsoft.WindowsAzure.Storage.dll
    Microsoft.Azure.Storage.DataMovement v0.5.1: Microsoft.WindowsAzure.Storage.DataMovement.dll

**For [Telemetry](USAGE.md#telemetry)**

    Microsoft.ApplicationInsights v2.0.1: Microsoft.ApplicationInsights.dll"
    Microsoft.Diagnostics.Tracing.EventSource.Redist v1.1.24: Microsoft.Diagnostics.Tracing.EventSource.dll
    Microsoft.Bcl.Async v1.0.168.0: Microsoft.Threading.Tasks.dll

During execution of a command, when StoreBroker has need for an object from one of these dll's,
if it cannot find the dll, it will automatically download nuget.exe, then download the nuget
package that the assembly is in, and finally cache it for the duration of your PowerShell session.
If you want to avoid this step in the future, just follow the steps that it prints out to your
console window:

 1. Copy the downloaded assembly to your [module directory](#choosing-a-folder)
 2. Or copy it to a directory of your choice, and then set that directory location to
    the environment variable `$global:SBAlternateAssemblyDir`.

> **PowerShell Tip**
>
> If you use `$global:SBAlternateAssemblyDir` and want to always have that value set when you open
> a PowerShell window, you can add it to your PowerShell profile.  By default, the full path
> to your profile is automatically stored by PowerShell in `$profile`. From a **PowerShell console**
> run `notepad $profile`. If Notepad informs you that the file doesn't exist, let Notepad create
> the profile for you. Then, just add `$global:SBAlternateAssemblyDir = "<path>"` to your profile.

----------

## Setup

### Prerequisites

To initially configure StoreBroker with your Developer Account:
  1. You must have an Azure Active Directory (AAD) and you must have
     [global administrator](https://azure.microsoft.com/en-us/documentation/articles/active-directory-assign-admin-roles/) for the directory. You can create a new Azure AD [from Dev Center](https://msdn.microsoft.com/windows/uwp/publish/manage-account-users)
     permission for it.  If you already use Office 365 or other business services from Microsoft,
     you already have an AAD. Otherwise, you can
     [create a new AAD in Dev Center](https://msdn.microsoft.com/windows/uwp/publish/manage-account-users)
     for no additional charge.

  2. You must [associate your AAD with your Dev Center account](https://msdn.microsoft.com/windows/uwp/monetize/create-and-manage-submissions-using-windows-store-services#associate-an-azure-ad-application-with-your-windows-dev-center-account)
     to obtain the credentials to allow StoreBroker to access your account and perform actions on
     your behalf.

  3. The app you want to publish must already exist. The Windows Store Submission API can only
     publish updates to existing applications. You can
     [create your app in Dev Center](https://msdn.microsoft.com/windows/uwp/publish/create-your-app-by-reserving-a-name).

  4. You must have already
     [created at least one submission](https://msdn.microsoft.com/windows/uwp/publish/app-submissions)
     for your app before you can publish an update with StoreBroker.  If you have not created a
     submission, the Update attempt will fail.


> These prerequisites come directly from the
> [API Documentation](https://msdn.microsoft.com/windows/uwp/monetize/create-and-manage-submissions-using-windows-store-services).
> Refer to that documentation for additional prerequisites.

### Authentication

In order to use any network-facing command in this module, you need to be able
to authenticate against the developer account that you are trying to modify.

#### Getting Credentials

> You only need to perform this task once per user.  You'll re-use these credentials as if they
> were your username and password.

First you have to get three key pieces of information:
 * `TenantId`: This is the ID of the Azure Active Directory (AAD) connected to your developer
   account.
 * `ClientId` and `ClientSecret`: Essentially a username/password for a "user" that you create
   for StoreBroker to be able to use the API against your developer account on your behalf.

To get those values:

1. In Dev Center, go to your **Account settings**, click **Manage users**, and associate your
   organization's Dev Center account with your organization's AAD. For detailed instructions,
   see [Manage account users](https://msdn.microsoft.com/windows/uwp/publish/manage-account-users).

2. In the **Manage users** page, click **Add Azure AD applications**, add the Azure AD application
   that represents the app or service that you will use to access submissions for your Dev Center
   account, and assign it the **Manager** role. If this application already exists in your AAD,
   you can select it on the **Add Azure AD applications** page to add it to your Dev Center account.
   Otherwise, you can create a new AAD application on the **Add Azure AD applications** page.
   For more information, see [Add and manage Azure AD applications](https://msdn.microsoft.com/windows/uwp/publish/manage-account-users#add-and-manage-azure-ad-applications).

3. Return to the **Manage users** page, click the name of your Azure AD application to go to the
   application settings, and copy the **Tenant ID** and **Client ID** values.

4. Click **Add new key**. On the following screen, copy the **Key** value, which corresponds to the
   **Client secret**. You *will not* be able to access this info again after you leave this page,
   so make sure to not lose it. For more information, see the information about managing keys in
   [Add and manage Azure AD applications](https://msdn.microsoft.com/windows/uwp/publish/manage-account-users#add-and-manage-azure-ad-applications).

> These steps are directly from the
> [API Documentation](https://msdn.microsoft.com/windows/uwp/monetize/create-and-manage-submissions-using-windows-store-services).

#### Direct Authentication

The `TenantId` **must** be cached in every PowerShell session.
The `ClientId` / `ClientSecret` _can_ be cached, or you can opt to just be prompted every time
they are needed.

In order to cache the tenantId, call:

    Set-StoreBrokerAuthentication -TenantId <tenantId>

That will cache the `TenantId` for that session, and it will also prompt you for the
`ClientId` and `ClientSecret` so it can cache those in the same session as well.
If you would rather be prompted every time for those two values, you can call:

    Set-StoreBrokerAuthentication -TenantId <tenantId> -OnlyCacheTenantId

When using `Set-StoreBrokerAuthentication`, it is only caching those values for the current
PowerShell session.  They can be cleared by simply closing your PowerShell window, or by calling:

    Clear-StoreBrokerAuthentication

If you want to be use this module without requiring any user-interaction at the console,
it is necessary to leverage `Set-StoreBrokerAuthentication -Credential` and provide
the `PSCredential` object yourself.

One way to do this would be the following:
  1. `$cred = Get-Credential`
  2. Enter your credentials (`ClientId` as the username, `ClientSecret` as the password)
  3. Now you can store the password somewhere on disk securely.  Doing this will encrypt the
     password into a plain-text file, and only the same user logged-in to the exact same computer
     will be able to decrypt it.

         $cred.Password | ConvertFrom-SecureString | Set-Content -Path (Join-Path -Path ([System.Environment]::GetFolderPath('MyDocuments')) -ChildPath 'clientSecret.txt')

  4. When you want to create the credentials yourself later on and authenticate (being sure to
     replace `<tenantId>` and `<clientId>` with the proper values):

         $clientSecret = Get-Content -Path (Join-Path -Path ([System.Environment]::GetFolderPath('MyDocuments')) -ChildPath 'clientSecret.txt') | ConvertTo-SecureString
         $cred = New-Object System.Management.Automation.PSCredential "<clientId>", $clientSecret
         Set-StoreBrokerAuthentication -TenantId <tenantId> -Credential $cred

> **PowerShell Tip**
>
> If you want to always be automatically authenticated whenever you open a PowerShell window,
> you can add the code above (from Step 4) to your PowerShell profile.  By default, the full path
> to your profile is automatically stored by PowerShell in `$profile`. From a **PowerShell console**
> run `notepad $profile`. If Notepad informs you that the file doesn't exist, let Notepad create
> the profile for you. Then, just add those 3 lines of code from Step 4 into your profile.

#### Authenticating With The Proxy

For most developers / companies, the above method of authentication is sufficient.  Usually, there
are only a handful of people in any company that need access to the company's Developer account or
need the permissions to publish updates, so having a ClientId/ClientSecret assigned to each of them
is not that big of a problem.

For larger companies (like Microsoft) where there are _many_ different apps under the same developer
account being published by _many_ different people, having to create and manage a large number of
ClientId's (and ClientSecrets) becomes a security headache.

At Microsoft, we solved this problem by creating a Proxy server for the API, and we've included all
of the code and [documentation](RESTPROXY.md) in the event that you want to do the same. When using
the Proxy, the Proxy is the only one that knows the `ClientId` and `ClientSecret`, and it
performs all of the API requests on behalf of the user.  Then you only need to block access to the
Proxy using [Windows Security Groups](https://technet.microsoft.com/en-us/library/cc960640.aspx).
By default, the Proxy supports two levels of security: r/o (restricted to GET API requests) and
r/w (all API requests).

For more information on how to deploy your own Proxy, refer to its [documentation](RESTPROXY.md).

If you have a Proxy up and running, then to use it, simply call:

    Set-StoreBrokerAuthentication -UseProxy -ProxyEndpoint <proxyUri>

where `<proxyUri>` is the base part of your Uri (like `https://mystorebrokerproxy`).

That setting (being configured to use the proxy) will be stored for the duration of your session.

> **PowerShell Tip**
>
> If you want to always be automatically authenticated whenever you open a PowerShell window,
> you can add that code above to your PowerShell profile.  By default, the full path to your
> profile is automatically stored by PowerShell in `$profile`. From a **PowerShell console**
> run `notepad $profile`. If Notepad informs you that the file doesn't exist, let Notepad create
> the profile for you. Then, just add those 3 lines of code from Step 4 into your profile.

To stop authenticating with the proxy, at any time simply close your PowerShell console window, or
call:

    Clear-StoreBrokerAuthentication

### Getting Your AppId

The next steps require you to know the AppId for the App you are trying to use StoreBroker with.

If you have easy access to the Dev Portal, you can get it directly from there by:
  1. Log in to the [Dev Portal](https://developer.microsoft.com/en-us/dashboard/apps/overview)
  2. Select the app
  3. Click on **App Management**
  4. Click on **App Identity**
  5. Look towards the bottom and grab the `Store ID` that is displayed.  This is your `AppId`.

Alternatively, you can find this value directly with StoreBroker by running the following and
getting the `id` that is shown there (it looks like this: `0ABCDEF12345`).
That's your `AppId` (replace `<appName>` with all or part your app's name to limit the results):

    Get-Applications -GetAll | Where-Object primaryName -like "*<appName>*" | Format-Application

If you run into issues with this command, it's possible that you're having trouble with your search
with `Where-Object`.  Instead, just try running this:

    Get-Applications -GetAll | Format-Applications

> The Windows Store Submission API does not allow for the *creation* of new apps.
> To use StoreBroker, you must have already created **and published** an app submission via the
> Dev Center web portal first.  Once that happens, you should be able to continue using StoreBroker
> as described.

### Getting Your PDPs

A major benefit of using the StoreBroker to do your updates, is that it can submit all of the
metadata (app description, feature list, captions, screenshots, etc...) automatically.
However, in order to create the "payload" (json and zip) required to use the API, it needs to have
a uniform way of getting that metadata content.

Enter the [PDP](PDP.md) XML format.  PDP stands for Product Description Page, and the PDP.xml file
is a schema that Microsoft uses internally to store all of the localizable metadata for an
application.  That XML file then gets localized into every language that the application has a Store
listing for.

> You don't _have_ to use PDP files to store your metadata in the event that you already have a
> different method of localization.  However, if you don't choose to use the PDP format, then
> you will have to write your own version of `New-SubmissionPackage` in order to create the
> payload (json and zip) that the other StoreBroker commands require.

You can read [PDP.md](PDP.md) for greater detail on PDP files.  Right now, we just need to get you
started by generating your app's PDP files based on your current published submission.

    .\Extensions\ConvertFrom-ExistingSubmission.ps1 -AppId <appId> -Release <release> -PdpFileName <pdpFileName> -OutPath <outPath>

Where:
  * `<appId>` is your app's ID.

  * `<release>` is the name of this release.  Many teams name their releases as `YYMM`
    (depending on how often they release).  This value will be added to each of the PDP's that are
    generated, and will impact the expected location of the screenshots being referenced.  More on
    that folder structure in the [next section](#getting-your-config).

  * `<pdpFileName>` - The name you want to give to the PDP files -- people often use `PDP.xml`.

  * `<outPath>` - The folder that the PDP files should be stored in.  _Langcode_ sub-folders will
    be created for storing the PDP files, as `New-SubmissionPackage` depends on that folder
    structure for determining what _langcode_ a PDP file is associated with.

#### Collecting Your Screenshots

The API does not provide any ability to download the existing screenshots for an application.  When
the script completes, it will tell you what images it expects you to gather up manually, and the
folder structure that you should be putting them in to.

### Getting Your Config

Every project should have its own StoreBroker config file.  The config file has two parts to it:

 * The top part lets you specify parameters to `New-SubmissionPackage` that remain static,
   so that you don't have to specify them at the commandline each time.
 * The bottom part lets you specify Application submission properties that generally remain static
   between submissions and aren't localized.

#### Config Setup Steps

1. Now run `New-StoreBrokerConfigFile -Path (Join-Path -Path ([System.Environment]::GetFolderPath('Desktop')) -ChildPath 'SBConfig.json') -AppId <AppId>`,
   substituting in your [AppId](#getting-your-appid), and that will generate a pre-populated config
   file to your desktop, based on the current configuration of your app in the Store. (Feel free
   to name this file whatever you want).

2. Once you have the config, review all of the app properties at the bottom half of the file.
   These are the values for these properties as they are configured for your app in the Store today.
   Some users have realized that the values in the Store (and thus in this file) are not what they
   expected, so it's worth checking them here and fixing them if need be.  (If you do change any of
   these properties, you'll need to use the appropriate _switch_ to
   [`Update-ApplicationSubmission`](USAGE.md#creating-a-new-application-submission) later on
   to make sure that your changes are applied).

3. Now you need to set the `New-SubmissionPackage` parameter values at the top half of the file.
   These parameter values are very well documented within the config file, but here's an additional
   crib sheet for what you'll _likely_ want to change:

    i. `PDPRootPath` and `Release` are related - If you'll be getting the localized PDP files
     dynamically during your build from a localization service/process, leave both blank and
     only specify `PDPRootPath` at the commandline so that you can use environment variables
     to reference the local path, and move on to "**ii**".

     Otherwise, it's necessary for you to provide the path that the PDP's can be found.
     You'll do this with a combination of these two config values.  The general idea
     is that you have a root folder for PDP's that contains sub-folders named after each
     different release.  The PDP's would actually be contained in the release-named sub-folders.
     Let's assume that your PDP files can be found here:

           \\my\file\share\1606\
                                en-us\PDP.xml
                                fr-fr\PDP.xml
                                es-es\PDP.xml

     In that scenario, you can either do this:

           PDPRootPath: \\my\file\share\1606\
           Release: <null>

     or

           PDPRootPath: \\my\file\share\
           Release: 1606

    Both methods result in accessing the files from the same location.  It just depends
    on how you intend to maintain your PDP files.  If the same share location will always
    be updated with the most recent PDP's, use the first method.  If you _will_ be using
    release-named sub-folders to organize your PDP's, then you may wish to use the second
    option, and you can either choose to update your config file with the new release name
    every time it changes, or provide it at the commandline instead. Your choice.

    > Remember that you have to escape any backslashes used in the config file.

    ii. `PDPInclude` - Update this to have the name (or names) of the PDP files that you want to
    consume.  If we were following the example above, we'd specify `PDP.xml` here.

    iii. `PDPExclude` - For most people, you'll want to leave this empty.

    iv. `LanguageExclude` - Add languages to here if there are language sub-folders in
    `PDPRootPath` that your app doesn't support.  We've added "default" in there for you
    since that's commonly in the loc output for Microsoft builds, but doesn't represent a real
    language (these sub-folders need to use the same lang-codes that the Store uses).

    v. `MediaRootPath` - Point this to where your app screenshots are stored.  Please note that
    this should point to a root location for the screenshots, and we expect there to be
    sub-folders for each release within here.

    If you had a folder structure like this:

               \\share\MyApp\Images\201605\en-us\
                   Screenshot1.png
                   Screenshot2.png
               \\share\MyApp\Images\201605\fr-fr\
                   Screenshot1.png
                   Screenshot2.png

    you would specify `\\share\MyApp\Images\` as your `MediaRootPath`, and your PDP file
    would set `201605` as the `Release` attribute (at the very top of the file).
    `New-SubmissionPackage` would then combine those together at runtime to get the
    full path to these images.

    > Remember that you have to escape any backslashes used in the config file.

    vi. `PackagePath` - Follow the guidance in the help comments to correctly specify where the appx
    packages for your app will be found.  Since this is likely part of your build output, you'll
    likely specify this at the commandline with environment variables, as opposed to setting a
    path in the config file.

    vii. `OutPath` - Update this to be where you want it to drop the .json/.zip bundle.  If this
    will be a location that uses an environment variable, then you'll need to specify it at the
    commandline instead.

    viii. `OutName` - Update this to specify the root name for your json/zip files.

4. [Optional] Check this file in side-by-side with your code for version control support.

----------

## IAP Setup

The [prerequisites](#prerequisites) and [authentication steps](#authentication) are identical here
as they are for applications (as explained above), and so they will not be repeated here.

### Getting Your IapId

The next steps require you to know the IapId for the In-App Product ("add on") that you are trying
to use with StoreBroker.

To run the next command, you'll need your [AppId](#getting-your-appid) from above.
Run the following and get the `ID` that is shown there (it looks like this: `0ABCDEF12345`).
That's your `IapId`.

    Get-ApplicationInAppProducts -AppId <appId> -GetAll | Format-ApplicationInAppProducts

> The Windows Store Submission API does not currently support IAP's that are "Store Managed Consumables."
> You will not be able to use StoreBroker to manage that type of IAP until the API has been updated.
> Additionally, if your application _has_ one of those IAPS's, the above command will fail with
> a `409` error.  In this scenario, you'll need to manually get the `IapId` by copying it from the
> URL of the Dev Center web portal when trying to edit that IAP.

### Getting Your IAP PDPs

A major benefit of using the StoreBroker to do your updates, is that it can submit all of the
metadata (title, description, icons, etc...) automatically.
However, in order to create the "payload" (json and zip) required to use the API, it needs to have
a uniform way of getting that metadata content.

Enter the [PDP](PDP.md) XML format.  PDP stands for Product Description Page, and the PDP.xml file
is a schema that Microsoft uses internally to store all of the localizable metadata for an
In-App Product.  That XML file then gets localized into every language that the application has a
Store listing for.

> You don't _have_ to use PDP files to store your metadata in the event that you already have a
> different method of localization.  However, if you don't choose to use the PDP format, then
> you will have to write your own version of `New-InAppProductSubmissionPackage` in order to
> create the payload (json and zip) that the other StoreBroker commands require.

You can read [PDP.md](PDP.md) for greater detail on PDP files.  Right now, we just need to get you
started by generating your IAP's PDP files based on your current published (or pending) submission.

    .\Extensions\ConvertFrom-ExistingIapSubmission.ps1 -IapId <iapId> -Release <release> -PdpFileName <pdpFileName> -OutPath <outPath>

Where:
  * `<iapId>` is your IAP's ID.

  * `<release>` is the name of this release.  Many teams name their releases as `YYMM`
    (depending on how often they release).  This value will be added to each of the PDP's that are
    generated, and will impact the expected location of the screenshots being referenced.  More on
    that folder structure in the [next section](#getting-your-config).

  * `<pdpFileName>` - The name you want to give to the PDP files -- people often use `PDP.xml`.

  * `<outPath>` - The folder that the PDP files should be stored in.  _Langcode_ sub-folders will
    be created for storing the PDP files, as `New-InAppProductSubmissionPackage` depends on
    that folder structure for determining what _langcode_ a PDP file is associated with.

#### Collecting Your Icons

The API does not provide any ability to download the existing icons for an IAP listing.  When
the script completes, it will tell you what icons it expects you to gather up manually, and the
folder structure that you should be putting them in to.

### Getting Your IAP Config

Every IAP should have its own StoreBroker config file.  The config file has two parts to it:

 * The top part lets you specify parameters to `New-InAppProductSubmissionPackage` that remain
   static, so that you don't have to specify them at the commandline each time.
 * The bottom part lets you specify In-App Product submission properties that generally remain static
   between submissions and aren't localized.

#### IAP Config Setup Steps

1. Now run `New-StoreBrokerInAppProductConfigFile -Path (Join-Path -Path ([System.Environment]::GetFolderPath('Desktop')) -ChildPath 'SBConfig.json') -IapId <IapId>`,
   substituting in your [IapId](#getting-your-iapid), and that will generate a pre-populated config
   file to your desktop, based on the current configuration of your IAP in the Store. (Feel free
   to name this file whatever you want).

2. Once you have the config, review all of the properties at the bottom half of the file.
   These are the values for these properties as they are configured for your IAP in the Store today.
   Some users have realized that the values in the Store (and thus in this file) are not what they
   expected, so it's worth checking them here and fixing them if need be.  (If you do change any of
   these properties, you'll need to use the appropriate _switch_ to
   [`Update-InAppProductSubmission`](USAGE.cmd#iap-commands) later on to make sure that your
   changes are applied).

3. Now you need to set the `New-InAppProductSubmissionPackage` parameter values at the top half
   of the file.  These parameter values are very well documented within the config file, but for
   more detailed information on what you'll _likely_ want to change, refer to **step 3** in
   [Config Setup Steps](#config-setup-steps) above.

4. [Optional] Check this file in side-by-side with your code for version control support.

----------

## Other Convenience Changes

Well, you did it.  You're now _fully_ setup to start using StoreBroker.

Congratulations!

While not required, there are other things that you can do to make your usage even easier.

* **Global variable for your AppId**: You need to provide your `appId` quite a bit when using
  StoreBroker.  Instead of having to remember it or constantly look it up, why not just create a
  global variable for it in your `$profile` so that you can just refer to it by name with
  tab-completion?  Just run `notepad $profile` to open up your profile, and add the following:

        $global:appName = '<appId>'

  set `appName` to whatever you want, and replace `<appId>` with your actual
  [appId](#getting-your-appid).  Then, in any new PowerShell console window, you can just start
  typing `$ap<tab>` and it should auto-complete the variable name for you (no need to start with
  `$global:`).

* **Global variable for other Ids or paths**: Following similar logic as above, you might want to
  create global variables to reference other common Ids (flightId, IapId), paths (like the path to
  your StoreBroker config file), etc...

----------

## Using StoreBroker

To learn how to use StoreBroker now that it's all setup, head on over to [README.md](../README.md).
