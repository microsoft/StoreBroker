# Copyright (C) Microsoft Corporation.  All rights reserved.

function Get-Applications
{
<#
    .SYNOPSIS
        Retrieves all of the applications associated with this developer account.

    .DESCRIPTION
        Retrieves all of the applications associated with this developer account.
        For formatted output of this result, consider piping the result into Format-Applications.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER MaxResults
        The number of applications that should be returned in the query.
        Defaults to 100.

    .PARAMETER StartAt
        The 0-based index (of all apps within your account) that the returned
        results should start returning from.
        Defaults to 0.

    .PARAMETER AccessToken
        If provided, this will be used as the AccessToken for authentication with the
        REST Api as opposed to requesting a new one.

    .PARAMETER GetAll
        If this switch is specified, the cmdlet will automatically loop in batches
        to get all of the applications in this account.  Using this will ignore
        the provided value for -StartAt, but will use the value provided for
        -MaxResults as its per-query limit.
        WARNING: This might take a while depending on how many applications are in
        your developer account.

    .PARAMETER NoStatus
        If this switch is specified, long-running commands will run on the main thread
        with no commandline status update.  When not specified, those commands run in
        the background, enabling the command prompt to provide status information.

    .EXAMPLE
        Get-Applications
        Gets the first 100 applications associated with this developer account,
        with the console window showing progress while awaiting the response
        from the REST request.

    .EXAMPLE
        Get-Applications -NoStatus
        Gets the first 100 applications associated with this developer account,
        but the request happens in the foreground and there is no additional status
        shown to the user until a response is returned from the REST request.

    .EXAMPLE
        Get-Applications 500
        Gets the first 500 applications associated with this developer account,
        with the console window showing progress while awaiting the response
        from the REST request.

    .EXAMPLE
        Get-Applications 10 -StartAt 50
        Gets the next 10 apps in the developer account starting with the 51st app
        (since it's a 0-based index) with the console window showing progress while
        awaiting the response from the REST request.

    .EXAMPLE
        $apps = Get-Applications
        Retrieves the first 100 applications associated with this developer account,
        and saves the results in a variable called $apps that can be used for
        further processing.

    .EXAMPLE
        Get-Applications -NoStatus | Format-Applications
        Pretty-print the results by piping them into Format-Applications.
#>
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "", Justification="Designed to mimic the actual API.")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="Methods called within here make use of PSShouldProcess, and the switch is passed on to them inherently.")]
    param(
        [ValidateScript({if ($_ -gt 0) { $true } else { throw "Must be greater than 0." }})]
        [int] $MaxResults = 100,

        [ValidateScript({if ($_ -ge 0) { $true } else { throw "Must be greater than or equal to 0." }})]
        [int] $StartAt = 0,

        [string] $AccessToken = "",

        [switch] $GetAll,

        [switch] $NoStatus
    )

    Write-Log -Message "[$($MyInvocation.MyCommand.Module.Version)] Executing: $($MyInvocation.Line.Trim())" -Level Verbose

    $params = @{
        "UriFragment" = "applications"
        "Description" = "Getting applications"
        "MaxResults" = $MaxResults
        "StartAt" = $StartAt
        "AccessToken" = $AccessToken
        "TelemetryEventName" = "Get-Applications"
        "GetAll" = $GetAll
        "NoStatus" = $NoStatus
    }

    return (Invoke-SBRestMethodMultipleResult @params)
}

function Format-Applications
{
<#
    .SYNOPSIS
        Pretty-prints the results of Get-Applications

    .DESCRIPTION
        This method is intended to be used by callers of Get-Applications.
        It takes the result from Get-Applications and presents it in a more easily
        viewable manner.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER ApplicationsData
        The output returned from Get-Applications.
        Supports Pipeline input.

    .EXAMPLE
        Format-Applications $(Get-Applications)
        Explicitly gets the result from Get-Applications and passes that in as the input
        to Format-Applications for pretty-printing.

    .EXAMPLE
        Get-Applications | Format-Applications
        Pipes the result of Get-Applications directly into Format-Applications for pretty-printing.
#>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "", Justification="Formatting method designed to mimic the actual API method.")]
    param(
        [Parameter(
            Mandatory,
            ValueFromPipeline)]
        [PSCustomObject] $ApplicationsData
    )

    begin
    {
        Set-TelemetryEvent -EventName Format-Applications

        Write-Log -Message "Displaying Applications..." -Level Verbose

        $publishedDateField = @{ label="firstPublishedDate"; Expression={ Get-Date -Date $_.firstPublishedDate -Format G }; }
        $publishedSubmissionField = @{ label="lastPublishedSubmission"; Expression={ $_.lastPublishedApplicationSubmission.id }; }
        $pendingSubmissionField = @{ label="pendingSubmission"; Expression={ if ($null -eq $_.pendingApplicationSubmission.id) { "---" } else { $_.pendingApplicationSubmission.id } }; }

        $apps = @()
    }

    process
    {
        $apps += $ApplicationsData
    }

    end
    {
        Write-Log -Message $($apps | Sort-Object primaryName | Format-Table primaryName, id, packagefamilyname, $publishedDateField, $publishedSubmissionField, $pendingSubmissionField | Out-String)
    }
}

function Get-Application
{
<#
    .SYNOPSIS
        Retrieves the detail for the specified application associated with this
        developer account.

    .DESCRIPTION
        Retrieves the detail for the specified application associated with this
        developer account.  This information is almost identical to the information
        you would see by just calling Get-Applications.
        Pipe the result of this command into Format-Application for a pretty-printed display
        of the result.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER AppId
        The Application ID for the application that you want to retrieve the information
        about.

    .PARAMETER AccessToken
        If provided, this will be used as the AccessToken for authentication with the
        REST Api as opposed to requesting a new one.

    .PARAMETER NoStatus
        If this switch is specified, long-running commands will run on the main thread
        with no commandline status update.  When not specified, those commands run in
        the background, enabling the command prompt to provide status information.

    .EXAMPLE
        Get-Application 0ABCDEF12345
        Gets all of the applications associated with this developer account,
        with the console window showing progress while awaiting the response
        from the REST request.

    .EXAMPLE
        Get-Application 0ABCDEF12345 -NoStatus
        Gets all of the applications associated with this developer account,
        but the request happens in the foreground and there is no additional status
        shown to the user until a response is returned from the REST request.

    .EXAMPLE
        $app = Get-Application 0ABCDEF12345
        Retrieves all of the applications associated with this developer account,
        and saves the results in a variable called $apps that can be used for
        further processing.

    .EXAMPLE
        Get-Application 0ABCDEF12345 | Format-Application
        Gets all of the applications associated with this developer account, and then
        displays it in a pretty-printed, formatted result.
#>
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="Methods called within here make use of PSShouldProcess, and the switch is passed on to them inherently.")]
    param(
        [Parameter(Mandatory=$true)]
        [string] $AppId,

        [string] $AccessToken = "",

        [switch] $NoStatus
    )

    Write-Log -Message "[$($MyInvocation.MyCommand.Module.Version)] Executing: $($MyInvocation.Line.Trim())" -Level Verbose

    $telemetryProperties = @{ [StoreBrokerTelemetryProperty]::AppId = $AppId }

    $params = @{
        "UriFragment" = "applications/$AppId"
        "Method" = "Get"
        "Description" = "Getting data for AppId: $AppId"
        "AccessToken" = $AccessToken
        "TelemetryEventName" = "Get-Application"
        "TelemetryProperties" = $telemetryProperties
        "NoStatus" = $NoStatus
    }

    return (Invoke-SBRestMethod @params)
}

function Format-Application
{
<#
    .SYNOPSIS
        Pretty-prints the results of Get-Application

    .DESCRIPTION
        This method is intended to be used by callers of Get-Application.
        It takes the result from Get-Application and presents it in a more easily
        viewable manner.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER ApplicationData
        The output returned from Get-Application.
        Supports Pipeline input.

    .EXAMPLE
        Format-Application $(Get-Application 0ABCDEF12345)
        Explicitly gets the result from Get-Application and passes that in as the input
        to Format-Application for pretty-printing.

    .EXAMPLE
        Get-Application 0ABCDEF12345 | Format-Application
        Pipes the result of Get-Application directly into Format-Application for pretty-printing.
#>
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory,
            ValueFromPipeline)]
        [PSCustomObject] $ApplicationData
    )

    begin
    {
        Set-TelemetryEvent -EventName Format-Application

        Write-Log -Message "Displaying Application..." -Level Verbose

        $output = @()
    }

    process
    {
        $output += ""
        $output += "Primary Name              : $($ApplicationData.primaryName)"
        $output += "Id                        : $($ApplicationData.id)"
        $output += "Package Family Name       : $($ApplicationData.packageFamilyName)"
        $output += "Supports Advanced Listings: $($ApplicationData.hasAdvancedListingPermission)"
        $output += "First Published Date      : $(Get-Date -Date $ApplicationData.firstPublishedDate -Format R)"
        $output += "Last Published Submission : $($ApplicationData.lastPublishedApplicationSubmission.id)"
        $output += "Pending Submission        : $(if ($null -eq $ApplicationData.pendingApplicationSubmission.id) { "---" } else { $ApplicationData.pendingApplicationSubmission.id } )"
    }

    end
    {
       Write-Log -Message $output
    }
}

function Get-ApplicationSubmission
{
<#
    .SYNOPSIS
        Retrieves the details of a specific application submission.

    .DESCRIPTION
        Gets the details of a specific application submission.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER AppId
        The Application ID for the application that you want to retrieve the information
        about.

    .PARAMETER SubmissionId
        The specific submission that you want to retrieve the information about.

    .PARAMETER AccessToken
        If provided, this will be used as the AccessToken for authentication with the
        REST Api as opposed to requesting a new one.

    .PARAMETER NoStatus
        If this switch is specified, long-running commands will run on the main thread
        with no commandline status update.  When not specified, those commands run in
        the background, enabling the command prompt to provide status information.

    .EXAMPLE
        Get-ApplicationSubmission 0ABCDEF12345 1234567890123456789
        Gets all of the detail known for this application submission,
        with the console window showing progress while awaiting the response
        from the REST request.

    .EXAMPLE
        Get-ApplicationSubmission 0ABCDEF12345 1234567890123456789 -NoStatus
        Gets all of the detail known for this application submission,
        but the request happens in the foreground and there is no additional status
        shown to the user until a response is returned from the REST request.

    .EXAMPLE
        $submission = Get-ApplicationSubmission 0ABCDEF12345 1234567890123456789
        Retrieves all of the applications submission detail, and saves the results in
        a variable called $submission that can be used for further processing.

    .EXAMPLE
        Get-ApplicationSubmission 0ABCDEF12345 1234567890123456789 | Format-ApplicationSubmission
        Pretty-print the results by piping them into Format-ApplicationSubmission.
#>
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="Methods called within here make use of PSShouldProcess, and the switch is passed on to them inherently.")]
    param(
        [Parameter(Mandatory)]
        [string] $AppId,

        [Parameter(Mandatory)]
        [string] $SubmissionId,

        [string] $AccessToken = "",

        [switch] $NoStatus
    )

    Write-Log -Message "[$($MyInvocation.MyCommand.Module.Version)] Executing: $($MyInvocation.Line.Trim())" -Level Verbose

    $telemetryProperties = @{
        [StoreBrokerTelemetryProperty]::AppId = $AppId
        [StoreBrokerTelemetryProperty]::SubmissionId = $SubmissionId
    }

    $params = @{
        "UriFragment" = "applications/$AppId/submissions/$SubmissionId"
        "Method" = "Get"
        "Description" = "Getting data for AppId: $AppId SubmissionId: $SubmissionId"
        "AccessToken" = $AccessToken
        "TelemetryEventName" = "Get-ApplicationSubmission"
        "TelemetryProperties" = $telemetryProperties
        "NoStatus" = $NoStatus
    }

    return (Invoke-SBRestMethod @params)
}

