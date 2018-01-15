# Summary of StoreBroker Commands

The following is an alphabetic listing of StoreBroker commands,
with brief descriptions. All aliases are documented. Required
inputs and return values are mentioned in some cases to provide
more clarity regarding the basic functionality of the command.

## Clear-StoreBrokerAuthentication
Clears out any cached tenantId, client id, and client secret credential from this PowerShell session. Also disables usage of the proxy server if that had been previously enabled. All future remote commands from this module will once again prompt for credentials.

## Complete-ApplicationFlightSubmission
Commits the specified application flight submission so that it can start the approval process.

Once committed, it is necessary to wait for the submission to either complete or fail the approval process before a new flight submission can be created/submitted.

**Alias:** Commit-ApplicationFlightSubmission


## Complete-ApplicationFlightSubmissionPackageRollout
Finalizes the package rollout for the specified application flight submission.

All users will now begin receiving this submission's packages.

**Alias:** Finalize-ApplicationFlightSubmissionPackageRollout

## Complete-ApplicationSubmission
Commits the specified application submission so that it can start the approval process.

Once committed, it is necessary to wait for the submission to either complete or fail the approval process before a new application submission can be created/submitted.

**Alias:** Commit-ApplicationSubmission

## Complete-ApplicationSubmissionPackageRollout
Finalizes the package rollout for the specified application submission.

All users will now begin receiving this submission's packages.

**Alias:** Finalize-ApplicationSubmissionPackageRollout

## Complete-InAppProductSubmission
Commits the specified In-App Product submission so that it can start the approval process.

Once committed, it is necessary to wait for the submission to either complete or fail the approval process before a new IAP submission can be created/submitted.

**Aliases:** Commit-IapSubmission, Commit-InAppProductSubmission

## Format-Application
Takes the result from Get-Application and presents it in a more easily-viewable manner.

## Format-ApplicationFlight
Takes the result from Get-ApplicationFlight and presents it in a more easily-viewable manner.

## Format-ApplicationFlightSubmission
Takes the result from Get-ApplicationFlightSubmission and presents it in a more easily-viewable manner.

## Format-ApplicationFlights
Takes the result from Get-ApplicationFlights and presents it in a more easily-viewable manner.

## Format-ApplicationInAppProducts
Takes the result from Get-ApplicationInAppProducts and presents it in a more easily-viewable manner.

**Alias:** Format-ApplicationIaps

## Format-ApplicationSubmission
Takes the result from Get-ApplicationSubmission and presents it in a more easily-viewable manner.

## Format-Applications
Takes the result from Get-Applications and presents it in a more easily-viewable manner.

## Format-InAppProduct
Takes the result from Get-InAppProduct and presents it in a more easily-viewable manner.

**Alias:** Format-Iap

## Format-InAppProductSubmission
Takes the result from Get-InAppProductSubmission and presents it in a more easily-viewable manner.

**Alias:** Format-IapSubmission

## Format-InAppProducts
Takes the result from Get-InAppProducts and presents it in a more easily-viewable manner.

**Alias:** Format-Iaps

## Get-Application
Retrieves the detail for the specified application associated with this developer account. This information is almost identical to the information you would see by just calling Get-Applications.

Pipe the result of this command into Format-Application for a pretty-printed display of the result.

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
Retrieves all IAP's associated with the specified application for this developer account.

Pipe the result of this command into Format-ApplicationInAppProducts for a
pretty-printed display of the results.

**Alias:** Get-ApplicationIaps

## Get-ApplicationSubmission
Gets the details of a specific application submission.

## Get-ApplicationSubmissionPackageRollout
Gets the package rollout information for the specified application submission.

## Get-ApplicationSubmissionStatus
Gets just the status of a specific application submission.

## Get-Applications
Retrieves all of the applications associated with this developer account.

For formatted output of this result, consider piping the result into Format-Applications.

## Get-FlightGroups
Launches the Dev Portal in the default web browser to display all of the available flight groups.

Viewing in the Dev Portal is necessary because there currently exists no API to programatically browse these groups.

