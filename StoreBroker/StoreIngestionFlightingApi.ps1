# Copyright (C) Microsoft Corporation.  All rights reserved.

function Get-ApplicationFlights
{
<#
    .SYNOPSIS
        Retrieves all flights associated with the specified application for this
        developer account.

    .DESCRIPTION
        Retrieves all flights associated with the specified application for this
        developer account.
        Pipe the result of this command into Format-ApplicationFlights for a
        pretty-printed display of the results.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER AppId
        The Application ID for the application that you want to retrieve the information
        about.

    .PARAMETER MaxResults
        The number of flight for this application that should be returned in the query.
        Defaults to 100.

    .PARAMETER StartAt
        The 0-based index (of all flights for this app) that the returned
        results should start returning from.
        Defaults to 0.

    .PARAMETER GetAll
        If this switch is specified, the cmdlet will automatically loop in batches
        to get all of the flights for this application.  Using this will ignore
        the provided value for -StartAt, but will use the value provided for
        -MaxResults as its per-query limit.
        WARNING: This might take a while depending on how many applications and
        flights are in your developer account.

    .PARAMETER NoStatus
        If this switch is specified, long-running commands will run on the main thread
        with no commandline status update.  When not specified, those commands run in
        the background, enabling the command prompt to provide status information.

    .EXAMPLE
        Get-ApplicationFlights 0ABCDEF12345

        Gets all of the flights associated with this applications in this developer account,
        with the console window showing progress while awaiting for the response
        from the REST request.

    .EXAMPLE
        Get-ApplicationFlights 0ABCDEF12345 -NoStatus

        Gets all of the flights associated with this applications in this developer account,
        but the request happens in the foreground and there is no additional status
        shown to the user until a response is returned from the REST request.

    .EXAMPLE
        $flights = Get-ApplicationFlights 0ABCDEF12345

        Retrieves all of the flights associated with this developer account,
        and saves the results in a variable called $flights that can be used for
        further processing.

    .EXAMPLE
        Get-ApplicationFlights 0ABCDEF12345 | Format-ApplicationFlights

        Gets all of the flights associated with this applications in this developer account,
        and then displays it in a pretty-printed, formatted result.
#>
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "", Justification="Designed to mimic the actual API.")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="Methods called within here make use of PSShouldProcess, and the switch is passed on to them inherently.")]
    param(
        [Parameter(Mandatory)]
        [string] $AppId,
        
        [ValidateScript({if ($_ -gt 0) { $true } else { throw "Must be greater than 0." }})]
        [int] $MaxResults = 100,

        [ValidateScript({if ($_ -ge 0) { $true } else { throw "Must be greater than or equal to 0." }})]
        [int] $StartAt = 0,

        [string] $AccessToken = "",

        [switch] $GetAll,

        [switch] $NoStatus
    )

    Write-Log "Executing: $($MyInvocation.Line)" -Level Verbose

    $telemetryProperties = @{ [StoreBrokerTelemetryProperty]::AppId = $AppId }

    $params = @{
        "UriFragment" = "applications/$AppId/listflights/"
        "Description" = "Getting flights for AppId: $AppId"
        "MaxResults" = $MaxResults
        "StartAt" = $StartAt
        "AccessToken" = $AccessToken
        "TelemetryEventName" = "Get-ApplicationFlights"
        "TelemetryProperties" = $telemetryProperties
        "GetAll" = $GetAll
        "NoStatus" = $NoStatus
    }

    return (Invoke-SBRestMethodMultipleResult @params)
}

function Format-ApplicationFlights
{
<#
    .SYNOPSIS
        Pretty-prints the results of Get-ApplicationFlights

    .DESCRIPTION
        This method is intended to be used by callers of Get-ApplicationFlights.
        It takes the result from Get-ApplicationFlights and presents it in a more easily
        viewable manner.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER ApplicationFlightsData
        The output returned from Get-ApplicationFlights.
        Supports Pipeline input.

    .EXAMPLE
        Format-ApplicationFlights (Get-ApplicationFlights 0ABCDEF12345)

        Explicitly gets the result from Get-ApplicationFlights and passes that in as the input
        to Format-ApplicationFlights for pretty-printing.

    .EXAMPLE
        Get-ApplicationFlights 0ABCDEF12345 | Format-ApplicationFlights

        Pipes the result of Get-ApplicationFlights directly into Format-ApplicationFlights
        for pretty-printing.
#>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "", Justification="Formatting method designed to mimic the actual API method.")]
    param(
        [Parameter(
            Mandatory,
            ValueFromPipeline)]
        [PSCustomObject] $ApplicationFlightsData
    )

    Begin
    {
        Set-TelemetryEvent -EventName Format-ApplicationFlights

        Write-Log "Displaying Application Flights..." -Level Verbose

        $publishedSubmissionField = @{ label="lastPublishedSubmission"; Expression={ if ([String]::IsNullOrEmpty($_.lastPublishedFlightSubmission.id)) { "<None>" } else { $_.lastPublishedFlightSubmission.id } }; }
        $pendingSubmissionField = @{ label="pendingSubmission"; Expression={ if ($null -eq $_.pendingFlightSubmission) { "<None>" } else { $_.pendingFlightSubmission.id } }; }

        $flights = @()
    }

    Process
    {
        $flights += $ApplicationFlightsData
    }

    End
    {
        Write-Log $($flights | Format-Table friendlyName, flightId, rankHigherThan, $publishedSubmissionField, $pendingSubmissionField, groupIds | Out-String)
    }
}

function Get-ApplicationFlight
{
<#
    .SYNOPSIS
        Retrieves the detail for the specified flight associated with the application in this
        developer account.

    .DESCRIPTION
        Retrieves the detail for the specified flight associated with the application in this
        developer account.
        Pipe the result of this command into Format-ApplicationFlight for a pretty-printed display
        of the result.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER AppId
        The Application ID for the application that you want to retrieve the information
        about.

    .PARAMETER FlightId
        The Flight ID for the flight of the application that you want to retrieve the information
        about.

    .PARAMETER NoStatus
        If this switch is specified, long-running commands will run on the main thread
        with no commandline status update.  When not specified, those commands run in
        the background, enabling the command prompt to provide status information.

    .EXAMPLE
        Get-ApplicationFlight 0ABCDEF12345 01234567-89ab-cdef-0123-456789abcdef

        Gets the detail for this application's flight with the console window showing progress
        while awaiting for the response from the REST request.

    .EXAMPLE
        Get-ApplicationFlight 0ABCDEF12345 01234567-89ab-cdef-0123-456789abcdef -NoStatus

        Gets the detail for this application's flight, but the request happens in the
        foreground and there is no additional status shown to the user until a response
        is returned from the REST request.

    .EXAMPLE
        $flight = Get-ApplicationFlight 0ABCDEF12345 01234567-89ab-cdef-0123-456789abcdef

        Retrieves the detail for this application's flight, and saves the results in a
        variable called $flight that can be used for further processing.

    .EXAMPLE
        Get-ApplicationFlight 0ABCDEF12345 01234567-89ab-cdef-0123-456789abcdef | Format-ApplicationFlight

        Gets the detail for this application's flight, and then displays it in a pretty-printed,
        formatted result.
#>
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="Methods called within here make use of PSShouldProcess, and the switch is passed on to them inherently.")]
    param(
        [Parameter(Mandatory)]
        [string] $AppId,
        
        [Parameter(Mandatory)]
        [string] $FlightId,

        [string] $AccessToken = "",

        [switch] $NoStatus
    )

    Write-Log "Executing: $($MyInvocation.Line)" -Level Verbose

    $telemetryProperties = @{
        [StoreBrokerTelemetryProperty]::AppId = $AppId
        [StoreBrokerTelemetryProperty]::FlightId = $FlightId
    }

    $params = @{
        "UriFragment" = "applications/$AppId/flights/$FlightId"
        "Method" = "Get"
        "Description" = "Getting data for AppId: $AppId FlightId: $FlightId"
        "AccessToken" = $AccessToken
        "TelemetryEventName" = "Get-ApplicationFlight"
        "TelemetryProperties" = $telemetryProperties
        "NoStatus" = $NoStatus
    }

    return (Invoke-SBRestMethod @params)
}