function Format-ApplicationSubmission
{
<#
    .SYNOPSIS
        Pretty-prints the results of Get-ApplicationSubmission

    .DESCRIPTION
        This method is intended to be used by callers of Get-ApplicationSubmission.
        It takes the result from Get-ApplicationSubmission and presents it in a more easily
        viewable manner.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER ApplicationSubmissionData
        The output returned from Get-ApplicationSubmission.
        Supports Pipeline input.

    .EXAMPLE
        Format-ApplicationSubmission $(Get-ApplicationSubmission 0ABCDEF12345 1234567890123456789)
        Explicitly gets the result from Get-ApplicationSubmission and passes that in as the input
        to Format-ApplicationSubmission for pretty-printing.

    .EXAMPLE
        Get-ApplicationSubmission 0ABCDEF12345 1234567890123456789 | Format-ApplicationSubmission
        Pipes the result of Get-ApplicationSubission directly into Format-ApplicationSubmuission for pretty-printing.
#>
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory,
            ValueFromPipeline)]
        [PSCustomObject] $ApplicationSubmissionData
    )

    begin
    {
        Set-TelemetryEvent -EventName Format-ApplicationSubmission

        Write-Log -Message "Displaying Application Submission..." -Level Verbose

        $indentLength = 5
        $output = @()
    }

    process
    {
        # Normalize the trailer data by language so that the data can be displayed
        # with the rest of the language listing information
        $trailers = $ApplicationSubmissionData.trailers
        $trailerByLang = [ordered]@{}
        foreach ($trailer in $ApplicationSubmissionData.trailers)
        {
            foreach ($lang in ($trailer.trailerAssets | Get-Member -type NoteProperty).Name)
            {
                $trailerData = [PSCustomObject]@{
                    fileName = $trailer.videoFileName
                    fileId = $trailer.videoFileId
                    title = $trailer.trailerAssets.$lang.title
                    screenshot = $trailer.trailerAssets.$lang.imageList[0].fileName
                    screenshotDescription = $trailer.trailerAssets.$lang.imageList[0].description
                }

                if ($null -eq $trailerByLang[$lang])
                {
                    $trailerByLang[$lang] = @()
                }

                $trailerByLang[$lang] += $trailerData
            }
        }

        $output += ""
        $output += "Submission Id                       : $($ApplicationSubmissionData.id)"
        $output += "Friendly Name                       : $($ApplicationSubmissionData.friendlyName)"
        $output += "Application Category                : $($ApplicationSubmissionData.applicationCategory)"
        $output += "Visibility                          : $($ApplicationSubmissionData.visibility)"
        $output += "Publish Mode                        : $($ApplicationSubmissionData.targetPublishMode)"
        if ($null -ne $ApplicationSubmissionData.targetPublishDate)
        {
            $output += "Publish Date                        : $(Get-Date -Date $ApplicationSubmissionData.targetPublishDate -Format R)"
        }

        $output += "Automatic Backup Enabled            : $($ApplicationSubmissionData.automaticBackupEnabled)"
        $output += "Can Install On Removable Media      : $($ApplicationSubmissionData.canInstallOnRemovableMedia)"
        $output += "Has External InApp Products         : $($ApplicationSubmissionData.hasExternalInAppProducts)"
        $output += "Meets Accessibility Guidelines      : $($ApplicationSubmissionData.meetAccessibilityGuidelines)"
        $output += "Notes For Certification             : $($ApplicationSubmissionData.notesForCertification)"
        $output += "Enterprise Licensing                : $($ApplicationSubmissionData.enterpriseLicensing)"
        $output += "Available To Future Device Families : $($ApplicationSubmissionData.allowMicrosoftDecideAppAvailabilityToFutureDeviceFamilies)"
        $output += ""

        $output += "Pricing                             :"
        $output += $ApplicationSubmissionData.pricing | Format-SimpleTableString -IndentationLevel $indentLength
        $output += ""

        $output += "Hardware Preferences                :"
        $output += $ApplicationSubmissionData.hardwarePreferences | Format-SimpleTableString -IndentationLevel $indentLength
        $output += ""

        $output += "Allow Target Future Device Families :"
        $output += $ApplicationSubmissionData.allowTargetFutureDeviceFamilies | Format-SimpleTableString -IndentationLevel $indentLength
        $output += ""

        $output += "File Upload Url                     : {0}" -f $(if ($ApplicationSubmissionData.fileUploadUrl) { $ApplicationSubmissionData.fileUploadUrl } else { "<None>" })
        $output += ""

        $output += "Application Packages                : {0}" -f $(if ($ApplicationSubmissionData.applicationPackages.count -eq 0) { "<None>" } else { "" })
        $output += $ApplicationSubmissionData.applicationPackages | Format-SimpleTableString -IndentationLevel $indentLength
        $output += ""

        $output += "Is Mandatory Update?                : {0}" -f $ApplicationSubmissionData.packageDeliveryOptions.isMandatoryUpdate
        $output += "Mandatory Update Effective Date     : {0}" -f $(Get-Date -Date $ApplicationSubmissionData.packageDeliveryOptions.mandatoryUpdateEffectiveDate -Format R)
        $output += ""

        $output += "Is Package Rollout?                 : {0}" -f $ApplicationSubmissionData.packageDeliveryOptions.packageRollout.isPackageRollout
        $output += "Package Rollout Percentage          : {0}%" -f $ApplicationSubmissionData.packageDeliveryOptions.packageRollout.packageRolloutPercentage
        $output += "Package Rollout Status              : {0}" -f $ApplicationSubmissionData.packageDeliveryOptions.packageRollout.packageRolloutStatus
        $output += "Fallback SubmissionId               : {0}" -f $ApplicationSubmissionData.packageDeliveryOptions.packageRollout.fallbackSubmissionId
        $output += ""

        $output += "Listings                            : {0}" -f $(if ($ApplicationSubmissionData.listings.count -eq 0) { "<None>" } else { "" })
        $listings = $ApplicationSubmissionData.listings
        foreach ($listing in ($listings | Get-Member -type NoteProperty))
        {
            $lang = $listing.Name
            $baseListing = $listings.$lang.baseListing
            $output += ""
            $output += "$(" " * $indentLength)$lang"
            $output += "$(" " * $indentLength)----------"
            $output += "$(" " * $indentLength)Title               : $($baseListing.title)"
            $output += "$(" " * $indentLength)ShortTitle          : $($baseListing.shortTitle)"
            $output += "$(" " * $indentLength)SortTitle           : $($baseListing.sortTitle)"
            $output += "$(" " * $indentLength)Voice Title         : $($baseListing.voiceTitle)"
            $output += "$(" " * $indentLength)Dev Studio          : $($baseListing.devStudio)"
            $output += "$(" " * $indentLength)Description         : $($baseListing.description)"
            $output += "$(" " * $indentLength)Short Description   : $($baseListing.shortDescription)"
            $output += "$(" " * $indentLength)Copyright/Trademark : $($baseListing.copyrightAndTrademarkInfo)"
            $output += "$(" " * $indentLength)Keywords            : $($baseListing.keywords -join "; ")"
            $output += "$(" " * $indentLength)License Terms       : $($baseListing.licenseTerms)"
            $output += "$(" " * $indentLength)Privacy Policy      : $($baseListing.privacyPolicy)"
            $output += "$(" " * $indentLength)Support Contact     : $($baseListing.supportContact)"
            $output += "$(" " * $indentLength)Website Url         : $($baseListing.websiteUrl)"
            $output += "$(" " * $indentLength)Features            : $($baseListing.features -join "; ")"
            $output += "$(" " * $indentLength)Release Notes       : $($baseListing.releaseNotes)"
            $output += "$(" " * $indentLength)Minimum Hardware    : {0}" -f $(if ($baseListing.minimumHardware.count -eq 0) { "<None>" } else { "" })
            $output += $baseListing.minimumHardware | Format-SimpleTableString -IndentationLevel $($indentLength * 2)
            $output += ""
            $output += "$(" " * $indentLength)Recommended Hardware: {0}" -f $(if ($baseListing.recommendedHardware.count -eq 0) { "<None>" } else { "" })
            $output += $baseListing.recommendedHardware | Format-SimpleTableString -IndentationLevel $($indentLength * 2)
            $output += ""
            $output += "$(" " * $indentLength)Images              : {0}" -f $(if ($baseListing.images.count -eq 0) { "<None>" } else { "" })
            $output += $baseListing.images | Format-SimpleTableString -IndentationLevel $($indentLength * 2)
            $output += ""

            # Only show the Trailers section if it exists
            if ($null -ne $trailers)
            {
                $langTrailers = $trailerByLang[$lang]
                $output += "$(" " * $indentLength)Trailers            : {0}" -f $(if ($langTrailers.count -eq 0) { "<None>" } else { "" })
                $output += $langTrailers | Format-SimpleTableString -IndentationLevel $($indentLength * 2)
                $output += ""
            }

            $output += "$(" " * $indentLength)Platform Overrides  : {0}" -f $(if ($listings.$lang.platformOverrides) { "<None>" } else { "" })
            $output += $listings.$lang.platformOverrides | Format-SimpleTableString -IndentationLevel $indentLength
            $output += ""
        }

        # Only show the Gaming Options section if ot exists
        if ($null -ne $ApplicationSubmissionData.gamingOptions)
        {
            $gamingOptions = $ApplicationSubmissionData.gamingOptions
            $output += "Gaming Options"
            $output += "$(" " * $indentLength)Genres                          : $($gamingOptions.genres -join ', ')"
            $output += "$(" " * $indentLength)isLocalMultiplayer              : $($gamingOptions.isLocalMultiplayer)"
            $output += "$(" " * $indentLength)isLocalCooperative              : $($gamingOptions.isLocalCooperative)"
            $output += "$(" " * $indentLength)isOnlineMultiplayer             : $($gamingOptions.isOnlineMultiplayer)"
            $output += "$(" " * $indentLength)isOnlineCooperative             : $($gamingOptions.isOnlineCooperative)"
            $output += "$(" " * $indentLength)localMultiplayerMinPlayers      : $($gamingOptions.localMultiplayerMinPlayers)"
            $output += "$(" " * $indentLength)localMultiplayerMaxPlayers      : $($gamingOptions.localMultiplayerMaxPlayers)"
            $output += "$(" " * $indentLength)localCooperativeMinPlayers      : $($gamingOptions.localCooperativeMinPlayers)"
            $output += "$(" " * $indentLength)localCooperativeMaxPlayers      : $($gamingOptions.localCooperativeMaxPlayers)"
            $output += "$(" " * $indentLength)isBroadcastingPrivilegeGranted  : $($gamingOptions.isBroadcastingPrivilegeGranted)"
            $output += "$(" " * $indentLength)isCrossPlayEnabled              : $($gamingOptions.isCrossPlayEnabled)"
            $output += "$(" " * $indentLength)kinectDataForExternal           : $($gamingOptions.kinectDataForExternal)"
            $output += ""
        }

        $output += "Status                                 : $($ApplicationSubmissionData.status)"
        $output += "Status Details [Errors]                : {0}" -f $(if ($ApplicationSubmissionData.statusDetails.errors.count -eq 0) { "<None>" } else { "" })
        $output += $ApplicationSubmissionData.statusDetails.errors | Format-SimpleTableString -IndentationLevel $indentLength
        $output += ""

        $output += "Status Details [Warnings]              : {0}" -f $(if ($ApplicationSubmissionData.statusDetails.warnings.count -eq 0) { "<None>" } else { "" })
        $output += $ApplicationSubmissionData.statusDetails.warnings | Format-SimpleTableString -IndentationLevel $indentLength
        $output += ""

        $output += "Status Details [Certification Reports] : {0}" -f $(if ($ApplicationSubmissionData.statusDetails.certificationReports.count -eq 0) { "<None>" } else { "" })
        foreach ($report in $ApplicationSubmissionData.statusDetails.certificationReports)
        {
            $output += $(" " * $indentLength) + $(Get-Date -Date $report.date -Format R) + ": $($report.reportUrl)"
        }
    }

    end
    {
        Write-Log -Message $output
    }
}

