# Summary of StoreBroker Commands (Functional Groupings)

The following is an listing of StoreBroker commands with brief descriptions, grouped by
areas of functionality. All aliases are documented.

Note: This is only summary information. For fuller documentation of StoreBroker commands,
use the PowerShell Get-Help command.

Some details on required inputs and return values are mentioned to provide more clarity
regarding the basic functionality of certain command. Note: if either required inputs or
a return value are mentioned, then all required inputs and any return value will be
covered.

Many StoreBroker commands directly correspond to Microsoft Store submission REST APIs.
For some commands, links are provided to documentation for the corresponding REST API or
related resources/objects.

-----
## Working with Applications, Flights and In-App Products

### Get-Application

### Get-ApplicationFlight

### Get-ApplicationFlights

### Get-ApplicationInAppProducts

### Get-Applications

### Get-FlightGroups

### Get-InAppProduct

### Get-InAppProducts

### New-ApplicationFlight

### New-InAppProduct

### Remove-ApplicationFlight

### Remove-InAppProduct

-----
## Working with Application Submissions

### Complete-ApplicationSubmission
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

### Complete-ApplicationSubmissionPackageRollout

### Get-ApplicationSubmission
Gets the details of a specific application submission.

Wraps the [Get An App Submission](https://docs.microsoft.com/en-us/windows/uwp/monetize/get-an-app-submission) Microsoft Store Submission API.

**Required input:**
- AppId
- SubmissionId

**Returns:** A [submission](https://docs.microsoft.com/en-us/windows/uwp/monetize/manage-app-submissions#app-submission-object) object \<PSCustomObject>

### Get-ApplicationSubmissionPackageRollout

### Get-ApplicationSubmissionStatus

### Get-SubmissionPackage

### Join-SubmissionPackage

### New-ApplicationSubmission
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

### New-StoreBrokerConfigFile

### New-SubmissionPackage

### Remove-ApplicationSubmission

### Set-ApplicationSubmission

### Set-SubmissionPackage

### Stop-ApplicationSubmissionPackageRollout

### Update-ApplicationSubmission

### Update-ApplicationSubmissionPackageRollout

-----
## Working with Application Flight Submissions

### Complete-ApplicationFlightSubmission

### Complete-ApplicationFlightSubmissionPackageRollout

### Get-ApplicationFlightSubmission

### Get-ApplicationFlightSubmissionPackageRollout

### Get-ApplicationFlightSubmissionStatus

### New-ApplicationFlightSubmission

### Remove-ApplicationFlightSubmission

### Set-ApplicationFlightSubmission

### Stop-ApplicationFlightSubmissionPackageRollout

### Update-ApplicationFlightSubmission

### Update-ApplicationFlightSubmissionPackageRollout

-----
## Working with In-App Product Submissions

### Complete-InAppProductSubmission

### Get-InAppProductSubmission

### Get-InAppProductSubmissionStatus

### New-InAppProductSubmission

### New-InAppProductSubmissionPackage

### New-StoreBrokerInAppProductConfigFile

### Remove-InAppProductSubmission

### Set-InAppProductSubmission

### Update-InAppProductSubmission

-----
## Utility: Account Interaction

### Clear-StoreBrokerAuthentication

### Set-StoreBrokerAuthentication

-----
## Utility: User Interaction

### Format-Application

### Format-ApplicationFlight

### Format-ApplicationFlightSubmission

### Format-ApplicationFlights

### Format-ApplicationInAppProducts

### Format-ApplicationSubmission

### Format-Applications

### Format-InAppProduct

### Format-InAppProductSubmission

### Format-InAppProducts

### Open-DevPortal

### Open-Store

### Start-ApplicationFlightSubmissionMonitor

### Start-InAppProductSubmissionMonitor

### Start-SubmissionMonitor

-----
## Utility: Other

### Invoke-SBRestMethod

### Invoke-SBRestMethodMultipleResult