function Format-ApplicationFlight
{
<#
    .SYNOPSIS
        Pretty-prints the results of Get-ApplicationFlight

    .DESCRIPTION
        This method is intended to be used by callers of Get-ApplicationFlight.
        It takes the result from Get-ApplicationFlight and presents it in a more easily
        viewable manner.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER ApplicationFlightData
        The output returned from Get-ApplicationFlight.
        Supports Pipeline input.

    .EXAMPLE
        Format-ApplicationFlight $(Get-ApplicationFlight 0ABCDEF12345)

        Explicitly gets the result from Get-ApplicationFlight and passes that in as the input
        to Format-ApplicationFlight for pretty-printing.

    .EXAMPLE
        Get-ApplicationFlight 0ABCDEF12345 | Format-ApplicationFlight

        Pipes the result of Get-ApplicationFlight directly into Format-ApplicationFlight for pretty-printing.
#>
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory,
            ValueFromPipeline)]
        [PSCustomObject] $ApplicationFlightData
    )

    Begin
    {
        Set-TelemetryEvent -EventName Format-ApplicationFlight

        Write-Log "Displaying Application Flight..." -Level Verbose

        $indentLength = 5
        $output = @()
    }

    Process
    {
        $output += ""
        $output += "Friendly Name             : $($ApplicationFlightData.friendlyName)"
        $output += "Id                        : $($ApplicationFlightData.flightId)"
        $output += "RankHigherThan            : $($ApplicationFlightData.rankHigherThan)"
        $output += "Flight Group Id's         :"
        foreach ($groupId in $ApplicationFlightData.groupIds)
        {
            # We are including a URL to view the Group because there currently exists no way to
            # get Flight Group information via the API
            $output += "$(" " * $indentLength)$groupId  | https://developer.microsoft.com/en-us/dashboard/groups/editgroup/$groupId"
        }

        $output += "Last Published Submission : $(if ($null -eq $ApplicationFlightData.lastPublishedFlightSubmission.id) { "---" } else { $ApplicationFlightData.lastPublishedFlightSubmission.id } )"
        $output += "Pending Submission        : $(if ($null -eq $ApplicationFlightData.pendingFlightSubmission.id) { "---" } else { $ApplicationFlightData.pendingFlightSubmission.id } )"
    }

    End
    {
        Write-Log $($output -join [Environment]::NewLine)
    }
}

function Get-FlightGroups
{
<#
    .SYNOPSIS
        Launches the Dev Portal in the default web browser to display all of the available flight groups.

    .DESCRIPTION
        Launches the Dev Portal in the default web browser to display all of the available flight groups.
        This is necessary because there currently exists no API to programatically browse these groups.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .EXAMPLE
        Open-ApplicationFlightGroups

        Opens a new tab in the default web browser to the page in the Dev Portal that displays
        all of the available flight groups.
#>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "", Justification="Designed to mimic the (expected) actual API.")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidGlobalVars", "", Justification="We use global variables sparingly and intentionally for module configuration, and employ a consistent naming convention.")]
    param()

    Set-TelemetryEvent -EventName Get-FlightGroups

    Write-Log "Opening the Dev Portal UI in your default browser to view flight groups because there is currently no API access for this data."
    Write-Log "The FlightGroupID is the number at the end of the URL when you click on any flight group name."

    if (-not [String]::IsNullOrWhiteSpace($global:SBInternalGroupIds))
    {
        Write-Log "For the Microsoft-internal pre-defined flight group ids, see below:"
        Write-Log "`n$($global:SBInternalGroupIds | Format-Table Name, @{ label="FlightGroupId"; Expression={ $_.Value }; }| Out-String)"
    }

    Start-Process -FilePath "https://developer.microsoft.com/en-us/dashboard/groups"
}

function New-ApplicationFlight
{
    <#
    .SYNOPSIS
        Creates a new flight (with associated flight groups) for an application.

    .DESCRIPTION
        Creates a new flight (with associated flight groups) for an application.

    .PARAMETER AppId
        The Application ID for the application that the new flight is for.

    .PARAMETER FriendlyName
        A name that you can use to easily refer to the new flight.

    .PARAMETER GroupIds
        The list of Flight Group Ids that should be part of this new Flight.
 
    .PARAMETER RankHigherThan
        The friendlyName of the Flight that this should be ranked higher than.
        If not provided, this will be ranked highest of all current flights.

    .PARAMETER AccessToken
        If provided, this will be used as the AccessToken for authentication with the
        REST Api as opposed to requesting a new one.

    .PARAMETER NoStatus
        If this switch is specified, long-running commands will run on the main thread
        with no commandline status update.  When not specified, those commands run in
        the background, enabling the command prompt to provide status information.

    .EXAMPLE
        New-ApplicationFlight 0ABCDEF12345 Alpha 1,2

        Creates a new flight called "Alpha" that will be ranked higher than all other flights
        for this application.  It will use the two internal Microsoft flight groups (Canary Insiders
        and Selfhost Insiders).  The console window showing progress while awaiting for the response
        from the REST request.

    .EXAMPLE
        New-ApplicationFlight 0ABCDEF12345 Beta 6 Gamma -NoStatus

        Creates a new flight called "Beta" that will be ranked higher than the "Gamma" flight
        for this application.  It will use the internal Microsoft flight group "Release Preview.
        and Selfhost Insiders).  The request happens in the foreground and there is no additional
        status shown to the user until a response is returned from the REST request.