function Get-ApplicationSubmissionStatus
{
<#
    .SYNOPSIS
        Retrieves just the status of a specific application submission.

    .DESCRIPTION
        Gets just the status of a specific application submission.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER AppId
        The Application ID for the application that you want to retrieve the information
        about.

    .PARAMETER SubmissionId
        The specific submission that you want to retrieve the information about.

    .PARAMETER AccessToken
        If provided, this will be used as the AccessToken for authentication with the
        REST Api as opposed to requesting a new one.

    .PARAMETER NoStatus
        If this switch is specified, long-running commands will run on the main thread
        with no commandline status update.  When not specified, those commands run in
        the background, enabling the command prompt to provide status information.

    .EXAMPLE
        Get-ApplicationSubmissionStatus 0ABCDEF12345 1234567890123456789

        Gets the status for this application submission, with the console window showing
        progress while awaiting the response from the REST request.

    .EXAMPLE
        Get-ApplicationSubmissionStatus 0ABCDEF12345 1234567890123456789 -NoStatus

        Gets the status for this application submission,  but the request happens in the
        foreground and there is no additional status shown to the user until a response
        is returned from the REST request.

    .EXAMPLE
        $submission = Get-ApplicationSubmission 0ABCDEF12345 1234567890123456789

        Retrieves the status of the applications submission, and saves the results in
        a variable called $submission that can be used for further processing.
#>
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="Methods called within here make use of PSShouldProcess, and the switch is passed on to them inherently.")]
    param(
        [Parameter(Mandatory)]
        [string] $AppId,

        [Parameter(Mandatory)]
        [string] $SubmissionId,

        [string] $AccessToken = "",

        [switch] $NoStatus
    )

    Write-Log -Message "[$($MyInvocation.MyCommand.Module.Version)] Executing: $($MyInvocation.Line.Trim())" -Level Verbose

    $telemetryProperties = @{
        [StoreBrokerTelemetryProperty]::AppId = $AppId
        [StoreBrokerTelemetryProperty]::SubmissionId = $SubmissionId
    }

    $params = @{
        "UriFragment" = "applications/$AppId/submissions/$SubmissionId/status"
        "Method" = "Get"
        "Description" = "Getting status for AppId: $AppId SubmissionId: $SubmissionId"
        "AccessToken" = $AccessToken
        "TelemetryEventName" = "Get-ApplicationSubmissionStatus"
        "TelemetryProperties" = $telemetryProperties
        "NoStatus" = $NoStatus
    }

    return (Invoke-SBRestMethod @params)
}

function Remove-ApplicationSubmission
{
    <#
    .SYNOPSIS
        Deletes the specified application submission from a developer account.

    .DESCRIPTION
        Deletes the specified application submission from a developer account.
        An app can only have a single "pending" submission at any given time,
        and submissions cannot be modified via the REST API once started.
        Therefore, before a new application submission can be submitted,
        this method must be called to remove any existing pending submission.

    .PARAMETER AppId
        The Application ID for the application that has the pending submission to be removed.

    .PARAMETER SubmissionId
        The ID of the pending submission that should be removed.

    .PARAMETER AccessToken
        If provided, this will be used as the AccessToken for authentication with the
        REST Api as opposed to requesting a new one.

    .PARAMETER NoStatus
        If this switch is specified, long-running commands will run on the main thread
        with no commandline status update.  When not specified, those commands run in
        the background, enabling the command prompt to provide status information.

    .EXAMPLE
        Remove-ApplicationSubmission 0ABCDEF12345 1234567890123456789
        Removes the specified application submission from the developer account,
        with the console window showing progress while awaiting the response
        from the REST request.

    .EXAMPLE
        Remove-ApplicationSubmission 0ABCDEF12345 1234567890123456789 -NoStatus
        Removes the specified application submission from the developer account,
        but the request happens in the foreground and there is no additional status
        shown to the user until a response is returned from the REST request.
#>
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="Methods called within here make use of PSShouldProcess, and the switch is passed on to them inherently.")]
    param(
        [Parameter(Mandatory)]
        [string] $AppId,

        [Parameter(Mandatory)]
        [string] $SubmissionId,

        [string] $AccessToken = "",

        [switch] $NoStatus
    )

    Write-Log -Message "[$($MyInvocation.MyCommand.Module.Version)] Executing: $($MyInvocation.Line.Trim())" -Level Verbose

    $telemetryProperties = @{
        [StoreBrokerTelemetryProperty]::AppId = $AppId
        [StoreBrokerTelemetryProperty]::SubmissionId = $SubmissionId
    }

    $params = @{
        "UriFragment" = "applications/$AppId/submissions/$SubmissionId"
        "Method" = "Delete"
        "Description" = "Deleting submission: $SubmissionId for App: $AppId"
        "AccessToken" = $AccessToken
        "TelemetryEventName" = "Remove-ApplicationSubmission"
        "TelemetryProperties" = $telemetryProperties
        "NoStatus" = $NoStatus
    }

    $null = Invoke-SBRestMethod @params
}

function New-ApplicationSubmission
{
<#
    .SYNOPSIS
        Creates a submission for an existing application on the developer account.

    .DESCRIPTION
        Creates a submission for an existing application on the developer account.
        This app must already have at least one *published* submission completed via
        the website in order for this function to work.
        You cannot submit a new application submission if there is an existing pending
        application submission for $AppId already.  You can use -Force to work around
        this.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER AppId
        The Application ID for the application that the new submission is for.

    .PARAMETER ExistingPackageRolloutAction
        If the current published submission is making use of gradual package rollout,
        a new submission cannot be created until that existing submission is either
        halted or finalized.  To streamline the behavior in this scenario, you can
        indicate what action should be performed to that existing submission's package
        rollout prior to starting a new submission.

    .PARAMETER Force
        If this switch is specified, any existing pending submission for AppId
        will be removed before continuing with creation of the new submission.

    .PARAMETER AccessToken
        If provided, this will be used as the AccessToken for authentication with the
        REST Api as opposed to requesting a new one.

    .PARAMETER NoStatus
        If this switch is specified, long-running commands will run on the main thread
        with no commandline status update.  When not specified, those commands run in
        the background, enabling the command prompt to provide status information.

    .EXAMPLE
        New-ApplicationSubmission 0ABCDEF12345 -NoStatus

        Creates a new application submission for app 0ABCDEF12345 that is an exact clone of the currently
        published application submission, but the request happens in the foreground
        and there is no additional status shown to the user until a response is returned from the
        REST request.
        If successful, will return back the PSCustomObject representing the newly created
        application submission.

    .EXAMPLE
        New-ApplicationSubmission 0ABCDEF12345 -Force

        First checks for any existing pending submission for the app with ID 0ABCDEF12345.
        If one is found, it will be removed.  After that check has completed, this will create
        a new application submission for app 0ABCDEF12345 that is an exact clone of the currently
        published application submission, with the console window showing progress while awaiting
        the response from the REST request.
        If successful, will return back the PSCustomObject representing the newly created
        application submission.

    .OUTPUTS
        PSCustomObject representing the newly created application submission.
#>
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="Methods called within here make use of PSShouldProcess, and the switch is passed on to them inherently.")]
    param(
        [Parameter(Mandatory)]
        [string] $AppId,

        [ValidateSet('NoAction', 'Finalize', 'Halt')]
        [string] $ExistingPackageRolloutAction = $script:keywordNoAction,

        [switch] $Force,

        [string] $AccessToken = "",

        [switch] $NoStatus
    )

    Write-Log -Message "[$($MyInvocation.MyCommand.Module.Version)] Executing: $($MyInvocation.Line.Trim())" -Level Verbose

    if ([System.String]::IsNullOrEmpty($AccessToken))
    {
        $AccessToken = Get-AccessToken -NoStatus:$NoStatus
    }

    try
    {
        # The Force switch tells us that we need to remove any pending submission
        if ($Force -or ($ExistingPackageRolloutAction -ne $script:keywordNoAction))
        {
            $application = Get-Application -AppId $AppId -AccessToken $AccessToken -NoStatus:$NoStatus
            $publishedSubmissionId = $application.lastPublishedApplicationSubmission.id
            $pendingSubmissionId = $application.pendingApplicationSubmission.id

            if ($Force -and ($null -ne $pendingSubmissionId))
            {
                Write-Log -Message "Force creation requested. Removing pending submission." -Level Verbose
                Remove-ApplicationSubmission -AppId $AppId -SubmissionId $pendingSubmissionId -AccessToken $AccessToken -NoStatus:$NoStatus
            }

            if ($ExistingPackageRolloutAction -ne $script:keywordNoAction)
            {
                $rollout = Get-ApplicationSubmissionPackageRollout -AppId $AppId -SubmissionId $publishedSubmissionId -AccessToken $AccessToken -NoStatus:$NoStatus
                $isPackageRollout = $rollout.isPackageRollout
                $packageRolloutStatus = $rollout.packageRolloutStatus
                if ($isPackageRollout -and ($packageRolloutStatus -in ('PackageRolloutNotStarted', 'PackageRolloutInProgress')))
                {
                    if ($ExistingPackageRolloutAction -eq 'Finalize')
                    {
                        Write-Log -Message "Finalizing package rollout for existing submission before continuing." -Level Verbose
                        Complete-ApplicationSubmissionPackageRollout -AppId $AppId -SubmissionId $publishedSubmissionId -AccessToken $AccessToken -NoStatus:$NoStatus
                    }
                    elseif ($ExistingPackageRolloutAction -eq 'Halt')
                    {
                        Write-Log -Message "Halting package rollout for existing submission before continuing." -Level Verbose
                        Stop-ApplicationSubmissionPackageRollout -AppId $AppId -SubmissionId $publishedSubmissionId -AccessToken $AccessToken -NoStatus:$NoStatus
                    }
                }
            }
        }

        # Finally, we can POST with a null body to create a clone of the currently published submission
        $telemetryProperties = @{
            [StoreBrokerTelemetryProperty]::AppId = $AppId
            [StoreBrokerTelemetryProperty]::ExistingPackageRolloutAction = $ExistingPackageRolloutAction
            [StoreBrokerTelemetryProperty]::Force = $Force
        }

        $params = @{
            "UriFragment" = "applications/$AppId/submissions"
            "Method" = "Post"
            "Description" = "Cloning current submission for App: $AppId"
            "AccessToken" = $AccessToken
            "TelemetryEventName" = "New-ApplicationSubmission"
            "TelemetryProperties" = $telemetryProperties
            "NoStatus" = $NoStatus
        }

        return (Invoke-SBRestMethod @params)
    }
    catch
    {
        throw
    }
}

