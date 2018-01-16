# Summary of StoreBroker Commands (Alphabetic)

The following is an alphabetic listing of StoreBroker commands,
with brief descriptions. All aliases are documented.

Note: This is only summary information. For fuller documentation of StoreBroker commands,
use the PowerShell Get-Help command.

Some details on required inputs and return values are mentioned to provide more clarity
regarding the basic functionality of certain command. Note: if either required inputs or
a return value are mentioned, then all required inputs and any return value will be
covered.

Many StoreBroker commands directly correspond to Microsoft Store submission REST APIs.
For some commands, links are provided to documentation for the corresponding REST API or
related resources/objects.

## Clear-StoreBrokerAuthentication

<dl><dd>

Clears out any cached tenantId, client id, and client secret credential from this PowerShell session. Also disables usage of the proxy server if that had been previously enabled. All future remote commands from this module will once again prompt for credentials.

</dd></dl>

## Complete-ApplicationFlightSubmission

<dl><dd>

**Alias:** Commit-ApplicationFlightSubmission

Commits the specified application flight submission so that it can start the approval process.

Once committed, it is necessary to wait for the submission to either complete or fail the approval process before a new flight submission can be created/submitted.

</dd></dl>

## Complete-ApplicationFlightSubmissionPackageRollout

<dl><dd>

**Alias:** Finalize-ApplicationFlightSubmissionPackageRollout

Finalizes the package rollout for the specified application flight submission.

All users will now begin receiving this submission's packages.

</dd></dl>

## Complete-ApplicationSubmission

<dl><dd>

**Alias:** Commit-ApplicationSubmission

Commits the specified application submission so that it can start the approval process.

Once committed, it is necessary to wait for the submission to either complete or fail the approval process before a new application submission can be created/submitted.

Note: This completes the submission API transaction, but not necessarily the publication
of the submission. The decision whether to publish after successful certification depends
on the TargetPublishMode setting when the submission was created.