#>
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="Methods called within here make use of PSShouldProcess, and the switch is passed on to them inherently.")]
    param(
        [Parameter(Mandatory)]
        [string] $AppId,
        
        [Parameter(Mandatory)]
        [string] $FriendlyName,

        [Parameter(Mandatory)]
        [string[]] $GroupIds,

        [string] $RankHigherThan = $null,

        [string] $AccessToken = "",

        [switch] $NoStatus
    )

    Write-Log "Executing: $($MyInvocation.Line)" -Level Verbose

    # Convert the input into a Json body.
    $hashBody = @{}
    $hashBody["friendlyName"] = $FriendlyName
    $hashBody["groupIds"] = $GroupIds
    if (-not [String]::IsNullOrEmpty($RankHigherThan))
    {
        $hashBody["rankHigherThan"] = $RankHigherThan
    }
    
    $body = $hashBody | ConvertTo-Json

    $telemetryProperties = @{ [StoreBrokerTelemetryProperty]::AppId = $AppId }

    $params = @{
        "UriFragment" = "applications/$AppId/flights/"
        "Method" = "Post"
        "Description" = "Creating a new flight called: $FriendlyName for AppId: $AppId"
        "Body" = $body
        "AccessToken" = $AccessToken
        "TelemetryEventName" = "New-ApplicationFlight"
        "TelemetryProperties" = $telemetryProperties
        "NoStatus" = $NoStatus
    }

    try
    {
        $result = Invoke-SBRestMethod @params

        $output = @()
        $output += "The new flight has been successfully created."
        $output += "As a result of creating this new flight, a new submission has already been started."
        $output += "For the *first* submission, instead of using the `"-Force`" parameter with Update-ApplicationFlightSubmission"
        $output += "to remove a pre-existing pending submission before starting a new one, you should"
        $output += "instead use the -SubmissionId parameter and reference this pre-existing submission like so:"
        $output += "    Update-ApplicationSubmission -AppId $AppId -Flight $($result.flightId) -SubmissionId $($result.pendingFlightSubmission.id) <your additional parameters>"
        Write-Log $($output -join [Environment]::NewLine)

        return $result
    }
    catch
    {
        throw
    }
}

function Remove-ApplicationFlight
{
    <#
    .SYNOPSIS
        Deletes the specified flight from an application in the developer's account.

    .DESCRIPTION
        Deletes the specified flight from an application in the developer's account.

    .PARAMETER AppId
        The Application ID for the application that has the flight being removed.

    .PARAMETER FlightId
        The ID of the flight that should be removed.

    .PARAMETER AccessToken
        If provided, this will be used as the AccessToken for authentication with the
        REST Api as opposed to requesting a new one.

    .PARAMETER NoStatus
        If this switch is specified, long-running commands will run on the main thread
        with no commandline status update.  When not specified, those commands run in
        the background, enabling the command prompt to provide status information.

    .EXAMPLE
        Remove-ApplicationFlight 0ABCDEF12345 01234567-89ab-cdef-0123-456789abcdef

        Removes the specified flight from the application in the developer's account,
        with the console window showing progress while awaiting for the response
        from the REST request.

    .EXAMPLE
        Remove-ApplicationFlight 0ABCDEF12345 01234567-89ab-cdef-0123-456789abcdef -NoStatus

        Removes the specified flight from the application in the developer's account,
        but the request happens in the foreground and there is no additional status
        shown to the user until a response is returned from the REST request.
#>
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="Methods called within here make use of PSShouldProcess, and the switch is passed on to them inherently.")]
    param(
        [Parameter(Mandatory)]
        [string] $AppId,
        
        [Parameter(Mandatory)]
        [string] $FlightId,

        [string] $AccessToken = "",

        [switch] $NoStatus
    )

    Write-Log "Executing: $($MyInvocation.Line)" -Level Verbose

    $telemetryProperties = @{
        [StoreBrokerTelemetryProperty]::AppId = $AppId
        [StoreBrokerTelemetryProperty]::FlightId = $FlightId
    }
    
    $params = @{
        "UriFragment" = "applications/$AppId/flights/$FlightId"
        "Method" = "Delete"
        "Description" = "Deleting flight: $FlightId for AppId: $AppId"
        "AccessToken" = $AccessToken
        "TelemetryEventName" = "Remove-ApplicationFlight"
        "TelemetryProperties" = $telemetryProperties
        "NoStatus" = $NoStatus
    }

    $null = Invoke-SBRestMethod @params
}

function Get-ApplicationFlightSubmission
{
<#
    .SYNOPSIS
        Retrieves the details of a specific application flight submission.

    .DESCRIPTION
        Gets the details of a specific application flight submission.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER AppId
        The Application ID for the application that you want to retrieve the information
        about.

    .PARAMETER FlightId
        The Flight ID for the application that you want to retrieve the information
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
        Get-ApplicationFlightSubmission 0ABCDEF12345 01234567-89ab-cdef-0123-456789abcdef 1234567890123456789

        Gets all of the detail known for this application's flight submission,
        with the console window showing progress while awaiting for the response
        from the REST request.

    .EXAMPLE
        Get-ApplicationFlightSubmission 0ABCDEF12345 01234567-89ab-cdef-0123-456789abcdef 1234567890123456789 -NoStatus

        Gets all of the detail known for this application's flight submission,
        but the request happens in the foreground and there is no additional status
        shown to the user until a response is returned from the REST request.

    .EXAMPLE
        $submission = Get-ApplicationFlightSubmission 0ABCDEF12345 01234567-89ab-cdef-0123-456789abcdef 1234567890123456789

        Retrieves all of the application's flight submission detail, and saves the results in
        a variable called $submission that can be used for further processing.

    .EXAMPLE
        Get-ApplicationFlightSubmission 0ABCDEF12345 01234567-89ab-cdef-0123-456789abcdef 1234567890123456789 | Format-ApplicationFlightSubmission

        Pretty-print the results by piping them into Format-ApplicationFlightSubmission.
#>
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="Methods called within here make use of PSShouldProcess, and the switch is passed on to them inherently.")]
    param(
        [Parameter(Mandatory)]
        [string] $AppId,
        
        [Parameter(Mandatory)]
        [string] $FlightId,

        [Parameter(Mandatory)]
        [string] $SubmissionId,
        
        [string] $AccessToken = "",

        [switch] $NoStatus
    )

    Write-Log "Executing: $($MyInvocation.Line)" -Level Verbose

    $telemetryProperties = @{
        [StoreBrokerTelemetryProperty]::AppId = $AppId
        [StoreBrokerTelemetryProperty]::FlightId = $FlightId
        [StoreBrokerTelemetryProperty]::SubmissionId = $SubmissionId
    }

    $params = @{
        "UriFragment" = "applications/$AppId/flights/$FlightId/submissions/$SubmissionId"
        "Method" = "Get"
        "Description" = "Getting SubmissionId: $SubmissionId for AppId: $AppId FlightId: $FlightId"
        "AccessToken" = $AccessToken
        "TelemetryEventName" = "Get-ApplicationFlightSubmission"
        "TelemetryProperties" = $telemetryProperties
        "NoStatus" = $NoStatus
    }

    return (Invoke-SBRestMethod @params)
}

function Format-ApplicationFlightSubmission
{
<#
    .SYNOPSIS
        Pretty-prints the results of Get-ApplicationFlightSubmission

    .DESCRIPTION
        This method is intended to be used by callers of Get-ApplicationFlightSubmission.
        It takes the result from Get-ApplicationFlightSubmission and presents it in a more easily
        viewable manner.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER ApplicationFlightSubmissionData
        The output returned from Get-ApplicationFlightSubmission.
        Supports Pipeline input.

    .EXAMPLE
        Format-ApplicationFlightSubmission $(Get-ApplicationFlightSubmission 0ABCDEF12345 01234567-89ab-cdef-0123-456789abcdef 1234567890123456789)
        Explicitly gets the result from Get-ApplicationFlightSubmission and passes that in as the input
        to Format-ApplicationSubmission for pretty-printing.

    .EXAMPLE
        Get-ApplicationFlightSubmission 0ABCDEF12345 01234567-89ab-cdef-0123-456789abcdef 1234567890123456789 | Format-ApplicationFlightSubmission
        Pipes the result of Get-ApplicationFlightSubmission directly into Format-ApplicationFlightSubmission for pretty-printing.
#>
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory,
            ValueFromPipeline)]
        [PSCustomObject] $ApplicationFlightSubmissionData
    )

    Begin
    {
        Set-TelemetryEvent -EventName Format-ApplicationFlightSubmission

        Write-Log "Displaying Application Submission..." -Level Verbose

        $indentLength = 5
        $output = @()
    }

    Process
    {
        $output += ""
        $output += "Submission Id                       : $($ApplicationFlightSubmissionData.id)"
        $output += "Flight Id                           : $($ApplicationFlightSubmissionData.flightId)"
        $output += "Publish Mode                        : $($ApplicationFlightSubmissionData.targetPublishMode)"
        if ($null -ne $ApplicationFlightSubmissionData.targetPublishDate)
        {
            $output += "Publish Date                        : $(Get-Date -Date $ApplicationFlightSubmissionData.targetPublishDate -Format R)"
        }

        $output += "Notes For Certification             : $($ApplicationFlightSubmissionData.notesForCertification)"
        $output += ""

        $output += "File Upload Url                     : {0}" -f $(if ($ApplicationFlightSubmissionData.fileUploadUrl) { $ApplicationFlightSubmissionData.fileUploadUrl } else { "<None>" })
        $output += ""

        $output += "Flight Packages                     : {0}" -f $(if ($ApplicationFlightSubmissionData.flightPackages.count -eq 0) { "<None>" } else { "" })
        $output += $ApplicationFlightSubmissionData.flightPackages | Format-SimpleTableString -IndentationLevel $indentLength
        $output += ""

        $output += "Status                                 : $($ApplicationFlightSubmissionData.status)"
        $output += "Status Details [Errors]                : {0}" -f $(if ($ApplicationFlightSubmissionData.statusDetails.errors.count -eq 0) { "<None>" } else { "" })
        $output += $ApplicationFlightSubmissionData.statusDetails.errors | Format-SimpleTableString -IndentationLevel $indentLength
        $output += ""

        $output += "Status Details [Warnings]              : {0}" -f $(if ($ApplicationFlightSubmissionData.statusDetails.warnings.count -eq 0) { "<None>" } else { "" })
        $output += $ApplicationFlightSubmissionData.statusDetails.warnings | Format-SimpleTableString -IndentationLevel $indentLength
        $output += ""

        $output += "Status Details [Certification Reports] : {0}" -f $(if ($ApplicationFlightSubmissionData.statusDetails.certificationReports.count -eq 0) { "<None>" } else { "" })
        foreach ($report in $ApplicationFlightSubmissionData.statusDetails.certificationReports)
        {
            $output += $(" " * $indentLength) + $(Get-Date -Date $report.date -Format R) + ": $($report.reportUrl)"
        }
    }

    End
    {
        Write-Log $($output -join [Environment]::NewLine)
    }
}

function Get-ApplicationFlightSubmissionStatus
{
<#
    .SYNOPSIS
        Retrieves just the status of a specific application flight submission.

    .DESCRIPTION
        Gets just the status of a specific application flight submission.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER AppId
        The Application ID for the application that you want to retrieve the information
        about.

    .PARAMETER FlightId
        The Flight ID for the application that you want to retrieve the information
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
        Get-ApplicationFlightSubmissionStatus 0ABCDEF12345 01234567-89ab-cdef-0123-456789abcdef 1234567890123456789

        Gets the status of this application's flight submission, with the console window showing
        progress while awaiting for the response from the REST request.

    .EXAMPLE
        Get-ApplicationFlightSubmissionStatus 0ABCDEF12345 01234567-89ab-cdef-0123-456789abcdef 1234567890123456789 -NoStatus

        Gets the status of this application's flight submission, but the request happens in the
        foreground and there is no additional status shown to the user until a response is
        returned from the REST request.

    .EXAMPLE
        $submission = Get-ApplicationFlightSubmissionStatus 0ABCDEF12345 01234567-89ab-cdef-0123-456789abcdef 1234567890123456789

        Retrieves the status of the application's flight submission, and saves the results in
        a variable called $submission that can be used for further processing.
#>
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="Methods called within here make use of PSShouldProcess, and the switch is passed on to them inherently.")]
    param(
        [Parameter(Mandatory)]
        [string] $AppId,
        
        [Parameter(Mandatory)]
        [string] $FlightId,

        [Parameter(Mandatory)]
        [string] $SubmissionId,
        
        [string] $AccessToken = "",

        [switch] $NoStatus
    )

    Write-Log "Executing: $($MyInvocation.Line)" -Level Verbose

    $telemetryProperties = @{
        [StoreBrokerTelemetryProperty]::AppId = $AppId
        [StoreBrokerTelemetryProperty]::FlightId = $FlightId
        [StoreBrokerTelemetryProperty]::SubmissionId = $SubmissionId
    }

    $params = @{
        "UriFragment" = "applications/$AppId/flights/$FlightId/submissions/$SubmissionId/status"
        "Method" = "Get"
        "Description" = "Getting status of SubmissionId: $SubmissionId for AppId: $AppId FlightId: $FlightId"
        "AccessToken" = $AccessToken
        "TelemetryEventName" = "Get-ApplicationFlightSubmissionStatus"
        "TelemetryProperties" = $telemetryProperties
        "NoStatus" = $NoStatus
    }

    return (Invoke-SBRestMethod @params)
}

function Remove-ApplicationFlightSubmission
{
    <#
    .SYNOPSIS
        Deletes the specified application flight submission from a developer account.

    .DESCRIPTION
        Deletes the specified application flight submission from a developer account.
        An app flight can only have a single "pending" submission at any given time,
        and submissions cannot be modified via the REST API once started.
        Therefore, before a new application flight submission can be submitted,
        this method must be called to remove any existing pending submission.

    .PARAMETER AppId
        The Application ID for the application that has the pending flight submission to be removed.

    .PARAMETER FlightId
        The Flight ID for the flight that has the pending submission to be removed.

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
        Remove-ApplicationFlightSubmission 0ABCDEF12345 01234567-89ab-cdef-0123-456789abcdef 1234567890123456789

        Removes the specified application flight submission from the developer account,
        with the console window showing progress while awaiting for the response
        from the REST request.

    .EXAMPLE
        Remove-ApplicationFlightSubmission 0ABCDEF12345 01234567-89ab-cdef-0123-456789abcdef 1234567890123456789 -NoStatus

        Removes the specified application flight submission from the developer account,
        but the request happens in the foreground and there is no additional status
        shown to the user until a response is returned from the REST request.
#>
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="Methods called within here make use of PSShouldProcess, and the switch is passed on to them inherently.")]
    param(
        [Parameter(Mandatory)]
        [string] $AppId,
        
        [Parameter(Mandatory)]
        [string] $FlightId,

        [Parameter(Mandatory)]
        [string] $SubmissionId,

        [string] $AccessToken = "",

        [switch] $NoStatus
    )

    Write-Log "Executing: $($MyInvocation.Line)" -Level Verbose

    $telemetryProperties = @{
        [StoreBrokerTelemetryProperty]::AppId = $AppId
        [StoreBrokerTelemetryProperty]::FlightId = $FlightId
        [StoreBrokerTelemetryProperty]::SubmissionId = $SubmissionId
    }

    $params = @{
        "UriFragment" = "applications/$AppId/flights/$FlightId/submissions/$SubmissionId"
        "Method" = "Delete"
        "Description" = "Deleting submission: $SubmissionId for App: $AppId Flight: $FlightId"
        "AccessToken" = $AccessToken
        "TelemetryEventName" = "Remove-ApplicationFlightSubmission"
        "TelemetryProperties" = $telemetryProperties
        "NoStatus" = $NoStatus
    }

    $null = Invoke-SBRestMethod @params
}

function New-ApplicationFlightSubmission
{
<#
    .SYNOPSIS
        Creates a submission for an existing application flight.

    .DESCRIPTION
        Creates a submission for an existing application flight.
        You cannot create a new application submission if there is an existing pending
        application submission for $AppId already.  You can use -Force to work around
        this.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER AppId
        The Application ID for the application that the new submission is for.

    .PARAMETER FlightId
        The Flight ID for the flight that the new submission is for.

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
        New-ApplicationFlightSubmission 0ABCDEF12345 01234567-89ab-cdef-0123-456789abcdef -NoStatus

        Creates a new application submission for the flight 01234567-89ab-cdef-0123-456789abcdef
        under the app 0ABCDEF12345 that is an exact clone of the currently published submission,
        but the request happens in the foreground and there is no additional status shown to the
        user until a response is returned from the REST request.
        If successful, will return back the PSCustomObject representing the newly created
        flight submission.

    .EXAMPLE
        New-ApplicationFlightSubmission 0ABCDEF12345 01234567-89ab-cdef-0123-456789abcdef -Force

        First checks for any existing pending submission for the flight
        01234567-89ab-cdef-0123-456789abcdefapp under the app 0ABCDEF12345.
        If one is found, it will be removed.  After that check has completed, this will create
        a new application submission that is an exact clone of the currently published submission,
        with the console window showing progress while awaiting for the response from the REST request.
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
        
        [Parameter(Mandatory)]
        [string] $FlightId,

        [switch] $Force,

        [string] $AccessToken = "",

        [switch] $NoStatus
    )

    Write-Log "Executing: $($MyInvocation.Line)" -Level Verbose

    if ([System.String]::IsNullOrEmpty($AccessToken))
    {
        $AccessToken = Get-AccessToken -NoStatus:$NoStatus
    }

    try
    {
        # The Force switch tells us that we need to remove any pending submission
        if ($Force)
        {
            Write-Log "Force creation requested.  Ensuring that there is no existing pending submission." -Level Verbose

            $flight = Get-ApplicationFlight -AppId $AppId -FlightId $FlightId -AccessToken $AccessToken -NoStatus:$NoStatus
            $pendingSubmissionId = $flight.pendingFlightSubmission.id

            if ($null -ne $pendingSubmissionId)
            {
                Remove-ApplicationFlightSubmission -AppId $AppId -FlightId $FlightId -SubmissionId $pendingSubmissionId -AccessToken $AccessToken -NoStatus:$NoStatus
            }
        }

        # Finally, we can POST with a null body to create a clone of the currently published submission
        $telemetryProperties = @{
            [StoreBrokerTelemetryProperty]::AppId = $AppId
            [StoreBrokerTelemetryProperty]::FlightId = $FlightId
        }

        $params = @{
            "UriFragment" = "applications/$AppId/flights/$FlightId/submissions"
            "Method" = "Post"
            "Description" = "Cloning current submission for App: $AppId Flight: $FlightId"
            "AccessToken" = $AccessToken
            "TelemetryEventName" = "New-ApplicationFlightSubmission"
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

function Update-ApplicationFlightSubmission
{
<#
    .SYNOPSIS
        Creates a new submission for an existing application flight on the developer account
        by cloning the existing submission and modifying specific parts of it.

    .DESCRIPTION
        Creates a new submission for an existing application flight on the developer account
        by cloning the existing submission and modifying specific parts of it. The
        parts that will be modified depend solely on the switches that are passed in.

        This app must already have at least one *published* submission completed via
        the website in order for this function to work.
        You cannot submit a new application submission if there is an existing pending
        application submission for this flight already.  You can use -Force to work around
        this.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER AppId
        The Application ID for the application that the new submission is for.

    .PARAMETER FlightId
        The Flight ID for the application that the new submission is for.

    .PARAMETER SubmissionDataPath
        The file containing the JSON payload for the application submission.

    .PARAMETER PackagePath
        If provided, this package will be uploaded after the submission has been successfully
        created.

    .PARAMETER TargetPublishMode
        Indicates how the submission will be published once it has passed certification.
        The value specified here takes precendence over the value from SubmissionDataPath if
        -UpdatePublishMode is specified.  If -UpdatePublishMode is not specified and the value
        'Default' is used, this submission will simply use the value from the previous submission.

    .PARAMETER TargetPublishDate
        Indicates when the submission will be published once it has passed certification.
        Specifying a value here is only valid when TargetPublishMode is set to 'SpecificDate'.
        The value specified here takes precendence over the value from SubmissionDataPath if
        -UpdatePublishMode is specified.  If -UpdatePublishMode is not specified and the value
        'Default' is used, this submission will simply use the value from the previous submission.

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

    .PARAMETER UpdatePublishMode
        Updates fields under the "Publish Mode and Visibility" category in the PackageTool config file.
        Updates the following fields using values from SubmissionDataPath: targetPublishMode
        and targetPublishDate.  The visibility property is ignored for a flight submission.

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
        Update-ApplicationFlightSubmission 0ABCDEF12345 01234567-89ab-cdef-0123-456789abcdef "c:\foo.json"

        Creates a new application submission for the flight 01234567-89ab-cdef-0123-456789abcdef
        under app 0ABCDEF12345 that is a clone of the currently published submission.
        Even though "c:\foo.json" was provided, because no switches were specified to indicate
        what to copy from it, the cloned submission was not further modified, and is thus still
        an exact copy of the currently published submission.
        If successful, will return back the pending submission id and url that should be
        used with Upload-SubmissionPackage.

    .EXAMPLE
        Update-ApplicationFlightSubmission 0ABCDEF12345 01234567-89ab-cdef-0123-456789abcdef "c:\foo.json" -AddPackages -NoStatus

        Creates a new application submission for the flight 01234567-89ab-cdef-0123-456789abcdef
        under the app 0ABCDEF12345 that is a clone of the currently published submission.
        The packages listed in "c:\foo.json" will be added to the list of packages that should be
        used by the submission.  The request happens in the foreground and there is no additional
        status shown to the user until a response is returned from the REST request.
        If successful, will return back the pending submission id and url that
        should be used with Upload-SubmissionPackage.

    .EXAMPLE
        Update-ApplicationFlightSubmission 0ABCDEF12345 01234567-89ab-cdef-0123-456789abcdef "c:\foo.json" "c:\foo.zip" -AutoCommit -SubmissionId 1234567890123456789 -AddPackages

        Retrieves submission 1234567890123456789 from the flight 01234567-89ab-cdef-0123-456789abcdef
        under app 0ABCDEF12345, updates the package listing to include the packages that are
        contained in "c:\foo.json."  If successful, this then attempts to upload "c:\foo.zip" as
        the package content for the submission.  If that is also successful, it then goes ahead and
        commits the submission so that the certification process can start. The pending
        submissionid and url that were used with with Upload-SubmissionPackage
        are still returned in this scenario, even though the upload url can no longer actively be used.

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
        [Parameter(
            Mandatory,
            Position=0)]
        [string] $AppId,
        
        [Parameter(
            Mandatory,
            Position=1)]
        [string] $FlightId,

        [Parameter(
            Mandatory,
            Position=2)]
        [ValidateScript({if (Test-Path -Path $_ -PathType Leaf) { $true } else { throw "$_ cannot be found." }})]
        [string] $SubmissionDataPath,

        [Parameter(Position=3)]
        [ValidateScript({if (Test-Path -Path $_ -PathType Leaf) { $true } else { throw "$_ cannot be found." }})]
        [string] $PackagePath = $null,

        [ValidateSet('Default', 'Immediate', 'Manual', 'SpecificDate')]
        [string] $TargetPublishMode = $script:keywordDefault,

        [DateTime] $TargetPublishDate,

        [switch] $AutoCommit,
        
        [string] $SubmissionId = "",

        [ValidateScript({if ([System.String]::IsNullOrEmpty($SubmissionId) -or !$_) { $true } else { throw "Can't use -Force and supply a SubmissionId." }})]
        [switch] $Force,

        [Parameter(ParameterSetName="AddPackages")]
        [switch] $AddPackages,

        [Parameter(ParameterSetName="ReplacePackages")]
        [switch] $ReplacePackages,

        [switch] $UpdatePublishMode,

        [switch] $UpdateNotesForCertification,

        [string] $AccessToken = "",

        [switch] $NoStatus
    )

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    Write-Log "Executing: $($MyInvocation.Line)" -Level Verbose

    Write-Log "Reading in the submission content from: $SubmissionDataPath" -Level Verbose
    if ($PSCmdlet.ShouldProcess($SubmissionDataPath, "Get-Content"))
    {
        $submission = [string](Get-Content $SubmissionDataPath -Encoding UTF8) | ConvertFrom-Json
    }

    # Extra layer of validation to protect users from trying to submit a PackageTool
    # payload to the wrong application
    if ([String]::IsNullOrWhiteSpace($submission.appId))
    {
        $output = @()
        $output += "The config file used to generate this submission did not have an AppId defined in it."
        $output += "The AppId entry in the config helps ensure that payloads are not submitted to the wrong application."
        $output += "Please update your app's StoreBroker config file by adding an ""appId"" property with"
        $output += "your app's AppId to the ""appSubmission"" section.  If you're unclear on what change"
        $output += "needs to be done, you can re-generate your config file using ""New-PackageToolConfigFile -AppId $AppId"" -Path ""`$home\desktop\newconfig.json"""
        $output += "and then diff the new config file against your current one to see the requested appId change."
        Write-Log $($output -join [Environment]::NewLine) -Level Warning
    }
    else
    {
        if ($AppId -ne $submission.appId)
        {
            $output = @()
            $output += "The AppId [$($submission.appId)] in the submission content [$SubmissionDataPath] does not match the intended AppId [$AppId]."
            $output += "You either entered the wrong AppId at the commandline, or you're referencing the wrong submission content to upload."
            Write-Log $($output -join [Environment]::NewLine) -Level Error
            throw $($output -join [Environment]::NewLine)
        }
    }

    # Now, we'll remove the appId property since it's not really valid in submission content.
    # We can safely call this method without validating that the property actually exists.
    $submission.PSObject.Properties.Remove('appId')

    # Identify potentially incorrect usage of this method by checking to see if no modification
    # switch was provided by the user
    if ((-not $AddPackages) -and
        (-not $ReplacePackages) -and
        (-not $UpdatePublishMode) -and
        (-not $UpdateNotesForCertification))
    {
        $output = @()
        $output += "You have not specified any `"modification`" switch for updating the submission."
        $output += "This means that the new submission will be identical to the current one."
        $output += "If this was not your intention, please read-up on the documentation for this command:"
        $output += "     Get-Help Update-ApplicationFlightSubmission -ShowWindow"
        Write-Log $($output -join [Environment]::NewLine) -Level Warning
    }

    if ([System.String]::IsNullOrEmpty($AccessToken))
    {
        $AccessToken = Get-AccessToken -NoStatus:$NoStatus
    }

    try
    {
        if ([System.String]::IsNullOrEmpty($SubmissionId))
        {
            $submissionToUpdate = New-ApplicationFlightSubmission -AppId $AppId -FlightId $FlightId -Force:$Force -AccessToken $AccessToken -NoStatus:$NoStatus
        }
        else
        {
            $submissionToUpdate = Get-ApplicationFlightSubmission -AppId $AppId -FlightId $FlightId -SubmissionId $SubmissionId -AccessToken $AccessToken -NoStatus:$NoStatus
            if ($submissionToUpdate.status -ne $script:keywordPendingCommit)
            {
                $output = @()
                $output += "We can only modify a submission that is in the '$script:keywordPendingCommit' state."
                $output += "The submission that you requested to modify ($SubmissionId) is in '$(submissionToUpdate.status)' state."
                Write-Log $($output -join [Environment]::NewLine) -Level Error
                throw "Halt Execution"
            }
        }

        if ($PSCmdlet.ShouldProcess("Patch-ApplicationFlightSubmission"))
        {
            $params = @{}
            $params.Add("ClonedSubmission", $submissionToUpdate)
            $params.Add("NewSubmission", $submission)
            $params.Add("TargetPublishMode", $TargetPublishMode)
            if ($null -ne $TargetPublishDate) { $params.Add("TargetPublishDate", $TargetPublishDate) }
            $params.Add("UpdatePublishMode", $UpdatePublishMode)
            $params.Add("UpdateNotesForCertification", $UpdateNotesForCertification)

            # Because these are mutually exclusive and tagged as such, we have to be sure to *only*
            # add them to the parameter set if they're true.
            if ($AddPackages) { $params.Add("AddPackages", $AddPackages) }
            if ($ReplacePackages) { $params.Add("ReplacePackages", $ReplacePackages) }

            $patchedSubmission = Patch-ApplicationFlightSubmission @params
        }

        if ($PSCmdlet.ShouldProcess("Set-ApplicationFlightSubmission"))
        {
            $params = @{}
            $params.Add("AppId", $AppId)
            $params.Add("UpdatedSubmission", $patchedSubmission)
            $params.Add("AccessToken", $AccessToken)
            $params.Add("NoStatus", $NoStatus)
            $replacedSubmission = Set-ApplicationFlightSubmission @params
        }

        $submissionId = $replacedSubmission.id
        $uploadUrl = $replacedSubmission.fileUploadUrl

        $output = @()
        $output += "Successfully cloned the existing submission and modified its content."
        $output += "You can view it on the Dev Portal here:"
        $output += "    https://dev.windows.com/en-us/dashboard/apps/$AppId/submissions/$submissionId/"
        $output += "or by running this command:"
        $output += "    Get-ApplicationFlightSubmission -AppId $AppId -FlightId $FlightId -SubmissionId $submissionId | Format-ApplicationFlightSubmission"
        $output += ""
        $output += $script:manualPublishWarning -f 'Update-ApplicationFlightSubmission'
        Write-Log $($output -join [Environment]::NewLine)

        if (![System.String]::IsNullOrEmpty($PackagePath))
        {
            Write-Log "Uploading the package [$PackagePath] since it was provided." -Level Verbose
            Set-SubmissionPackage -PackagePath $PackagePath -UploadUrl $uploadUrl -NoStatus:$NoStatus
        }
        elseif (!$AutoCommit)
        {
            $output = @()
            $output += "Your next step is to upload the package using:"
            $output += "  Upload-SubmissionPackage -PackagePath <package> -UploadUrl `"$uploadUrl`""
            Write-Log $($output -join [Environment]::NewLine)
        }

        if ($AutoCommit)
        {
            if ($stopwatch.Elapsed.TotalSeconds -gt $script:accessTokenTimeoutSeconds)
            {
                # The package upload probably took a long time.
                # There's a high likelihood that the token will be considered expired when we call
                # into Complete-ApplicationFlightSubmission ... so, we'll send in a $null value and
                # let it acquire a new one.
                $AccessToken = $null
            }

            Write-Log "Commiting the submission since -AutoCommit was requested." -Level Verbose
            Complete-ApplicationFlightSubmission -AppId $AppId -FlightId $FlightId -SubmissionId $submissionId -AccessToken $AccessToken -NoStatus:$NoStatus
        }
        else
        {
            $output = @()
            $output += "When you're ready to commit, run this command:"
            $output += "  Commit-ApplicationFlightSubmission -AppId $AppId -FlightId $FlightId -SubmissionId $submissionId"
            Write-Log $($output -join [Environment]::NewLine)
        }

        # Record the telemetry for this event.
        $stopwatch.Stop()
        $telemetryMetrics = @{ [StoreBrokerTelemetryMetric]::Duration = $stopwatch.Elapsed.TotalSeconds }
        $telemetryProperties = @{
            [StoreBrokerTelemetryProperty]::AppId = $AppId
            [StoreBrokerTelemetryProperty]::FlightId = $FlightId
            [StoreBrokerTelemetryProperty]::SubmissionId = $SubmissionId
            [StoreBrokerTelemetryProperty]::PackagePath = (Get-PiiSafeString -PlainText $PackagePath)
            [StoreBrokerTelemetryProperty]::AutoCommit = $AutoCommit
            [StoreBrokerTelemetryProperty]::Force = $Force
            [StoreBrokerTelemetryProperty]::AddPackages = $AddPackages
            [StoreBrokerTelemetryProperty]::ReplacePackages = $ReplacePackages
            [StoreBrokerTelemetryProperty]::UpdatePublishMode = $UpdatePublishMode
            [StoreBrokerTelemetryProperty]::UpdateNotesForCertification = $UpdateNotesForCertification
        }

        Set-TelemetryEvent -EventName Update-ApplicationFlightSubmission -Properties $telemetryProperties -Metrics $telemetryMetrics

        return $submissionId, $uploadUrl
    }
    catch
    {
        Write-Log $_ -Level Error
        throw "Halt Execution"
    }
}

function Patch-ApplicationFlightSubmission
{
<#
    .SYNOPSIS
        Modifies a cloned application flight submission by copying the specified data from the
        provided "new" submission.  Returns the final, patched submission JSON.

    .DESCRIPTION
        Modifies a cloned application flight submission by copying the specified data from the
        provided "new" submission.  Returns the final, patched submission JSON.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER ClonedSubmisson
        The JSON that was returned by the Store API when the application flight submission was cloned.

    .PARAMETER NewSubmission
        The JSON for the new/updated application flight submission.  The only parts from this
        submission that will be copied to the final, patched submission will be those specified
        by the switches.

    .PARAMETER TargetPublishMode
        Indicates how the submission will be published once it has passed certification.
        The value specified here takes precendence over the value from NewSubmission if
        -UpdatePublishMode is specified.  If -UpdatePublishMode is not specified and the value
        'Default' is used, this submission will simply use the value from the previous submission.

    .PARAMETER TargetPublishDate
        Indicates when the submission will be published once it has passed certification.
        Specifying a value here is only valid when TargetPublishMode is set to 'SpecificDate'.
        The value specified here takes precendence over the value from NewSubmission if
        -UpdatePublishMode is specified.  If -UpdatePublishMode is not specified and the value
        'Default' is used, this submission will simply use the value from the previous submission.

    .PARAMETER AddPackages
        Causes the packages that are listed in SubmissionDataPath to be added to the package listing
        in the final, patched submission.  This switch is mutually exclusive with ReplacePackages.

    .PARAMETER ReplacePackages
        Causes any existing packages in the cloned submission to be removed and only the packages
        that are listed in SubmissionDataPath will be in the final, patched submission.
        This switch is mutually exclusive with AddPackages.

    .PARAMETER UpdatePublishMode
        Updates fields under the "Publish Mode and Visibility" category in the PackageTool config file.
        Updates the following fields using values from SubmissionDataPath: targetPublishMode
        and targetPublishDate.  The visibility property is ignored for a flight submission.

    .PARAMETER UpdateNotesForCertification
        Updates the notesForCertification field using the value from SubmissionDataPath.

    .EXAMPLE
        $patchedSubmission = Patch-ApplicationFlightSubmission $clonedSubmission $jsonContent

        Because no switches were specified, ($patchedSubmission -eq $clonedSubmission).

    .EXAMPLE
        $patchedSubmission = Patch-ApplicationFlightSubmission $clonedSubmission $jsonContent -AddPackages

        $patchedSubmission will be identical to $clonedSubmission, however all of the packages that
        were contained in $jsonContent will have also been added to the package array.

    .EXAMPLE
        $patchedSubmission = Patch-ApplicationFlightSubmission $clonedSubmission $jsonContent -AddPackages -UpdatePublishMode

        $patchedSubmission will be contain the packages and publish mode/date settings that were
        part of $jsonContent, but the rest of the submission content will be identical to what
        had been in $clonedSubmission.

    .NOTES
        This is an internal-only helper method.
#>

    [CmdletBinding(
        SupportsShouldProcess,
        DefaultParametersetName="AddPackages")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseApprovedVerbs", "", Justification="Internal-only helper method.  Best description for purpose.")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="Methods called within here make use of PSShouldProcess, and the switch is passed on to them inherently.")]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject] $ClonedSubmission,
        
        [Parameter(Mandatory)]
        [PSCustomObject] $NewSubmission,

        [ValidateSet('Default', 'Immediate', 'Manual', 'SpecificDate')]
        [string] $TargetPublishMode = $script:keywordDefault,

        [DateTime] $TargetPublishDate,

        [Parameter(ParameterSetName="AppPackages")]
        [switch] $AddPackages,

        [Parameter(ParameterSetName="ReplacePackages")]
        [switch] $ReplacePackages,

        [switch] $UpdateListings,

        [switch] $UpdatePublishModeAndVisibility,

        [switch] $UpdatePricingAndAvailability,

        [switch] $UpdateAppProperties,

        [switch] $UpdateNotesForCertification
    )
    
    Write-Log "Patching the content of the submission." -Level Verbose

    # Our method should have zero side-effects -- we don't want to modify any parameter
    # that was passed-in to us.  To that end, we'll create a deep copy of the ClonedSubmisison,
    # and we'll modify that throughout this function and that will be the value that we return
    # at the end.
    $PatchedSubmission = DeepCopy-Object $ClonedSubmission

    # Caller wants to simply append the new packages to the existing set of packages in the
    # submission.
    if ($AddPackages)
    {
        $PatchedSubmission.flightPackages += $NewSubmission.applicationPackages
    }

    # Caller wants to remove any existing packages in the cloned submission and only have the
    # packages that are defined in the new submission.
    if ($ReplacePackages)
    {
        $PatchedSubmission.flightPackages | ForEach-Object { $_.fileStatus = $script:keywordPendingDelete }
        $PatchedSubmission.flightPackages += $NewSubmission.applicationPackages
    }

    # For the remaining switches, simply copy the field if it is a scalar, or
    # DeepCopy-Object if it is an object.
    if ($UpdatePublishMode)
    {
        $PatchedSubmission.targetPublishMode = Get-ProperEnumCasing -EnumValue ($NewSubmission.targetPublishMode)
        $PatchedSubmission.targetPublishDate = $NewSubmission.targetPublishDate
    }

    # If users pass in a different value for any of the publish/visibility values at the commandline,
    # they override those coming from the config.
    if ($TargetPublishMode -ne $script:keywordDefault)
    {
        if (($TargetPublishMode -eq $script:keywordSpecificDate) -and ($null -eq $TargetPublishDate))
        {
            $output = "TargetPublishMode was set to '$script:keywordSpecificDate' but TargetPublishDate was not specified."
            Write-Log $output -Level Error
            throw $output
        }

        $PatchedSubmission.targetPublishMode = Get-ProperEnumCasing -EnumValue $TargetPublishMode
    }

    if ($null -ne $TargetPublishDate)
    {
        if ($TargetPublishMode -ne $script:keywordSpecificDate)
        {
            $output = "A TargetPublishDate was specified, but the TargetPublishMode was [$TargetPublishMode],  not '$script:keywordSpecificDate'."
            Write-Log $output -Level Error
            throw $output
        }

        $PatchedSubmission.targetPublishDate = $TargetPublishDate.ToString('o')
    }

    if ($UpdateNotesForCertification)
    {
        $PatchedSubmission.notesForCertification = $NewSubmission.notesForCertification
    }

    # To better assist with debugging, we'll store exactly the original and modified JSON submission bodies.
    $tempFile = [System.IO.Path]::GetTempFileName() # New-TemporaryFile requires PS 5.0
    ($ClonedSubmission | ConvertTo-Json -Depth $script:jsonConversionDepth) | Set-Content -Path $tempFile -Encoding UTF8
    Write-Log "The original cloned JSON content can be found here: [$tempFile]" -Level Verbose

    $tempFile = [System.IO.Path]::GetTempFileName() # New-TemporaryFile requires PS 5.0
    ($PatchedSubmission | ConvertTo-Json -Depth $script:jsonConversionDepth) | Set-Content -Path $tempFile -Encoding UTF8
    Write-Log "The patched JSON content can be found here: [$tempFile]" -Level Verbose

    return $PatchedSubmission
}

function Set-ApplicationFlightSubmission
{
<#
    .SYNOPSIS
        Replaces the content of an existing application flight submission with the supplied
        submission content.

    .DESCRIPTION
        Replaces the content of an existing application flight submission with the supplied
        submission content.
    
        This should be called after having cloned an application flight submission via
        New-ApplicationFlightSubmission.

        The ID of the submission and flight being updated/replaced will be inferred by the
        ID's defined in UpdatedSubmission.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER AppId
        The Application ID for the application that the submission is for.

    .PARAMETER UpdatedSubmission
        The updated application submission content that should be used to replace the
        existing submission content.  The Submission ID will be determined from this.

    .PARAMETER AccessToken
        If provided, this will be used as the AccessToken for authentication with the
        REST Api as opposed to requesting a new one.

    .PARAMETER NoStatus
        If this switch is specified, long-running commands will run on the main thread
        with no commandline status update.  When not specified, those commands run in
        the background, enabling the command prompt to provide status information.

    .EXAMPLE
        Set-ApplicationFlightSubmission 0ABCDEF12345 $submissionBody

        Inspects $submissionBody to retrieve the id of the submission and flight in question,
        and then replaces the entire content of that existing submission with the content
        specified in $submissionBody.

    .EXAMPLE
        Set-ApplicationFlightSubmission 0ABCDEF12345 $submissionBody -NoStatus

        Inspects $submissionBody to retrieve the id and flight of the submission in question,
        and then replaces the entire content of that existing submission with the content
        specified in $submissionBody.
        The request happens in the foreground and there is no additional status shown to the user
        until a response is returned from the REST request.

    .OUTPUTS
        A PSCustomObject containing the JSON of the updated application submission.
#>
    [CmdletBinding(SupportsShouldProcess)]
    [Alias('Replace-ApplicationFlightSubmission')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="Methods called within here make use of PSShouldProcess, and the switch is passed on to them inherently.")]
    param(
        [Parameter(Mandatory)]
        [string] $AppId,
        
        [Parameter(Mandatory)]
        [PSCustomObject] $UpdatedSubmission,

        [string] $AccessToken = "",

        [switch] $NoStatus
    )

    Write-Log "Executing: $($MyInvocation.Line)" -Level Verbose

    $submissionId = $UpdatedSubmission.id
    $flightId = $UpdatedSubmission.flightId
    $body = [string]($UpdatedSubmission | ConvertTo-Json -Depth $script:jsonConversionDepth)

    $telemetryProperties = @{
        [StoreBrokerTelemetryProperty]::AppId = $AppId
        [StoreBrokerTelemetryProperty]::FlightId = $FlightId
    }

    $params = @{
        "UriFragment" = "applications/$AppId/flights/$flightId/submissions/$submissionId"
        "Method" = "Put"
        "Description" = "Replacing the content of Submission: $submissionId for App: $AppId Flight: $flightId"
        "Body" = $body
        "AccessToken" = $AccessToken
        "TelemetryEventName" = "Set-ApplicationFlightSubmission"
        "TelemetryProperties" = $telemetryProperties
        "NoStatus" = $NoStatus
    }

    return (Invoke-SBRestMethod @params)
}

function Complete-ApplicationFlightSubmission
{
<#
    .SYNOPSIS
        Commits the specified application flight submission so that it can start the approval process.

    .DESCRIPTION
        Commits the specified application flight submission so that it can start the approval process.
        Once committed, it is necessary to wait for the submission to either complete or fail
        the approval process before a new flight submission can be created/submitted.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER AppId
        The Application ID for the application that has the pending submission to be submitted.

    .PARAMETER FlightId
        The flight ID for the flight that has the pending submission to be submitted.

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
        Commit-ApplicationFlightSubmission 0ABCDEF12345 01234567-89ab-cdef-0123-456789abcdef 1234567890123456789

        Marks the pending submission 1234567890123456789 to start the approval process
        for publication, with the console window showing progress while awaiting
        for the response from the REST request.

    .EXAMPLE
        Commit-ApplicationFlightSubmission 0ABCDEF12345 01234567-89ab-cdef-0123-456789abcdef 1234567890123456789 -NoStatus

        Marks the pending submission 1234567890123456789 to start the approval process
        for publication, but the request happens in the foreground and there is no
        additional status shown to the user until a response is returned from the REST
        request.

    .NOTES
        This uses the "Complete" verb to avoid Powershell import module warnings, but this
        actually only *commits* the submission.  The decision to publish or not is based
        entirely on the contents of the payload included when calling New-ApplicationFlightSubmission.
#>
    [CmdletBinding(SupportsShouldProcess)]
    [Alias('Commit-ApplicationFlightSubmission')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="Methods called within here make use of PSShouldProcess, and the switch is passed on to them inherently.")]
    param(
        [Parameter(Mandatory)]
        [string] $AppId,
        
        [Parameter(Mandatory)]
        [string] $FlightId,

        [Parameter(Mandatory)]
        [string] $SubmissionId,
        
        [string] $AccessToken = "",

        [switch] $NoStatus
    )

    Write-Log "Executing: $($MyInvocation.Line)" -Level Verbose

    try
    {
        $telemetryProperties = @{
            [StoreBrokerTelemetryProperty]::AppId = $AppId
            [StoreBrokerTelemetryProperty]::FlightId = $FlightId
            [StoreBrokerTelemetryProperty]::SubmissionId = $SubmissionId
        }

        $params = @{
            "UriFragment" = "applications/$AppId/flights/$FlightId/submissions/$SubmissionId/Commit"
            "Method" = "Post"
            "Description" = "Committing submission $SubmissionId for App: $AppId Flight: $FlightId"
            "AccessToken" = $AccessToken
            "TelemetryEventName" = "Complete-ApplicationFlightSubmission"
            "TelemetryProperties" = $telemetryProperties
            "NoStatus" = $NoStatus
        }

        $null = Invoke-SBRestMethod @params

        $output = @()
        $output += "The submission has been successfully committed."
        $output += "This is just the beginning though."
        $output += "It still has multiple phases of validation to get through, and there's no telling how long that might take."
        $output += "You can view the progress of the submission validation on the Dev Portal here:"
        $output += "    https://dev.windows.com/en-us/dashboard/apps/$AppId/submissions/$submissionId/"
        $output += "or by running this command:"
        $output += "    Get-ApplicationFlightSubmission -AppId $AppId -Flight $FlightId -SubmissionId $submissionId | Format-ApplicationFlightSubmission"
        $output += "You can automatically monitor this submission with this command:"
        $output += "    Start-ApplicationFlightSubmissionMonitor -AppId $AppId -Flight $FlightId -SubmissionId $submissionId -EmailNotifyTo $env:username"
        $output += ""
        $output += $script:manualPublishWarning -f 'Update-ApplicationFlightSubmission'

        Write-Log $($output -join [Environment]::NewLine)
    }
    catch [System.InvalidOperationException]
    {
        throw
    }
}

function Start-ApplicationFlightSubmissionMonitor
{
<#
    .SYNOPSIS
        Auto-checks an application flight submission for status changes every 60 seconds with optional
        email notification.

    .DESCRIPTION
        Auto-checks an application flight submission for status changes every 60 seconds with optional
        email notification.

        The monitoring will automatically end if the submission enters a failed state, or once
        its state enters the final state that its targetPublishMode allows for.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER AppId
        The Application ID for the application that has the committed submission.

    .PARAMETER FlightId
        The Flight ID for the flight that has the committed submission.

    .PARAMETER SubmissionId
        The ID of the submission that should be monitored.

    .PARAMETER EmailNotifyTo
        A list of email addresses that should be emailed every time that status changes for
        this submission.

    .PARAMETER NoStatus
        If this switch is specified, long-running commands will run on the main thread
        with no commandline status update.  When not specified, those commands run in
        the background, enabling the command prompt to provide status information.

    .EXAMPLE
        Start-ApplicationFlightSubmissionMonitor 0ABCDEF12345 01234567-89ab-cdef-0123-456789abcdef 1234567890123456789

        Checks that submission every 60 seconds until the submission enters a Failed state
        or reaches the final state that it can reach given its current targetPublishMode.

    .EXAMPLE
        Start-ApplicationFlightSubmissionMonitor 0ABCDEF12345 01234567-89ab-cdef-0123-456789abcdef 1234567890123456789 user@foo.com

        Checks that submission every 60 seconds until the submission enters a Failed state
        or reaches the final state that it can reach given its current targetPublishMode.
        Will email user@foo.com every time this status changes as well.

    .NOTES
        This is a pure proxy for Start-ApplicationSubmissionMonitor.  The only benefit that
        it provides is that it makes FlightId a required parameter and puts it positionally in
        the appropriate place.  We can't accomplish that with normal parameter sets since all the
        parameters are strings and thus can't be differentiated.
#>
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="Methods called within here make use of PSShouldProcess, and the switch is passed on to them inherently.")]
    param(
        [Parameter(Mandatory)]
        [string] $AppId,

        [Parameter(Mandatory)]
        [string] $FlightId,
        
        [Parameter(Mandatory)]
        [string] $SubmissionId,

        [string[]] $EmailNotifyTo = @(),

        [switch] $NoStatus
    )

    Start-SubmissionMonitor @PSBoundParameters
}