## Get-InAppProduct
Retrieves the detail for the specified IAP associated with the developer account.
    
Pipe the result of this command into Format-InAppProduct for a pretty-printed display of the result.

**Alias:** Get-Iap

## Get-InAppProductSubmission
Retrieves the details of a specific In-App Product submission.

**Alias:** Get-IapSubmission

## Get-InAppProductSubmissionStatus
Retrieves just the status of a specific In-App Product submission.

**Alias:** Get-IapSubmissionStatus

## Get-InAppProducts
Retrieves all IAP's associated across all applications for this
developer account.

Pipe the result of this command into Format-InAppProducts for a
pretty-printed display of the results.

**Alias:** Get-Iaps

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

## New-ApplicationFlight
Creates a new flight (with associated flight groups) for an application.

## New-ApplicationFlightSubmission
Creates a submission for an existing application flight.

You cannot create a new application submission if there is an existing pending
application submission for $AppId already.  You can use -Force to work around this.

## New-ApplicationSubmission
Creates a submission for an existing application on the developer account.

This app must already have at least one *published* submission completed via the website in order for this function to work.

You cannot submit a new application submission if there is an existing pending
application submission for $AppId already.  You can use -Force to work around this.

## New-InAppProduct
Creates a new In-App Product associated with this developer account.

**Alias:** New-Iap

## New-InAppProductSubmission
Creates a submission for an existing In-App Product.

You cannot create a new In-App Product submission if there is an existing pending
application submission for this IAP already.  You can use -Force to work around this.

**Alias:** New-IapSubmission

## New-InAppProductSubmissionPackage
Top-level function for creating an in-app product submission's JSON body and .zip package for upload.

Creates the JSON body for a submission request.  Localized listing metadata
is taken from the path specified in the config file.
    
In the process of creating the JSON, the packaging tool also copies any specified
images to a .zip file.
    
The .json and .zip files generated by this tool are given a common name specified by
the -OutName parameter.

**Alias:** New-IapSubmissionPackage

## New-StoreBrokerConfigFile
Creates a new configuration file as a template for an app submission.

The full path to the new file can be provided by the -Path parameter.

**Alias:** New-PackageToolConfigFile

## New-StoreBrokerInAppProductConfigFile
Creates a new configuration file as a template for an In-App Product submission.

The full path to the new file can be provided by the -Path parameter.

**Alias:** New-StoreBrokerIapConfigFile

## New-SubmissionPackage
Top-level function for creating an application submission's JSON body
and .zip package for upload.

Creates the JSON body for a submission request.  Localized listing metadata
is taken from the path specified in the config file.
    
The .appxbundle, .appxupload, and .appx files are given via the -AppxPath parameter.
    
In the process of creating the JSON, the packaging tool also copies any specified
images and .appx files to a .zip file.
    
The .json and .zip files generated by this tool are given the common name specified by the -OutName parameter.

## Open-DevPortal
Launches the Dev Portal in the default web browser to display the requested information.
    
Sometimes users simply want to be able to see what's going on within the web portal as
opposed to the commandline.  This is designed to make that work as quickly as possible.

## Open-Store
Opens the specified app in the Windows Store.

## Remove-ApplicationFlight
Deletes the specified flight from an application in the developer's account.

## Remove-ApplicationFlightSubmission
Deletes the specified application flight submission from a developer account.

An app flight can only have a single "pending" submission at any given time,
and submissions cannot be modified via the REST API once started.
Therefore, before a new application flight submission can be submitted,
this method must be called to remove any existing pending submission.

## Remove-ApplicationSubmission
Deletes the specified application submission from a developer account.

An app can only have a single "pending" submission at any given time,
and submissions cannot be modified via the REST API once started.
Therefore, before a new application submission can be submitted,
this method must be called to remove any existing pending submission.

## Remove-InAppProduct
Deletes the specified In-App Product from the developer's account.

**Alias:** Remove-Iap

## Remove-InAppProductSubmission
Deletes the specified In-App Product submission from a developer account.