function Update-ApplicationSubmission
{
<#
    .SYNOPSIS
        Creates a new submission for an existing application on the developer account
        by cloning the existing submission and modifying specific parts of it.

    .DESCRIPTION
        Creates a new submission for an existing application on the developer account
        by cloning the existing submission and modifying specific parts of it. The
        parts that will be modified depend solely on the switches that are passed in.

        This app must already have at least one *published* submission completed via
        the website in order for this function to work.
        You cannot submit a new application submission if there is an existing pending
        application submission for $AppId already.  You can use -Force to work around
        this.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER AppId
        The Application ID for the application that the new submission is for.

    .PARAMETER SubmissionDataPath
        The file containing the JSON payload for the application submission.

    .PARAMETER PackagePath
        If provided, this package will be uploaded after the submission has been successfully
        created.

    .PARAMETER TargetPublishMode
        Indicates how the submission will be published once it has passed certification.
        The value specified here takes precendence over the value from SubmissionDataPath if
        -UpdatePublishModeAndVisibility is specified.  If -UpdatePublishModeAndVisibility
        is not specified and the value 'Default' is used, this submission will simply use the
        value from the previous submission.

    .PARAMETER TargetPublishDate
        Indicates when the submission will be published once it has passed certification.
        Specifying a value here is only valid when TargetPublishMode is set to 'SpecificDate'.
        The value specified here takes precendence over the value from SubmissionDataPath if
        -UpdatePublishModeAndVisibility is specified.  If -UpdatePublishModeAndVisibility
        is not specified and the value 'Default' is used, this submission will simply use the
        value from the previous submission.  Users should provide this in local time and it
        will be converted automatically to UTC.

    .PARAMETER Visibility
        Indicates the store visibility of the app once the submission has been published.
        The value specified here takes precendence over the value from SubmissionDataPath if
        -UpdatePublishModeAndVisibility is specified.  If -UpdatePublishModeAndVisibility
        is not specified and the value 'Default' is used, this submission will simply use the
        value from the previous submission.

    .PARAMETER ExistingPackageRolloutAction
        If the current published submission is making use of gradual package rollout,
        a new submission cannot be created until that existing submission is either
        halted or finalized.  To streamline the behavior in this scenario, you can
        indicate what action should be performed to that existing submission's package
        rollout prior to starting a new submission.

    .PARAMETER PackageRolloutPercentage
        If specified, this submission will use gradual package rollout, setting their
        initial rollout percentage to be the indicated amount.

    .PARAMETER IsMandatoryUpdate
        Indicates whether you want to treat the packages in this submission as mandatory
        for self-installing app updates.

    .PARAMETER MandatoryUpdateEffectiveDate
        The date and time when the packages in this submission become mandatory. It is
        not required to provide a value for this when using IsMandatoryUpdate, however
        this value will be ignored if specified and IsMandatoryUpdate is not also provided.
        Users should provide this in local time and it will be converted automatically to UTC.

    .PARAMETER AutoCommit
        If this switch is specified, will automatically commit the submission
        (which starts the certification process) once the Package has been uploaded
        (if PackagePath was specified), or immediately after the submission has been modified.

    .PARAMETER SubmissionId
        If a submissionId is provided, instead of trying to clone the currently published
        submission and operating against that clone, this will operate against an already
        existing pending submission (that was likely cloned previously).

    .PARAMETER Force
        If this switch is specified, any existing pending submission for AppId
        will be removed before continuing with creation of the new submission.

    .PARAMETER AddPackages
        Causes the packages that are listed in SubmissionDataPath to be added to the package listing
        in the final, patched submission.  This switch is mutually exclusive with ReplacePackages.

    .PARAMETER ReplacePackages
        Causes any existing packages in the cloned submission to be removed and only the packages
        that are listed in SubmissionDataPath will be in the final, patched submission.
        This switch is mutually exclusive with AddPackages.

    .PARAMETER UpdateListings
        Replaces the listings array in the final, patched submission with the listings array
        from SubmissionDataPath.  Ensures that the images originally part of each listing in the
        cloned submission are marked as "PendingDelete" in the final, patched submission.

    .PARAMETER UpdatePublishModeAndVisibility
        Updates fields under the "Publish Mode and Visibility" category in the PackageTool config file.
        Updates the following fields using values from SubmissionDataPath: targetPublishMode,
        targetPublishDate, and visibility.

    .PARAMETER UpdatePricingAndAvailability
        Updates fields under the "Pricing and Availability" category in the PackageTool config file.
        Updates the following fields using values from SubmissionDataPath:  pricing,
        allowTargetFutureDeviceFamilies, allowMicrosoftDecideAppAvailabilityToFutureDeviceFamilies,
        and enterpriseLicensing.

    .PARAMETER UpdateAppProperties
        Updates fields under the "App Properties" category in the PackageTool config file.
        Updates the following fields using values from SubmissionDataPath: applicationCategory,
        hardwarePreferences, hasExternalInAppProducts, meetAccessibilityGuidelines,
        canInstallOnRemovableMedia, automaticBackupEnabled, and isGameDvrEnabled.

    .PARAMETER UpdateGamingOptions
        Updates fields under the "Ganming Options" category in the PackageTool config file.
        Updates the following fields using values from SubmissionDataPath under gamingOptions:
        genres, isLocalMultiplayer, isLocalCooperative, isOnlineMultiplayer, isOnlineCooperative,
        localMultiplayerMinPlayers, localMultiplayerMaxPlayers, localCooperativeMinPlayers,
        localCooperativeMaxPlayers, isBroadcastingPrivilegeGranted, isCrossPlayEnabled, and kinectDataForExternal.

     .PARAMETER UpdateTrailers
        Replaces the trailers array in the final, patched submission with the trailers array
        from SubmissionDataPath.

     .PARAMETER UpdateNotesForCertification
        Updates the notesForCertification field using the value from SubmissionDataPath.

    .PARAMETER AccessToken
        If provided, this will be used as the AccessToken for authentication with the
        REST Api as opposed to requesting a new one.

    .PARAMETER NoStatus
        If this switch is specified, long-running commands will run on the main thread
        with no commandline status update.  When not specified, those commands run in
        the background, enabling the command prompt to provide status information.

    .EXAMPLE
        Update-ApplicationSubmission 0ABCDEF12345 "c:\foo.json"
        Creates a new application submission for app 0ABCDEF12345 that is a clone of the currently
        published submission.  Even though "c:\foo.json" was provided, because no switches
        were specified to indicate what to copy from it, the cloned submission was not further
        modified, and is thus still an exact copy of the currently published submission.
        If successful, will return back the pending submission id and url that should be
        used with Upload-SubmissionPackage.

    .EXAMPLE
        Update-ApplicationSubmission 0ABCDEF12345 "c:\foo.json" -AddPackages -NoStatus
        Creates a new application submission for app 0ABCDEF12345 that is a clone of the currently
        published submission.  The packages listed in "c:\foo.json" will be added to the list
        of packages that should be used by the submission.  The request happens in the foreground
        and there is no additional status shown to the user until a response is returned from the
        REST request.  If successful, will return back the pending submission id and url that
        should be used with Upload-SubmissionPackage.

    .EXAMPLE
        Update-ApplicationSubmission 0ABCDEF12345 "c:\foo.json" -Force -UpdateListings -UpdatePricingAndAvailability
        First checks for any existing pending submission for the app with ID 0ABCDEF12345.
        If one is found, it will be removed.  After that check has completed, this will create
        a new application submission for app 0ABCDEF12345 that is a clone of the currently published
        submission.  The "Pricing and Availability" fields of that cloned submission will be modified to
        reflect the values that are in "c:\foo.json".
        If successful, will return back the pending submission id and url that should be
        used with Upload-SubmissionPackage.

    .EXAMPLE
        Update-ApplicationSubmission 0ABCDEF12345 "c:\foo.json" "c:\foo.zip" -AutoCommit -SubmissionId 1234567890123456789 -AddPackages
        Retrieves submission 1234567890123456789 from app 0ABCDEF12345, updates the package listing
        to include the packages that are contained in "c:\foo.json."  If successful, this then
        attempts to upload "c:\foo.zip" as the package content for the submission.  If that
        is also successful, it then goes ahead and commits the submission so that the certification
        process can start. The pending submission id and url that were used with with
        Upload-SubmissionPackage are still returned in this scenario, even though the
        upload url can no longer actively be used.

    .OUTPUTS
        An array of the following two objects:
            System.String - The id for the new pending submission
            System.String - The URL that the package needs to be uploaded to.
#>
    [CmdletBinding(
        SupportsShouldProcess,
        DefaultParametersetName="AddPackages")]
    [OutputType([Object[]])]
    param(
        [Parameter(Mandatory)]
        [string] $AppId,

        [Parameter(Mandatory)]
        [ValidateScript({if (Test-Path -Path $_ -PathType Leaf) { $true } else { throw "$_ cannot be found." }})]
        [string] $SubmissionDataPath,

        [ValidateScript({if (Test-Path -Path $_ -PathType Leaf) { $true } else { throw "$_ cannot be found." }})]
        [string] $PackagePath = $null,

        [switch] $AutoCommit,

        [string] $SubmissionId = "",

        [ValidateSet('Default', 'Immediate', 'Manual', 'SpecificDate')]
        [string] $TargetPublishMode = $script:keywordDefault,

        [DateTime] $TargetPublishDate,

        [ValidateSet('Default', 'Public', 'Private', 'Hidden')]
        [string] $Visibility = $script:keywordDefault,

        [ValidateSet('NoAction', 'Finalize', 'Halt')]
        [string] $ExistingPackageRolloutAction = $script:keywordNoAction,

        [ValidateRange(0, 100)]
        [double] $PackageRolloutPercentage = -1,

        [switch] $IsMandatoryUpdate,

        [DateTime] $MandatoryUpdateEffectiveDate,

        [ValidateScript({if ([System.String]::IsNullOrEmpty($SubmissionId) -or !$_) { $true } else { throw "Can't use -Force and supply a SubmissionId." }})]
        [switch] $Force,

        [Parameter(ParameterSetName="AddPackages")]
        [switch] $AddPackages,

        [Parameter(ParameterSetName="ReplacePackages")]
        [switch] $ReplacePackages,

        [switch] $UpdateListings,

        [switch] $UpdatePublishModeAndVisibility,

        [switch] $UpdatePricingAndAvailability,

        [switch] $UpdateAppProperties,

        [switch] $UpdateGamingOptions,

        [switch] $UpdateTrailers,

        [switch] $UpdateNotesForCertification,

        [string] $AccessToken = "",

        [switch] $NoStatus
    )

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    Write-Log -Message "[$($MyInvocation.MyCommand.Module.Version)] Executing: $($MyInvocation.Line.Trim())" -Level Verbose

    Write-Log -Message "Reading in the submission content from: $SubmissionDataPath" -Level Verbose
    if ($PSCmdlet.ShouldProcess($SubmissionDataPath, "Get-Content"))
    {
        $submission = [string](Get-Content $SubmissionDataPath -Encoding UTF8) | ConvertFrom-Json
    }

    # Extra layer of validation to protect users from trying to submit a payload to the wrong application
    if ([String]::IsNullOrWhiteSpace($submission.appId))
    {
        $configPath = Join-Path -Path ([System.Environment]::GetFolderPath('Desktop')) -ChildPath 'newconfig.json'

        Write-Log -Level Warning -Message @(
            "The config file used to generate this submission did not have an AppId defined in it.",
            "The AppId entry in the config helps ensure that payloads are not submitted to the wrong application.",
            "Please update your app's StoreBroker config file by adding an `"appId`" property with",
            "your app's AppId to the `"appSubmission`" section.  If you're unclear on what change",
            "needs to be done, you can re-generate your config file using",
            "   New-StoreBrokerConfigFile -AppId $AppId -Path `"$configPath`"",
            "and then diff the new config file against your current one to see the requested appId change.")
    }
    else
    {
        if ($AppId -ne $submission.appId)
        {
            $output = @()
            $output += "The AppId [$($submission.appId)] in the submission content [$SubmissionDataPath] does not match the intended AppId [$AppId]."
            $output += "You either entered the wrong AppId at the commandline, or you're referencing the wrong submission content to upload."

            $newLineOutput = ($output -join [Environment]::NewLine)
            Write-Log -Message $newLineOutput -Level Error
            throw $newLineOutput
        }
    }

    Remove-UnofficialSubmissionProperties -Submission $submission

    # Identify potentially incorrect usage of this method by checking to see if no modification
    # switch was provided by the user
    if ((-not $AddPackages) -and
        (-not $ReplacePackages) -and
        (-not $UpdateListings) -and
        (-not $UpdatePublishModeAndVisibility) -and
        (-not $UpdatePricingAndAvailability) -and
        (-not $UpdateAppProperties) -and
        (-not $UpdateGamingOptions) -and
        (-not $UpdateTrailers) -and
        (-not $UpdateNotesForCertification))
    {
        Write-Log -Level Warning -Message @(
            "You have not specified any `"modification`" switch for updating the submission.",
            "This means that the new submission will be identical to the current one.",
            "If this was not your intention, please read-up on the documentation for this command:",
            "     Get-Help Update-ApplicationSubmission -ShowWindow")
    }

    if ([System.String]::IsNullOrEmpty($AccessToken))
    {
        $AccessToken = Get-AccessToken -NoStatus:$NoStatus
    }

    try
    {
        if ([System.String]::IsNullOrEmpty($SubmissionId))
        {
            $submissionToUpdate = New-ApplicationSubmission -AppId $AppId -ExistingPackageRolloutAction $ExistingPackageRolloutAction -Force:$Force -AccessToken $AccessToken -NoStatus:$NoStatus
        }
        else
        {
            $submissionToUpdate = Get-ApplicationSubmission -AppId $AppId -SubmissionId $SubmissionId -AccessToken $AccessToken -NoStatus:$NoStatus
            if ($submissionToUpdate.status -ne $script:keywordPendingCommit)
            {
                $output = @()
                $output += "We can only modify a submission that is in the '$script:keywordPendingCommit' state."
                $output += "The submission that you requested to modify ($SubmissionId) is in '$($submissionToUpdate.status)' state."

                $newLineOutput = ($output -join [Environment]::NewLine)
                Write-Log -Message $newLineOutput -Level Error
                throw $newLineOutput
            }
        }

        if ($PSCmdlet.ShouldProcess("Patch-ApplicationSubmission"))
        {
            $params = @{}
            $params.Add("ClonedSubmission", $submissionToUpdate)
            $params.Add("NewSubmission", $submission)
            $params.Add("TargetPublishMode", $TargetPublishMode)
            if ($null -ne $TargetPublishDate) { $params.Add("TargetPublishDate", $TargetPublishDate) }
            $params.Add("Visibility", $Visibility)
            $params.Add("UpdateListings", $UpdateListings)
            $params.Add("UpdatePublishModeAndVisibility", $UpdatePublishModeAndVisibility)
            $params.Add("UpdatePricingAndAvailability", $UpdatePricingAndAvailability)
            $params.Add("UpdateAppProperties", $UpdateAppProperties)
            $params.Add("UpdateGamingOptions", $UpdateGamingOptions)
            $params.Add("UpdateTrailers", $UpdateTrailers)
            $params.Add("UpdateNotesForCertification", $UpdateNotesForCertification)
            if ($PackageRolloutPercentage -ge 0) { $params.Add("PackageRolloutPercentage", $PackageRolloutPercentage) }
            $params.Add("IsMandatoryUpdate", $IsMandatoryUpdate)
            if ($null -ne $MandatoryUpdateEffectiveDate) { $params.Add("MandatoryUpdateEffectiveDate", $MandatoryUpdateEffectiveDate) }

            # Because these are mutually exclusive and tagged as such, we have to be sure to *only*
            # add them to the parameter set if they're true.
            if ($AddPackages) { $params.Add("AddPackages", $AddPackages) }
            if ($ReplacePackages) { $params.Add("ReplacePackages", $ReplacePackages) }

            $patchedSubmission = Patch-ApplicationSubmission @params
        }

        if ($PSCmdlet.ShouldProcess("Set-ApplicationSubmission"))
        {
            $params = @{}
            $params.Add("AppId", $AppId)
            $params.Add("UpdatedSubmission", $patchedSubmission)
            $params.Add("AccessToken", $AccessToken)
            $params.Add("NoStatus", $NoStatus)
            $replacedSubmission = Set-ApplicationSubmission @params
        }

        $submissionId = $replacedSubmission.id
        $uploadUrl = $replacedSubmission.fileUploadUrl

        Write-Log -Message @(
            "Successfully cloned the existing submission and modified its content.",
            "You can view it on the Dev Portal here:",
            "    https://dev.windows.com/en-us/dashboard/apps/$AppId/submissions/$submissionId/",
            "or by running this command:",
            "    Get-ApplicationSubmission -AppId $AppId -SubmissionId $submissionId | Format-ApplicationSubmission",
            "",
            ($script:manualPublishWarning -f 'Update-ApplicationSubmission'))

        if (![System.String]::IsNullOrEmpty($PackagePath))
        {
            Write-Log -Message "Uploading the package [$PackagePath] since it was provided." -Level Verbose
            Set-SubmissionPackage -PackagePath $PackagePath -UploadUrl $uploadUrl -NoStatus:$NoStatus
        }
        elseif (!$AutoCommit)
        {
            Write-Log -Message @(
                "Your next step is to upload the package using:",
                "  Upload-SubmissionPackage -PackagePath <package> -UploadUrl `"$uploadUrl`"")
        }

        if ($AutoCommit)
        {
            if ($stopwatch.Elapsed.TotalSeconds -gt $script:accessTokenTimeoutSeconds)
            {
                # The package upload probably took a long time.
                # There's a high likelihood that the token will be considered expired when we call
                # into Complete-ApplicationSubmission ... so, we'll send in a $null value and
                # let it acquire a new one.
                $AccessToken = $null
            }

            Write-Log -Message "Commiting the submission since -AutoCommit was requested." -Level Verbose
            Complete-ApplicationSubmission -AppId $AppId -SubmissionId $submissionId -AccessToken $AccessToken -NoStatus:$NoStatus
        }
        else
        {
            Write-Log -Message @(
                "When you're ready to commit, run this command:",
                "  Commit-ApplicationSubmission -AppId $AppId -SubmissionId $submissionId")
        }

        # Record the telemetry for this event.
        $stopwatch.Stop()
        $telemetryMetrics = @{ [StoreBrokerTelemetryMetric]::Duration = $stopwatch.Elapsed.TotalSeconds }
        $telemetryProperties = @{
            [StoreBrokerTelemetryProperty]::AppId = $AppId
            [StoreBrokerTelemetryProperty]::SubmissionId = $SubmissionId
            [StoreBrokerTelemetryProperty]::PackagePath = (Get-PiiSafeString -PlainText $PackagePath)
            [StoreBrokerTelemetryProperty]::AutoCommit = $AutoCommit
            [StoreBrokerTelemetryProperty]::Force = $Force
            [StoreBrokerTelemetryProperty]::PackageRolloutPercentage = $PackageRolloutPercentage
            [StoreBrokerTelemetryProperty]::IsMandatoryUpdate = [bool]$IsMandatoryUpdate
            [StoreBrokerTelemetryProperty]::AddPackages = $AddPackages
            [StoreBrokerTelemetryProperty]::UpdateListings = $UpdateListings
            [StoreBrokerTelemetryProperty]::UpdatePublishModeAndVisibility = $UpdatePublishModeAndVisibility
            [StoreBrokerTelemetryProperty]::UpdatePricingAndAvailability = $UpdatePricingAndAvailability
            [StoreBrokerTelemetryProperty]::UpdateGamingOptions = $UpdateGamingOptions
            [StoreBrokerTelemetryProperty]::UpdateTrailers = $UpdateTrailers
            [StoreBrokerTelemetryProperty]::UpdateAppProperties = $UpdateAppProperties
            [StoreBrokerTelemetryProperty]::UpdateNotesForCertification = $UpdateNotesForCertification
        }

        Set-TelemetryEvent -EventName Update-ApplicationSubmission -Properties $telemetryProperties -Metrics $telemetryMetrics

        return $submissionId, $uploadUrl
    }
    catch
    {
        Write-Log -Exception $_ -Level Error
        throw
    }
}

function Patch-ApplicationSubmission
{
<#
    .SYNOPSIS
        Modifies a cloned application submission by copying the specified data from the
        provided "new" submission.  Returns the final, patched submission JSON.

    .DESCRIPTION
        Modifies a cloned application submission by copying the specified data from the
        provided "new" submission.  Returns the final, patched submission JSON.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER ClonedSubmisson
        The JSON that was returned by the Store API when the application submission was cloned.

    .PARAMETER NewSubmission
        The JSON for the new/updated application submission.  The only parts from this submission
        that will be copied to the final, patched submission will be those specified by the
        switches.

    .PARAMETER TargetPublishMode
        Indicates how the submission will be published once it has passed certification.
        The value specified here takes precendence over the value from NewSubmission if
        -UpdatePublishModeAndVisibility is specified.  If -UpdatePublishModeAndVisibility
        is not specified and the value 'Default' is used, this submission will simply use the
        value from the previous submission.

    .PARAMETER TargetPublishDate
        Indicates when the submission will be published once it has passed certification.
        Specifying a value here is only valid when TargetPublishMode is set to 'SpecificDate'.
        The value specified here takes precendence over the value from NewSubmission if
        -UpdatePublishModeAndVisibility is specified.  If -UpdatePublishModeAndVisibility
        is not specified and the value 'Default' is used, this submission will simply use the
        value from the previous submission.  Users should provide this in local time and it
        will be converted automatically to UTC.

    .PARAMETER Visibility
        Indicates the store visibility of the app once the submission has been published.
        The value specified here takes precendence over the value from NewSubmission if
        -UpdatePublishModeAndVisibility is specified.  If -UpdatePublishModeAndVisibility
        is not specified and the value 'Default' is used, this submission will simply use the
        value from the previous submission.

    .PARAMETER PackageRolloutPercentage
        If specified, this submission will use gradual package rollout, setting their
        initial rollout percentage to be the indicated amount.

    .PARAMETER IsMandatoryUpdate
        Indicates whether you want to treat the packages in this submission as mandatory
        for self-installing app updates.

    .PARAMETER MandatoryUpdateEffectiveDate
        The date and time when the packages in this submission become mandatory. It is
        not required to provide a value for this when using IsMandatoryUpdate, however
        this value will be ignored if specified and IsMandatoryUpdate is not also provided.
        Users should provide this in local time and it will be converted automatically to UTC.

    .PARAMETER AddPackages
        Causes the packages that are listed in SubmissionDataPath to be added to the package listing
        in the final, patched submission.  This switch is mutually exclusive with ReplacePackages.

    .PARAMETER ReplacePackages
        Causes any existing packages in the cloned submission to be removed and only the packages
        that are listed in SubmissionDataPath will be in the final, patched submission.
        This switch is mutually exclusive with AddPackages.

    .PARAMETER UpdateListings
        Replaces the listings array in the final, patched submission with the listings array
        from NewSubmission.  Ensures that the images originally part of each listing in the
        ClonedSubmission are marked as "PendingDelete" in the final, patched submission.

    .PARAMETER UpdatePublishModeAndVisibility
        Updates fields under the "Publish Mode and Visibility" category in the PackageTool config file.
        Updates the following fields using values from SubmissionDataPath: targetPublishMode,
        targetPublishDate, and visibility.

    .PARAMETER UpdatePricingAndAvailability
        Updates fields under the "Pricing and Availability" category in the PackageTool config file.
        Updates the following fields using values from SubmissionDataPath: targetPublishMode,
        targetPublishDate, visibility, pricing, allowTargetFutureDeviceFamilies,
        allowMicrosoftDecideAppAvailabilityToFutureDeviceFamilies, and enterpriseLicensing.

    .PARAMETER UpdateAppProperties
        Updates fields under the "App Properties" category in the PackageTool config file.
        Updates the following fields using values from SubmissionDataPath: applicationCategory,
        hardwarePreferences, hasExternalInAppProducts, meetAccessibilityGuidelines,
        canInstallOnRemovableMedia, automaticBackupEnabled, and isGameDvrEnabled.

    .PARAMETER UpdateGamingOptions
        Updates fields under the "Ganming Options" category in the PackageTool config file.
        Updates the following fields using values from SubmissionDataPath under gamingOptions:
        genres, isLocalMultiplayer, isLocalCooperative, isOnlineMultiplayer, isOnlineCooperative,
        localMultiplayerMinPlayers, localMultiplayerMaxPlayers, localCooperativeMinPlayers,
        localCooperativeMaxPlayers, isBroadcastingPrivilegeGranted, isCrossPlayEnabled, and kinectDataForExternal.

    .PARAMETER UpdateTrailers
        Replaces the trailers array in the final, patched submission with the trailers array
        from SubmissionDataPath.

    .PARAMETER UpdateNotesForCertification
        Updates the notesForCertification field using the value from SubmissionDataPath.

    .EXAMPLE
        $patchedSubmission = Prepare-ApplicationSubmission $clonedSubmission $jsonContent
        Because no switches were specified, ($patchedSubmission -eq $clonedSubmission).

    .EXAMPLE
        $patchedSubmission = Prepare-ApplicationSubmission $clonedSubmission $jsonContent -AddPackages
        $patchedSubmission will be identical to $clonedSubmission, however all of the packages that
        were contained in $jsonContent will have also been added to the package array.

    .EXAMPLE
        $patchedSubmission = Prepare-ApplicationSubmission $clonedSubmission $jsonContent -AddPackages -UpdateListings
        $patchedSubmission will be contain the listings and packages that were part of $jsonContent,
        but the rest of the submission content will be identical to what had been in $clonedSubmission.
        Additionally, any images that were part of listings from $clonedSubmission will still be
        listed in $patchedSubmission, but their file status will have been changed to "PendingDelete".

    .NOTES
        This is an internal-only helper method.
#>

    [CmdletBinding(DefaultParametersetName="AddPackages")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseApprovedVerbs", "", Justification="Internal-only helper method.  Best description for purpose.")]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject] $ClonedSubmission,

        [Parameter(Mandatory)]
        [PSCustomObject] $NewSubmission,

        [ValidateSet('Default', 'Immediate', 'Manual', 'SpecificDate')]
        [string] $TargetPublishMode = $script:keywordDefault,

        [DateTime] $TargetPublishDate,

        [ValidateSet('Default', 'Public', 'Private', 'Hidden')]
        [string] $Visibility = $script:keywordDefault,

        [ValidateRange(0, 100)]
        [double] $PackageRolloutPercentage = -1,

        [switch] $IsMandatoryUpdate,

        [DateTime] $MandatoryUpdateEffectiveDate,

        [Parameter(ParameterSetName="AppPackages")]
        [switch] $AddPackages,

        [Parameter(ParameterSetName="ReplacePackages")]
        [switch] $ReplacePackages,

        [switch] $UpdateListings,

        [switch] $UpdatePublishModeAndVisibility,

        [switch] $UpdatePricingAndAvailability,

        [switch] $UpdateAppProperties,

        [switch] $UpdateGamingOptions,

        [switch] $UpdateTrailers,

        [switch] $UpdateNotesForCertification
    )

    Write-Log -Message "Patching the content of the submission." -Level Verbose

    # Our method should have zero side-effects -- we don't want to modify any parameter
    # that was passed-in to us.  To that end, we'll create a deep copy of the ClonedSubmisison,
    # and we'll modify that throughout this function and that will be the value that we return
    # at the end.
    $PatchedSubmission = DeepCopy-Object $ClonedSubmission

    # We use a ValidateRange attribute to ensure a valid percentage, but then use -1 as a default
    # value to indicate when the user hasn't specified a value (and thus, does not want to use
    # this feature).
    if ($PackageRolloutPercentage -ge 0)
    {
        $PatchedSubmission.packageDeliveryOptions.packageRollout.isPackageRollout = $true
        $PatchedSubmission.packageDeliveryOptions.packageRollout.packageRolloutPercentage = $PackageRolloutPercentage

        Write-Log -Level Warning -Message @(
            "Your rollout selections apply to all of your packages, but will only apply to your customers running OS",
            "versions that support package flights (Windows.Desktop build 10586 or later; Windows.Mobile build 10586.63",
            "or later, and Xbox), including any customers who get the app via Store-managed licensing via the",
            "Windows Store for Business.  When using gradual package rollout, customers on earlier OS versions will not",
            "get packages from the latest submission until you finalize the package rollout.")
    }

    $PatchedSubmission.packageDeliveryOptions.isMandatoryUpdate = [bool]$IsMandatoryUpdate
    if ($null -ne $MandatoryUpdateEffectiveDate)
    {
        if ($IsMandatoryUpdate)
        {
            $PatchedSubmission.packageDeliveryOptions.mandatoryUpdateEffectiveDate = $MandatoryUpdateEffectiveDate.ToUniversalTime().ToString('o')
        }
        else
        {
            Write-Log -Message "MandatoryUpdateEffectiveDate specified without indicating IsMandatoryUpdate.  The value will be ignored." -Level Warning
        }
    }

    if (($AddPackages -or $ReplacePackages) -and ($NewSubmission.applicationPackages.Count -eq 0))
    {
        $output = @()
        $output += "Your submission doesn't contain any packages, so you cannot Add or Replace packages."
        $output += "Please check your input settings to New-SubmissionPackage and ensure you're providing a value for AppxPath."
        $output = $output -join [Environment]::NewLine
        Write-Log -Message $output -Level Error
        throw $output
    }

    # When updating packages, we'll simply add the new packages to the list of existing packages.
    # At some point when the API provides more signals to us with regard to what platform/OS
    # an existing package is for, we may want to mark "older" packages for the same platform
    # as "PendingDelete" so as to not overly clutter the dev account with old packages.  For now,
    # we'll leave any package maintenance to uses of the web portal.
    if ($AddPackages)
    {
        $PatchedSubmission.applicationPackages += $NewSubmission.applicationPackages
    }

    # Caller wants to remove any existing packages in the cloned submission and only have the
    # packages that are defined in the new submission.
    if ($ReplacePackages)
    {
        $PatchedSubmission.applicationPackages | ForEach-Object { $_.fileStatus = $script:keywordPendingDelete }
        $PatchedSubmission.applicationPackages += $NewSubmission.applicationPackages
    }

    # When updating the listings metadata, what we really want to do is just blindly replace
    # the existing listings array with the new one.  We can't do that unfortunately though,
    # as we need to mark the existing screenshots as "PendingDelete" so that they'll be deleted
    # during the upload.  Otherwise, even though we don't include them in the updated JSON, they
    # will still remain there in the Dev Portal.
    if ($UpdateListings)
    {
        # Save off the original listings so that we can make changes to them without affecting
        # other references
        $existingListings = DeepCopy-Object $PatchedSubmission.listings

        # Then we'll replace the patched submission's listings array (which had the old,
        # cloned metadata), with the metadata from the new submission.
        $PatchedSubmission.listings = DeepCopy-Object $NewSubmission.listings

        # Now we'll update the screenshots in the existing listings
        # to indicate that they should all be deleted. We'll also add
        # all of these deleted images to the corresponding listing
        # in the patched submission.
        #
        # Unless the Store team indicates otherwise, we assume that the server will handle
        # deleting the images in regions that were part of the cloned submission, but aren't part
        # of the patched submission that we provide. Otherwise, we'd have to create empty listing
        # objects that would likely fail validation.
        $existingListings |
            Get-Member -type NoteProperty |
                ForEach-Object {
                    $lang = $_.Name
                    if ($null -ne $PatchedSubmission.listings.$lang.baseListing.images)
                    {
                        $existingListings.$lang.baseListing.images |
                            ForEach-Object {
                                $_.FileStatus = $script:keywordPendingDelete
                                $PatchedSubmission.listings.$lang.baseListing.images += $_
                            }
                    }
                }

        # We also have to be sure to carry forward any "platform overrides" that the cloned
        # submission had.  These platform overrides have listing information for previous OS
        # releases like Windows 8.0/8.1 and Windows Phone 8.0/8.1.
        #
        # This has slightly different logic from the normal listings as we don't expect users
        # to use StoreBroker to modify these values.  We will copy any platform override that
        # exists from the cloned submission to the patched submission, provided that the patched
        # submission has that language.  If a platform override entry already exists for a specific
        # platform in the patched submission, we will just carry forward the previous images for
        # that platformOverride and mark them as PendingDelete, just like we do for normal listings.
        $existingListings |
            Get-Member -type NoteProperty |
                ForEach-Object {
                    $lang = $_.Name

                    # We're only bringing over platformOverrides for languages that we still have
                    # in the patched submission.
                    if ($null -ne $PatchedSubmission.listings.$lang.baseListing)
                    {
                        $existingListings.$lang.platformOverrides |
                            Get-Member -type NoteProperty |
                                ForEach-Object {
                                    $platform = $_.Name

                                    if ($null -eq $PatchedSubmission.listings.$lang.platformOverrides.$platform)
                                    {
                                        # If the override doesn't exist in the patched submission, just
                                        # bring the whole thing over.
                                        $PatchedSubmission.listings.$lang.platformOverrides |
                                            Add-Member -Type NoteProperty -Name $platform -Value $($existingListings.$lang.platformOverrides.$platform)
                                    }
                                    else
                                    {
                                        # The PatchedSubmission has an entry for this platform.
                                        # We'll only copy over the images from the cloned submission
                                        # and mark them all as PendingDelete.
                                        $existingListings.$lang.platformOverrides.$platform.images |
                                            ForEach-Object {
                                                $_.FileStatus = $script:keywordPendingDelete
                                                $PatchedSubmission.listings.$lang.platformOverrides.$platform.images += $_
                                            }
                                    }
                                }
                    }
                }

    }

    # For the last four switches, simply copy the field if it is a scalar, or
    # DeepCopy-Object if it is an object.

    if ($UpdatePublishModeAndVisibility)
    {
        $PatchedSubmission.targetPublishMode = Get-ProperEnumCasing -EnumValue ($NewSubmission.targetPublishMode)
        $PatchedSubmission.targetPublishDate = $NewSubmission.targetPublishDate
        $PatchedSubmission.visibility = Get-ProperEnumCasing -EnumValue ($NewSubmission.visibility)
    }

    # If users pass in a different value for any of the publish/visibility values at the commandline,
    # they override those coming from the config.
    if ($TargetPublishMode -ne $script:keywordDefault)
    {
        if (($TargetPublishMode -eq $script:keywordSpecificDate) -and ($null -eq $TargetPublishDate))
        {
            $output = "TargetPublishMode was set to '$script:keywordSpecificDate' but TargetPublishDate was not specified."
            Write-Log -Message $output -Level Error
            throw $output
        }

        $PatchedSubmission.targetPublishMode = Get-ProperEnumCasing -EnumValue $TargetPublishMode
    }

    if ($null -ne $TargetPublishDate)
    {
        if ($TargetPublishMode -ne $script:keywordSpecificDate)
        {
            $output = "A TargetPublishDate was specified, but the TargetPublishMode was [$TargetPublishMode],  not '$script:keywordSpecificDate'."
            Write-Log -Message $output -Level Error
            throw $output
        }

        $PatchedSubmission.targetPublishDate = $TargetPublishDate.ToUniversalTime().ToString('o')
    }

    if ($Visibility -ne $script:keywordDefault)
    {
        $PatchedSubmission.visibility = Get-ProperEnumCasing -EnumValue $Visibility
    }

    if ($UpdatePricingAndAvailability)
    {
        $PatchedSubmission.pricing = DeepCopy-Object $NewSubmission.pricing
        $PatchedSubmission.allowTargetFutureDeviceFamilies = DeepCopy-Object $NewSubmission.allowTargetFutureDeviceFamilies
        $PatchedSubmission.allowMicrosoftDecideAppAvailabilityToFutureDeviceFamilies = $NewSubmission.allowMicrosoftDecideAppAvailabilityToFutureDeviceFamilies
        $PatchedSubmission.enterpriseLicensing = $NewSubmission.enterpriseLicensing
    }

    if ($UpdateAppProperties)
    {
        $PatchedSubmission.applicationCategory = $NewSubmission.applicationCategory
        $PatchedSubmission.hardwarePreferences = $NewSubmission.hardwarePreferences
        $PatchedSubmission.hasExternalInAppProducts = $NewSubmission.hasExternalInAppProducts
        $PatchedSubmission.meetAccessibilityGuidelines = $NewSubmission.meetAccessibilityGuidelines
        $PatchedSubmission.canInstallOnRemovableMedia = $NewSubmission.canInstallOnRemovableMedia
        $PatchedSubmission.automaticBackupEnabled = $NewSubmission.automaticBackupEnabled
        $PatchedSubmission.isGameDvrEnabled = $NewSubmission.isGameDvrEnabled
    }

    if ($UpdateGamingOptions)
    {
        # It's possible that an existing submission object may not have this property at all.
        # Make sure it's there before continuing.
        if ($null -eq $PatchedSubmission.gamingOptions)
        {
            $PatchedSubmission | Add-Member -Type NoteProperty -Name 'gamingOptions' -Value $null
        }

        if ($null -eq $NewSubmission.gamingOptions)
        {
            $output = @()
            $output += "You selected to update the Gaming Options for this submission, but it appears you don't have"
            $output += "that section in your config file.  You should probably re-generate your config file with"
            $output += "New-StoreBrokerConfigFile, transfer any modified properties to that new config file, and then"
            $output += "re-generate your StoreBroker payload with New-SubmissionPackage."
            $output = $output -join [Environment]::NewLine
            Write-Log -Message $output -Level Error
            throw $output
        }

        # Gaming options is an array with a single item, but it's important that we ensure that
        # PowerShell doesn't convert that to just be a single object, so we force it back into
        # an array.
        $PatchedSubmission.gamingOptions = DeepCopy-Object -Object (, $NewSubmission.gamingOptions)
    }

    if ($UpdateTrailers)
    {
        # It's possible that an existing submission object may not have this property at all.
        # Make sure it's there before continuing.
        if ($null -eq $PatchedSubmission.trailers)
        {
            $PatchedSubmission | Add-Member -Type NoteProperty -Name 'trailers' -Value $null
        }

        # Trailers has to be an array, so it's important that in the cases when we have 0 or 1
        # trailers, we don't let PowerShell convert it away from an array to a single object.
        $PatchedSubmission.trailers = DeepCopy-Object -Object (, $NewSubmission.trailers)
    }

    if ($UpdateNotesForCertification)
    {
        $PatchedSubmission.notesForCertification = $NewSubmission.notesForCertification
    }

    # To better assist with debugging, we'll store exactly the original and modified JSON submission bodies.
    $tempFile = [System.IO.Path]::GetTempFileName() # New-TemporaryFile requires PS 5.0
    ($ClonedSubmission | ConvertTo-Json -Depth $script:jsonConversionDepth) | Set-Content -Path $tempFile -Encoding UTF8
    Write-Log -Message "The original cloned JSON content can be found here: [$tempFile]" -Level Verbose

    $tempFile = [System.IO.Path]::GetTempFileName() # New-TemporaryFile requires PS 5.0
    ($PatchedSubmission | ConvertTo-Json -Depth $script:jsonConversionDepth) | Set-Content -Path $tempFile -Encoding UTF8
    Write-Log -Message "The patched JSON content can be found here: [$tempFile]" -Level Verbose

    return $PatchedSubmission
}

function Set-ApplicationSubmission
{
<#
    .SYNOPSIS
        Replaces the content of an existing application submission with the supplied
        submission content.

    .DESCRIPTION
        Replaces the content of an existing application submission with the supplied
        submission content.

        This should be called after having cloned an application submission via
        New-ApplicationSubmission.

        The ID of the submission being updated/replaced will be inferred by the
        submissionId defined in UpdatedSubmission.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER AppId
        The Application ID for the application that the submission is for.

    .PARAMETER UpdatedSubmission
        The updated application submission content that should be used to replace the
        existing submission content.  The Submission ID will be determined from this.

    .PARAMETER AccessToken
        If provided, this will be used as the AccessToken for authentication with the
        REST Api as opposed to requesting a new one.

    .PARAMETER FlightId
        This optional parameter, if provided, will tream the submission being replaced as
        a flight submission as opposed to the regular app published submission.

    .PARAMETER NoStatus
        If this switch is specified, long-running commands will run on the main thread
        with no commandline status update.  When not specified, those commands run in
        the background, enabling the command prompt to provide status information.

    .EXAMPLE
        Set-ApplicationSubmission 0ABCDEF12345 $submissionBody

        Inspects $submissionBody to retrieve the id of the submission in question, and then replaces
        the entire content of that existing submission with the content specified in $submissionBody.

    .EXAMPLE
        Set-ApplicationSubmission 0ABCDEF12345 $submissionBody -NoStatus

        Inspects $submissionBody to retrieve the id of the submission in question, and then replaces
        the entire content of that existing submission with the content specified in $submissionBody.
        The request happens in the foreground and there is no additional status shown to the user
        until a response is returned from the REST request.

    .OUTPUTS
        A PSCustomObject containing the JSON of the updated application submission.
#>
    [CmdletBinding(SupportsShouldProcess)]
    [Alias('Replace-ApplicationSubmission')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="Methods called within here make use of PSShouldProcess, and the switch is passed on to them inherently.")]
    param(
        [Parameter(Mandatory)]
        [string] $AppId,

        [Parameter(Mandatory)]
        [PSCustomObject] $UpdatedSubmission,

        [string] $AccessToken = "",

        [switch] $NoStatus
    )

    Write-Log -Message "[$($MyInvocation.MyCommand.Module.Version)] Executing: $($MyInvocation.Line.Trim())" -Level Verbose

    $submissionId = $UpdatedSubmission.id
    $body = [string]($UpdatedSubmission | ConvertTo-Json -Depth $script:jsonConversionDepth)
    $telemetryProperties = @{ [StoreBrokerTelemetryProperty]::AppId = $AppId }

    $params = @{
        "UriFragment" = "applications/$AppId/submissions/$submissionId"
        "Method" = "Put"
        "Description" = "Replacing the content of Submission: $submissionId for App: $AppId"
        "Body" = $body
        "AccessToken" = $AccessToken
        "TelemetryEventName" = "Set-ApplicationSubmission"
        "TelemetryProperties" = $telemetryProperties
        "NoStatus" = $NoStatus
    }

    return (Invoke-SBRestMethod @params )
}

function Complete-ApplicationSubmission
{
<#
    .SYNOPSIS
        Commits the specified application submission so that it can start the approval process.

    .DESCRIPTION
        Commits the specified application submission so that it can start the approval process.
        Once committed, it is necessary to wait for the submission to either complete or fail
        the approval process before a new application submission can be created/submitted.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER AppId
        The Application ID for the application that has the pending submission to be submitted.

    .PARAMETER SubmissionId
        The ID of the pending submission that should be submitted.

    .PARAMETER AccessToken
        If provided, this will be used as the AccessToken for authentication with the
        REST Api as opposed to requesting a new one.

    .PARAMETER NoStatus
        If this switch is specified, long-running commands will run on the main thread
        with no commandline status update.  When not specified, those commands run in
        the background, enabling the command prompt to provide status information.

    .EXAMPLE
        Commit-ApplicationSubmission 0ABCDEF12345 1234567890123456789
        Marks the pending submission 1234567890123456789 to start the approval process
        for publication, with the console window showing progress while awaiting
        the response from the REST request.

    .EXAMPLE
        Commit-ApplicationSubmission 0ABCDEF12345 1234567890123456789 -NoStatus
        Marks the pending submission 1234567890123456789 to start the approval process
        for publication, but the request happens in the foreground and there is no
        additional status shown to the user until a response is returned from the REST
        request.

    .NOTES
        This uses the "Complete" verb to avoid Powershell import module warnings, but this
        actually only *commits* the submission.  The decision to publish or not is based
        entirely on the contents of the payload included when calling New-ApplicationSubmission.
#>
    [CmdletBinding(SupportsShouldProcess)]
    [Alias('Commit-ApplicationSubmission')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="Methods called within here make use of PSShouldProcess, and the switch is passed on to them inherently.")]
    param(
        [Parameter(Mandatory)]
        [string] $AppId,

        [Parameter(Mandatory)]
        [string] $SubmissionId,

        [string] $AccessToken = "",

        [switch] $NoStatus
    )

    Write-Log -Message "[$($MyInvocation.MyCommand.Module.Version)] Executing: $($MyInvocation.Line.Trim())" -Level Verbose

    try
    {
        $telemetryProperties = @{
            [StoreBrokerTelemetryProperty]::AppId = $AppId
            [StoreBrokerTelemetryProperty]::SubmissionId = $SubmissionId
        }

        $params = @{
            "UriFragment" = "applications/$AppId/submissions/$SubmissionId/Commit"
            "Method" = "Post"
            "Description" = "Committing submission $SubmissionId for App: $AppId"
            "AccessToken" = $AccessToken
            "TelemetryEventName" = "Complete-ApplicationSubmission"
            "TelemetryProperties" = $telemetryProperties
            "NoStatus" = $NoStatus
        }

        $null = Invoke-SBRestMethod @params

        Write-Log -Message @(
            "The submission has been successfully committed.",
            "This is just the beginning though.",
            "It still has multiple phases of validation to get through, and there's no telling how long that might take.",
            "You can view the progress of the submission validation on the Dev Portal here:",
            "    https://dev.windows.com/en-us/dashboard/apps/$AppId/submissions/$submissionId/",
            "or by running this command:",
            "    Get-ApplicationSubmission -AppId $AppId -SubmissionId $submissionId | Format-ApplicationSubmission",
            "You can automatically monitor this submission with this command:",
            "    Start-ApplicationSubmissionMonitor -AppId $AppId -SubmissionId $submissionId -EmailNotifyTo $env:username",
            "",
            ($script:manualPublishWarning -f 'Update-ApplicationSubmission'))
    }
    catch [System.InvalidOperationException]
    {
        throw
    }
}

function Get-ApplicationSubmissionPackageRollout
{
<#
    .SYNOPSIS
        Gets the package rollout information for the specified application submission.

    .DESCRIPTION
        Gets the package rollout information for the specified application submission.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER AppId
        The Application ID for the application that has the package rollout information
        you are interested in.

    .PARAMETER SubmissionId
        The ID of the published submission that has the package rollout information that
        you are interested in.

    .PARAMETER AccessToken
        If provided, this will be used as the AccessToken for authentication with the
        REST Api as opposed to requesting a new one.

    .PARAMETER NoStatus
        If this switch is specified, long-running commands will run on the main thread
        with no commandline status update.  When not specified, those commands run in
        the background, enabling the command prompt to provide status information.

    .EXAMPLE
        Get-ApplicationSubmissionPackageRollout 0ABCDEF12345 1234567890123456789

        Gets the package rollout information for submission 1234567890123456789
        of application 0ABCDEF12345.  The console window will show progress while awaiting
        the response from the REST request.

    .EXAMPLE
        Get-ApplicationSubmissionPackageRollout 0ABCDEF12345 1234567890123456789 -NoStatus

        Gets the package rollout information for submission 1234567890123456789
        of application 0ABCDEF12345.  The request happens in the foreground and there is
        no additional status shown to the user until a response is returned from the REST
        request.
#>
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="Methods called within here make use of PSShouldProcess, and the switch is passed on to them inherently.")]
    param(
        [Parameter(Mandatory)]
        [string] $AppId,

        [Parameter(Mandatory)]
        [string] $SubmissionId,

        [string] $AccessToken = "",

        [switch] $NoStatus
    )

    Write-Log -Message "[$($MyInvocation.MyCommand.Module.Version)] Executing: $($MyInvocation.Line.Trim())" -Level Verbose

    try
    {
        $telemetryProperties = @{
            [StoreBrokerTelemetryProperty]::AppId = $AppId
            [StoreBrokerTelemetryProperty]::SubmissionId = $SubmissionId
        }

        $params = @{
            "UriFragment" = "applications/$AppId/submissions/$SubmissionId/packagerollout"
            "Method" = "Get"
            "Description" = "Getting package rollout on submission $SubmissionId for App: $AppId"
            "AccessToken" = $AccessToken
            "TelemetryEventName" = "Get-ApplicationSubmissionPackageRollout"
            "TelemetryProperties" = $telemetryProperties
            "NoStatus" = $NoStatus
        }

        return (Invoke-SBRestMethod @params)
    }
    catch [System.InvalidOperationException]
    {
        throw
    }
}

function Update-ApplicationSubmissionPackageRollout
{
<#
    .SYNOPSIS
        Updates the package rollout percentage for the specified application submission.

    .DESCRIPTION
        Updates the package rollout percentage for the specified application submission.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER AppId
        The Application ID for the application that has the package rollout information
        you are interested in.

    .PARAMETER SubmissionId
        The ID of the published submission that has the package rollout information that
        you are interested in.

    .PARAMETER Percentage
        The new percentage that should be applied to the submission's package rollout.

    .PARAMETER AccessToken
        If provided, this will be used as the AccessToken for authentication with the
        REST Api as opposed to requesting a new one.

    .PARAMETER NoStatus
        If this switch is specified, long-running commands will run on the main thread
        with no commandline status update.  When not specified, those commands run in
        the background, enabling the command prompt to provide status information.

    .EXAMPLE
        Update-ApplicationSubmissionPackageRollout 0ABCDEF12345 1234567890123456789 20

        Updates the package rollout information for submission 1234567890123456789
        of application 0ABCDEF12345 to be set to 20%.  The console window will show
        progress while awaiting the response from the REST request.

    .EXAMPLE
        Update-ApplicationSubmissionPackageRollout 0ABCDEF12345 1234567890123456789 50.5 -NoStatus

        Updates the package rollout information for submission 1234567890123456789
        of application 0ABCDEF12345 to be set to 50.5%.  The request happens in the
        foreground and there is no additional status shown to the user until a response
        is returned from the REST request.
#>
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="Methods called within here make use of PSShouldProcess, and the switch is passed on to them inherently.")]
    param(
        [Parameter(Mandatory)]
        [string] $AppId,

        [Parameter(Mandatory)]
        [string] $SubmissionId,

        [Parameter(Mandatory)]
        [ValidateRange(0, 100)]
        [double] $Percentage,

        [string] $AccessToken = "",

        [switch] $NoStatus
    )

    Write-Log -Message "[$($MyInvocation.MyCommand.Module.Version)] Executing: $($MyInvocation.Line.Trim())" -Level Verbose

    try
    {
        $telemetryProperties = @{
            [StoreBrokerTelemetryProperty]::AppId = $AppId
            [StoreBrokerTelemetryProperty]::SubmissionId = $SubmissionId
            [StoreBrokerTelemetryProperty]::PackageRolloutPercentage = $Percentage
        }

        $params = @{
            "UriFragment" = "applications/$AppId/submissions/$SubmissionId/updatepackagerolloutpercentage?percentage=$Percentage"
            "Method" = "Post"
            "Description" = "Updating package rollout percentage on submission $SubmissionId for App: $AppId to: $Percentage"
            "AccessToken" = $AccessToken
            "TelemetryEventName" = "Update-ApplicationSubmissionPackageRollout"
            "TelemetryProperties" = $telemetryProperties
            "NoStatus" = $NoStatus
        }

        $null = Invoke-SBRestMethod @params

        Write-Log -Message "Package rollout for this submission has been updated to $Percentage%."

        if ($Percentage -eq 100)
        {
            Write-Log -Level Warning -Message @(
                "Changing the rollout percentage to 100% does not ensure that all of your customers will get the",
                "packages from the latest submissions, because some customers may be on OS versions that don't",
                "support rollout. You must finalize the rollout in order to stop distributing the older packages",
                "and update all existing customers to the newer ones by calling",
                "    Complete-ApplicationFlightSubmissionPackageRollout -AppId $AppId -FlightId $FlightId -SubmissionId $SubmissionId")
        }
    }
    catch [System.InvalidOperationException]
    {
        throw
    }
}

function Stop-ApplicationSubmissionPackageRollout
{
<#
    .SYNOPSIS
        Stops the package rollout for the specified application submission.

    .DESCRIPTION
        Stops the package rollout for the specified application submission.
        All users will now begin receiving the fallback submission.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER AppId
        The Application ID for the application that is currently being rolled out.

    .PARAMETER SubmissionId
        The ID of the published submission that is currently being rolled out.

    .PARAMETER AccessToken
        If provided, this will be used as the AccessToken for authentication with the
        REST Api as opposed to requesting a new one.

    .PARAMETER NoStatus
        If this switch is specified, long-running commands will run on the main thread
        with no commandline status update.  When not specified, those commands run in
        the background, enabling the command prompt to provide status information.

    .EXAMPLE
        Stop-ApplicationSubmissionPackageRollout 0ABCDEF12345 1234567890123456789

        Halts the package rollout for submission 1234567890123456789 of application
        0ABCDEF12345.  Users will now begin receiving the packages from the fallback
        submission. The console window will show progress while awaiting the response
        from the REST request.

    .EXAMPLE
        Stop-ApplicationSubmissionPackageRollout 0ABCDEF12345 1234567890123456789 -NoStatus

        Halts the package rollout for submission 1234567890123456789 of application
        0ABCDEF12345.  Users will now begin receiving the packages from the fallback
        submission. The request happens in the foreground and there is no additional
        status shown to the user until a response is returned from the REST request.
#>
    [CmdletBinding(SupportsShouldProcess)]
    [Alias('Halt-ApplicationSubmissionPackageRollout')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="Methods called within here make use of PSShouldProcess, and the switch is passed on to them inherently.")]
    param(
        [Parameter(Mandatory)]
        [string] $AppId,

        [Parameter(Mandatory)]
        [string] $SubmissionId,

        [string] $AccessToken = "",

        [switch] $NoStatus
    )

    Write-Log -Message "[$($MyInvocation.MyCommand.Module.Version)] Executing: $($MyInvocation.Line.Trim())" -Level Verbose

    try
    {
        $telemetryProperties = @{
            [StoreBrokerTelemetryProperty]::AppId = $AppId
            [StoreBrokerTelemetryProperty]::SubmissionId = $SubmissionId
        }

        $params = @{
            "UriFragment" = "applications/$AppId/submissions/$SubmissionId/haltpackagerollout"
            "Method" = "Post"
            "Description" = "Halting package rollout on submission $SubmissionId for App: $AppId"
            "AccessToken" = $AccessToken
            "TelemetryEventName" = "Stop-ApplicationSubmissionPackageRollout"
            "TelemetryProperties" = $telemetryProperties
            "NoStatus" = $NoStatus
        }

        $result = Invoke-SBRestMethod @params

        Write-Log -Message @(
            "Package rollout for this submission has been halted.",
            "Users will now receive the packages from SubmissionId: $($result.fallbackSubmissionId)")

        Write-Log -Level Warning -Message @(
            "Any customers who already have the newer packages will keep those packages; they won't be rolled back to the previous version.",
            "To provide an update to these customers, you'll need to create a new submission with the packages you'd like them to get.",
            "Note that if you use a gradual rollout in your next submission, customers who had the package you halted will be offered",
            "the new update in the same order they were offered the halted package.  The new rollout will be between your last finalized",
            "submission and your newest submission; once you halt a package rollout, those packages will no longer be distributed to any customers.")
    }
    catch [System.InvalidOperationException]
    {
        throw
    }
}

function Complete-ApplicationSubmissionPackageRollout
{
<#
    .SYNOPSIS
        Finalizes the package rollout for the specified application submission.

    .DESCRIPTION
        Finalizes the package rollout for the specified application submission.
        All users will now begin receiving this submission's packages.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER AppId
        The Application ID for the application that is currently being rolled out.

    .PARAMETER SubmissionId
        The ID of the published submission that is currently being rolled out.

    .PARAMETER AccessToken
        If provided, this will be used as the AccessToken for authentication with the
        REST Api as opposed to requesting a new one.

    .PARAMETER NoStatus
        If this switch is specified, long-running commands will run on the main thread
        with no commandline status update.  When not specified, those commands run in
        the background, enabling the command prompt to provide status information.

    .EXAMPLE
        Complete-ApplicationSubmissionPackageRollout 0ABCDEF12345 1234567890123456789

        Finalizes the package rollout for submission 1234567890123456789 of application
        0ABCDEF12345.  All users will now begin receiving the packages from this
        submission. The console window will show progress while awaiting the response
        from the REST request.

    .EXAMPLE
        Complete-ApplicationSubmissionPackageRollout 0ABCDEF12345 1234567890123456789 -NoStatus

        Finalizes the package rollout for submission 1234567890123456789 of application
        0ABCDEF12345.  All users will now begin receiving the packages from this
        submission. The request happens in the foreground and there is no additional
        status shown to the user until a response is returned from the REST request.
#>
    [CmdletBinding(SupportsShouldProcess)]
    [Alias('Finalize-ApplicationSubmissionPackageRollout')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="Methods called within here make use of PSShouldProcess, and the switch is passed on to them inherently.")]
    param(
        [Parameter(Mandatory)]
        [string] $AppId,

        [Parameter(Mandatory)]
        [string] $SubmissionId,

        [string] $AccessToken = "",

        [switch] $NoStatus
    )

    Write-Log -Message "[$($MyInvocation.MyCommand.Module.Version)] Executing: $($MyInvocation.Line.Trim())" -Level Verbose

    try
    {
        $telemetryProperties = @{
            [StoreBrokerTelemetryProperty]::AppId = $AppId
            [StoreBrokerTelemetryProperty]::SubmissionId = $SubmissionId
        }

        $params = @{
            "UriFragment" = "applications/$AppId/submissions/$SubmissionId/finalizepackagerollout"
            "Method" = "Post"
            "Description" = "Finalizing package rollout on submission $SubmissionId for App: $AppId"
            "AccessToken" = $AccessToken
            "TelemetryEventName" = "Complete-ApplicationSubmissionPackageRollout"
            "TelemetryProperties" = $telemetryProperties
            "NoStatus" = $NoStatus
        }

        $null = Invoke-SBRestMethod @params

        Write-Log -Message "Package rollout for this submission has been finalized.  All users will now receive these packages."
    }
    catch [System.InvalidOperationException]
    {
        throw
    }
}