Wraps the [Commit An App Submission](https://docs.microsoft.com/en-us/windows/uwp/monetize/commit-an-app-submission) Microsoft Store Submission API.

**Required inputs:**
- AppId
- SubmissionId

**Returns:** A status. (See [JSON response body](https://docs.microsoft.com/en-us/windows/uwp/monetize/commit-an-app-submission#response).)

</dd></dl>

## Complete-ApplicationSubmissionPackageRollout

<dl><dd>

**Alias:** Finalize-ApplicationSubmissionPackageRollout

Finalizes the package rollout for the specified application submission.

All users will now begin receiving this submission's packages.

</dd></dl>

## Complete-InAppProductSubmission
**Aliases:** Commit-IapSubmission, Commit-InAppProductSubmission

Commits the specified In-App Product submission so that it can start the approval process.

Once committed, it is necessary to wait for the submission to either complete or fail the approval process before a new IAP submission can be created/submitted.

## Format-Application
Takes the result from Get-Application and presents it in a more easily-viewable manner.

## Format-ApplicationFlight
Takes the result from Get-ApplicationFlight and presents it in a more easily-viewable manner.

## Format-ApplicationFlightSubmission
Takes the result from Get-ApplicationFlightSubmission and presents it in a more easily-viewable manner.

## Format-ApplicationFlights
Takes the result from Get-ApplicationFlights and presents it in a more easily-viewable manner.

## Format-ApplicationInAppProducts
**Alias:** Format-ApplicationIaps

Takes the result from Get-ApplicationInAppProducts and presents it in a more easily-viewable manner.

## Format-ApplicationSubmission
Takes the result from Get-ApplicationSubmission and presents it in a more easily-viewable manner.

## Format-Applications
Takes the result from Get-Applications and presents it in a more easily-viewable manner.

## Format-InAppProduct
**Alias:** Format-Iap

Takes the result from Get-InAppProduct and presents it in a more easily-viewable manner.

## Format-InAppProductSubmission
**Alias:** Format-IapSubmission

Takes the result from Get-InAppProductSubmission and presents it in a more easily-viewable manner.

## Format-InAppProducts
**Alias:** Format-Iaps

Takes the result from Get-InAppProducts and presents it in a more easily-viewable manner.

## Get-Application
Retrieves the detail for the specified application associated with this developer account. This information is almost identical to the information you would see by just calling Get-Applications.

Pipe the result of this command into Format-Application for a pretty-printed display of the result.

Wraps the [Get An APP](https://docs.microsoft.com/en-us/windows/uwp/monetize/get-an-app) Microsoft Store Submission API.

**Required input:** AppId

**Returns:** An [application](https://docs.microsoft.com/en-us/windows/uwp/monetize/get-app-data#application_object) object \<PSCustomObject>

## Get-ApplicationFlight
Retrieves the detail for the specified flight associated with the application in this developer account.

Pipe the result of this command into Format-ApplicationFlight for a pretty-printed display of the result.

## Get-ApplicationFlightSubmission
Gets the details of a specific application flight submission.

## Get-ApplicationFlightSubmissionPackageRollout
Gets the package rollout information for the specified application flight submission.

## Get-ApplicationFlightSubmissionStatus
Gets just the status of a specific application flight submission.

## Get-ApplicationFlights
Retrieves all flights associated with the specified application for this developer account.

Pipe the result of this command into Format-ApplicationFlights for a pretty-printed display of the results.

## Get-ApplicationInAppProducts
**Alias:** Get-ApplicationIaps

Retrieves all IAP's associated with the specified application for this developer account.

Pipe the result of this command into Format-ApplicationInAppProducts for a
pretty-printed display of the results.

## Get-ApplicationSubmission
Gets the details of a specific application submission.

Wraps the [Get An App Submission](https://docs.microsoft.com/en-us/windows/uwp/monetize/get-an-app-submission) Microsoft Store Submission API.

**Required input:**
- AppId
- SubmissionId

**Returns:** A [submission](https://docs.microsoft.com/en-us/windows/uwp/monetize/manage-app-submissions#app-submission-object) object \<PSCustomObject>

## Get-ApplicationSubmissionPackageRollout
Gets the package rollout information for the specified application submission.

## Get-ApplicationSubmissionStatus
Gets just the status of a specific application submission.

## Get-Applications
Retrieves all of the applications associated with this developer account.

For formatted output of this result, consider piping the result into Format-Applications.

Wraps the [Get All Apps](https://docs.microsoft.com/en-us/windows/uwp/monetize/get-all-apps) Microsoft Store Submission API.

**Returns:** Array of [application](https://docs.microsoft.com/en-us/windows/uwp/monetize/get-app-data#application_object) objects \<PSCustomObject>

## Get-FlightGroups
Launches the Dev Portal in the default web browser to display all of the available flight groups.

Viewing in the Dev Portal is necessary because there currently exists no API to programatically browse these groups.

## Get-InAppProduct
**Alias:** Get-Iap

Retrieves the detail for the specified IAP associated with the developer account.
    
Pipe the result of this command into Format-InAppProduct for a pretty-printed display of the result.

## Get-InAppProductSubmission
**Alias:** Get-IapSubmission

Retrieves the details of a specific In-App Product submission.

## Get-InAppProductSubmissionStatus
**Alias:** Get-IapSubmissionStatus

Retrieves just the status of a specific In-App Product submission.

## Get-InAppProducts
**Alias:** Get-Iaps

Retrieves all IAP's associated across all applications for this
developer account.

Pipe the result of this command into Format-InAppProducts for a
pretty-printed display of the results.

## Get-SubmissionPackage
Downloads the existing package from the URL provided after calling New-ApplicationSubmission.

## Invoke-SBRestMethod
A very heavy wrapper around Invoke-WebRequest that understands the Store API and
how to perform its operation with and without console status updates.  It also
understands how to parse and handle errors from the REST calls.

## Invoke-SBRestMethodMultipleResult
A special-case wrapper around Invoke-SBRestMethod that understands GET URI's that support the 'top' and 'max' parameters.

## Join-SubmissionPackage
Merges the specified content from an ancillary StoreBroker payload into the master payload.

This is most useful in the scenario where you have packages that are coming from different
builds that should all be part of the same Store submission update.
    
Users will only specify the .json files for the two payloads, with the expectation that
the .zip will be at the same location and same name as its complementary .json file.

**Required inputs:**
- MasterJsonPath
- AdditionalJsonPath
- OutJsonPath

## New-ApplicationFlight
Creates a new flight (with associated flight groups) for an application.

**Required inputs:**
- AppId
- FriendlyName
- GroupIds (array)

## New-ApplicationFlightSubmission
Creates a submission for an existing application flight.

You cannot create a new application submission if there is an existing pending
application submission for $AppId already.  You can use -Force to work around this.

**Required inputs:**
- AppId
- FlightId

**Returns:** A submission \<PSCustomObject>

## New-ApplicationSubmission
Creates a submission for an existing application on the developer account.

This app must already have at least one *published* submission completed via the
Dev Portal in order for this function to work. The submission that is returned is
a clone of the currently-published submission.

You cannot submit a new application submission if there is an existing pending
application submission for $AppId already.  You can use -Force to work around this.

Wraps the [Create an App Submission](https://docs.microsoft.com/en-us/windows/uwp/monetize/create-an-app-submission) Microsoft Store Submission API.

**Required inputs:**
- AppId

**Returns:** A [submission](https://docs.microsoft.com/en-us/windows/uwp/monetize/manage-app-submissions#app-submission-object) object \<PSCustomObject>

## New-InAppProduct
**Alias:** New-Iap

Creates a new In-App Product associated with this developer account.

**Required inputs:**
- ProductId
- ProductType
- ApplicatonIds

## New-InAppProductSubmission
**Alias:** New-IapSubmission

Creates a submission for an existing In-App Product.

You cannot create a new In-App Product submission if there is an existing pending
application submission for this IAP already.  You can use -Force to work around this.

**Required inputs:** IapId

**Returns:** A submission \<PSCustomObject>

## New-InAppProductSubmissionPackage
**Alias:** New-IapSubmissionPackage

Top-level function for creating an in-app product submission's JSON body and .zip package for upload.

Creates the JSON body for a submission request.  Localized listing metadata
is taken from the path specified in the config file.
    
In the process of creating the JSON, the packaging tool also copies any specified
images to a .zip file.
    
The .json and .zip files generated by this tool are given a common name specified by
the -OutName parameter.

**Required inputs:** ConfigPath (existing SBConfig.json file)

## New-StoreBrokerConfigFile
**Alias:** New-PackageToolConfigFile

Creates a new configuration file as a template for an app submission.

The full path to the new file can be provided by the -Path parameter.

**Required inputs:** Path (for generated SBConfig.json file)

## New-StoreBrokerInAppProductConfigFile
**Alias:** New-StoreBrokerIapConfigFile

Creates a new configuration file as a template for an In-App Product submission.

The full path to the new file can be provided by the -Path parameter.

**Required inputs:** Path (for generated SBConfig.json file)

## New-SubmissionPackage
Top-level function for creating an application submission's JSON body
and .zip package for upload.

Creates the JSON body for a submission request.  Localized listing metadata
is taken from the path specified in the config file.
    
The .appxbundle, .appxupload, and .appx files are given via the -AppxPath parameter.
    
In the process of creating the JSON, the packaging tool also copies any specified
images and .appx files to a .zip file.
    
The .json and .zip files generated by this tool are given the common name specified by the -OutName parameter.

**Required inputs:** ConfigPath (existing SBConfig.json file)

## Open-DevPortal
Launches the Dev Portal in the default web browser to display the requested information.
    
Sometimes users simply want to be able to see what's going on within the web portal as
opposed to the commandline.  This is designed to make that work as quickly as possible.

**Required/Optional inputs:**
- AppId
- \[SubmissionId]

## Open-Store
Opens the specified app in the Windows Store.

## Remove-ApplicationFlight
Deletes the specified flight from an application in the developer's account.

**Required inputs:**
- AppId
- FlightId

## Remove-ApplicationFlightSubmission
Deletes the specified application flight submission from a developer account.

An app flight can only have a single "pending" submission at any given time,
and submissions cannot be modified via the REST API once started.
Therefore, before a new application flight submission can be submitted,
this method must be called to remove any existing pending submission.

**Required inputs:**
- AppId
- FlightId
- SubmissionId

## Remove-ApplicationSubmission
Deletes the specified application submission from a developer account.

An app can only have a single "pending" submission at any given time,
and submissions cannot be modified via the REST API once started.
Therefore, before a new application submission can be submitted,
this method must be called to remove any existing pending submission.

**Required inputs:**
- AppId
- SubmissionId

## Remove-InAppProduct
**Alias:** Remove-Iap

Deletes the specified In-App Product from the developer's account.

**Required inputs:**
- IapId

## Remove-InAppProductSubmission
**Alias:** Remove-IapSubmission

Deletes the specified In-App Product submission from a developer account.

An IAP can only have a single "pending" submission at any given time,
and submissions cannot be modified via the REST API once started.
Therefore, before a new IAP submission can be submitted,
this method must be called to remove any existing pending submission.

**Required inputs:**
- IapId
- SubmissionId

## Set-ApplicationFlightSubmission
**Alias:** Replace-ApplicationFlightSubmission

Replaces the content of an existing application flight submission with the supplied submission content.

This should be called after having cloned an application flight submission via New-ApplicationFlightSubmission.
    
The ID of the submission and flight being updated/replaced will be inferred by the
ID's defined in UpdatedSubmission.

**Required inputs:**
- AppID
- UpdatedSubmission \<PSObject>

**Returns:** A submission \<PSCustomObject>

## Set-ApplicationSubmission
**Alias:** Replace-ApplicationSubmission

Replaces the content of an existing application submission with the supplied submission content.

This should be called after having cloned an application submission via New-ApplicationSubmission.

The ID of the submission being updated/replaced will be inferred by the
submissionId defined in UpdatedSubmission.

Wraps the [Update an App Submission](https://docs.microsoft.com/en-us/windows/uwp/monetize/update-an-app-submission) Microsoft Store Submission API.

**Required inputs:**
- AppID
- UpdatedSubmission \<PSObject>

**Returns:** A [submission](https://docs.microsoft.com/en-us/windows/uwp/monetize/manage-app-submissions#app-submission-object) object \<PSCustomObject>

## Set-InAppProductSubmission
**Aliases:** Replace-IapSubmission, Replace-InAppProductSubmission, Set-IapSubmission

Replaces the content of an existing In-App Product submission with the supplied submission content.

This should be called after having cloned an In-App Product submission via New-InAppProductSubmission.

The ID of the submission being updated/replaced will be inferred by the ID's defined in UpdatedSubmission.

**Required inputs:**
- IapId
- UpdatedSubmission \<PSObject>

**Returns:** A submission \<PSCustomObject>

## Set-StoreBrokerAuthentication
Prompts the user for their client id and secret so that they can be cached for
this PowerShell session to avoid repeated prompts.

The cached credential can always be cleared by calling Clear-StoreBrokerAuthentication.

## Set-SubmissionPackage
**Aliases:** Upload-ApplicationSubmissionPackage, Upload-SubmissionPackage

Uploads the package to the URL provided after calling New-ApplicationSubmission.

**Required inputs:**
- PackagePath
- UploadUrl

## Start-ApplicationFlightSubmissionMonitor
Auto-checks an application flight submission for status changes every 60 seconds with optional email notification.

The monitoring will automatically end if the submission enters a failed state, or once
its state enters the final state that its targetPublishMode allows for.

**Required inputs:**
- AppId
- FlightId
- SubmissionId

**Returns:** The last retrieved submission \<PSCustomObject>

## Start-InAppProductSubmissionMonitor
**Alias:** Start-IapSubmissionMonitor

Auto-checks an In-App Product submission for status changes every 60 seconds with optional email notification.

The monitoring will automatically end if the submission enters a failed state, or once
its state enters the final state that its targetPublishMode allows for.

**Required inputs:**
- IapId
- SubmissionId

**Returns:** The last retrieved submission \<PSCustomObject>

## Start-SubmissionMonitor
**Alias:** Start-ApplicationSubmissionMonitor

Auto-checks an application submission for status changes every 60 seconds with optional email notification.

The monitoring will automatically end if the submission enters a failed state, or once
its state enters the final state that its targetPublishMode allows for.

**Required inputs:**
- AppId or IapId
- SubmissionId

**Returns:** The last retrieved submission \<PSCustomObject>

## Stop-ApplicationFlightSubmissionPackageRollout
**Alias:** Halt-ApplicationFlightSubmissionPackageRollout

Stops the package rollout for the specified application flight submission.

All users will now begin receiving the fallback submission.

**Required inputs:**
- AppId
- FlightId
- SubmissionId

## Stop-ApplicationSubmissionPackageRollout
**Alias:** Halt-ApplicationSubmissionPackageRollout

Stops the package rollout for the specified application submission.

All users will now begin receiving the fallback submission.

**Required inputs:**
- AppId
- SubmissionId

## Update-ApplicationFlightSubmission
Creates a new submission for an existing application flight on the developer account
by cloning the existing submission and modifying specific parts of it. The
parts that will be modified depend solely on the switches that are passed in.

This app must already have at least one *published* submission completed via
the website in order for this function to work.
You cannot submit a new application submission if there is an existing pending
application submission for this flight already.  You can use -Force to work around this.

**Required inputs:**
- AppId
- FlightId
- SubmissionDataPath

**Returns:** Array containing:
- The id for the new pending submission.
- The URL that the package needs to be uploaded to.

## Update-ApplicationFlightSubmissionPackageRollout
Updates the package rollout percentage displayed in the console for the specified application flight submission.

**Required inputs:**
- AppId
- FlightId
- SubmissionId
- Percentage

## Update-ApplicationSubmission
Creates a new submission for an existing application on the developer account by
cloning the existing submission and modifying specific parts of it. The
parts that will be modified depend solely on the switches that are passed in.

This is a high-level method that wraps other submission-related methods:
- New-ApplicationSubmission
- Set-ApplicationSubmission
- Set-SubmissionPackage
- Complete-ApplicationSubmission

This app must already have at least one *published* submission completed via
the website in order for this function to work.
You cannot submit a new application submission if there is an existing pending
application submission for $AppId already.  You can use -Force to work around this.

**Required inputs:**
- AppId
- SubmissionDataPath

**Returns:** Array containing:
- The id for the new pending submission.
- The URL that the package needs to be uploaded to.

## Update-ApplicationSubmissionPackageRollout
Updates the package rollout percentage displayed in the console for the specified application submission.

**Required inputs:**
- AppId
- SubmissionId
- Percentage

## Update-InAppProductSubmission
**Alias:** Update-IapSubmission

Creates a new submission for an existing In-App Product on the developer account
by cloning the existing submission and modifying specific parts of it. The
parts that will be modified depend solely on the switches that are passed in.

You cannot submit a new application submission if there is an existing pending
application submission for this IAP already.  You can use -Force to work around this.

**Required inputs:**
- IapId
- SubmissionDataPath

**Returns:** Array containing:
- The id for the new pending submission.
- The URL that the package needs to be uploaded to.