An IAP can only have a single "pending" submission at any given time,
and submissions cannot be modified via the REST API once started.
Therefore, before a new IAP submission can be submitted,
this method must be called to remove any existing pending submission.

**Alias:** Remove-IapSubmission

## Set-ApplicationFlightSubmission
Replaces the content of an existing application flight submission with the supplied submission content.

This should be called after having cloned an application flight submission via New-ApplicationFlightSubmission.
    
The ID of the submission and flight being updated/replaced will be inferred by the
ID's defined in UpdatedSubmission.

**Alias:** Replace-ApplicationFlightSubmission

**Required inputs:**
- AppID
- UpdatedSubmission \<PSObject>

**Returns:** A submission \<PSCustomObject>

## Set-ApplicationSubmission
Replaces the content of an existing application submission with the supplied submission content.

This should be called after having cloned an application submission via New-ApplicationSubmission.

The ID of the submission being updated/replaced will be inferred by the
submissionId defined in UpdatedSubmission.

**Alias:** Replace-ApplicationSubmission

**Required inputs:**
- AppID
- UpdatedSubmission \<PSObject>

**Returns:** A submission \<PSCustomObject>

## Set-InAppProductSubmission
Replaces the content of an existing In-App Product submission with the supplied submission content.

This should be called after having cloned an In-App Product submission via New-InAppProductSubmission.

The ID of the submission being updated/replaced will be inferred by the ID's defined in UpdatedSubmission.

**Aliases:** Replace-IapSubmission, Replace-InAppProductSubmission, Set-IapSubmission

**Required inputs:**
- IapId
- UpdatedSubmission \<PSObject>

**Returns:** A submission \<PSCustomObject>

## Set-StoreBrokerAuthentication
Prompts the user for their client id and secret so that they can be cached for
this PowerShell session to avoid repeated prompts.

The cached credential can always be cleared by calling Clear-StoreBrokerAuthentication.

## Set-SubmissionPackage
Uploads the package to the URL provided after calling New-ApplicationSubmission.

**Aliases:** Upload-ApplicationSubmissionPackage, Upload-SubmissionPackage

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
Auto-checks an In-App Product submission for status changes every 60 seconds with optional email notification.

The monitoring will automatically end if the submission enters a failed state, or once
its state enters the final state that its targetPublishMode allows for.

**Alias:** Start-IapSubmissionMonitor

**Required inputs:**
- IapId
- SubmissionId

**Returns:** The last retrieved submission \<PSCustomObject>

## Start-SubmissionMonitor
Auto-checks an application submission for status changes every 60 seconds with optional email notification.

The monitoring will automatically end if the submission enters a failed state, or once
its state enters the final state that its targetPublishMode allows for.

**Alias:** Start-ApplicationSubmissionMonitor

**Required inputs:**
- AppId or IapId
- SubmissionId

**Returns:** The last retrieved submission \<PSCustomObject>

## Stop-ApplicationFlightSubmissionPackageRollout
Stops the package rollout for the specified application flight submission.

All users will now begin receiving the fallback submission.

**Alias:** Halt-ApplicationFlightSubmissionPackageRollout

**Required inputs:**
- AppId
- FlightId
- SubmissionId

## Stop-ApplicationSubmissionPackageRollout
Stops the package rollout for the specified application submission.

All users will now begin receiving the fallback submission.

**Alias:** Halt-ApplicationSubmissionPackageRollout

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
Creates a new submission for an existing application on the developer account by cloning the existing submission and modifying specific parts of it. The
parts that will be modified depend solely on the switches that are passed in.

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
Creates a new submission for an existing In-App Product on the developer account
by cloning the existing submission and modifying specific parts of it. The
parts that will be modified depend solely on the switches that are passed in.

You cannot submit a new application submission if there is an existing pending
application submission for this IAP already.  You can use -Force to work around this.

**Alias:** Update-IapSubmission

**Required inputs:**
- IapId
- SubmissionDataPath

**Returns:** Array containing:
- The id for the new pending submission.
- The URL that the package needs to be uploaded to.
