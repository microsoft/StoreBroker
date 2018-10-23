# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

Add-Type -TypeDefinition @"
   public enum StoreBrokerSubmissionProperty
   {
       certificationNotes,
       isAutoPromote,
       isManualPublish,
       releaseTimeInUtc,
       resourceType,
       revisionToken,
       state,
       targets
   }
"@

Add-Type -TypeDefinition @"
   public enum StoreBrokerSubmissionTargetsProperty
   {
       type,
       value
   }
"@

Add-Type -TypeDefinition @"
   public enum StoreBrokerSubmissionTargetsValues
   {
       flight,
       sandbox,
       scope
   }
"@

Add-Type -TypeDefinition @"
   public enum StoreBrokerSubmissionState
   {
       InProgress,
       Published
   }
"@

Add-Type -TypeDefinition @"
   public enum StoreBrokerSubmissionSubState
   {
       Cancelled,
       InDraft,
       Submitted,
       Failed,
       FailedInCertification,
       ReadyToPublish,
       Publishing,
       Published,
       InStore
   }
"@

function Get-Submission
{
<#
    .SYNOPSIS
        Retrieves submissions for the specified Product in the Windows Store.

    .DESCRIPTION
        Retrieves submissions for the specified Product in the Windows Store.

        Can be used to retrieve a specific submission, or to get all known
        submission for a Product that are targeted for retail, a flight, a sandbox.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER ProductId
        The ID of the Product in the Windows Store.

    .PARAMETER FlightId
        The ID of the Flight for the Product that contains the submissions desired to be seen.

    .PARAMETER SandboxId
        The ID of the Sandbox for the Product that contains the submissions desired to be seen.

    .PARAMETER State
        Optionally specify the state of the submissions desired to be seen.

    .PARAMETER Scope
        Optionally specify the scope of the submissions desired to be seen.
        Please note: "Preview" is currently limited to Azure products.

    .PARAMETER SubmissionId
        The Submission to retrieve the information for.

    .PARAMETER Detail
        When specified, additionally calls Get-SubmissionDetail for the specified Submission.

    .PARAMETER Report
        When specified, additionally calls Get-SubmissionReport for the specified Submission.

    .PARAMETER Validation
        When specified, additionally calls Get-SubmissionValidation for the specified Submission.

    .PARAMETER WaitUntilReady
        When specified, will continue to query the API for information on the specified
        Submission until the API has indicated that all resources are ready.  If the
        specified Submission was recently created, it is possible that the API is asynchronously
        creating resources for the Submission, and thus the information in the Submission
        cannot be "trusted" until all of its resources are "ready".
 
    .PARAMETER SinglePage
        When specified, will only return back the first set of results supplied by the API.
        If not specified, then the API continuously be queried until all results have been
        retrieved, and then the final combined result set will be returned.

    .PARAMETER ClientRequestId
        An optional identifier that should be sent along to the Store to help with identifying
        this request during post-mortem debugging.

    .PARAMETER CorrelationId
        An optional identifier that should be sent along to the Store to help with identifying
        this request during post-mortem debugging.  This is typically supplied when trying to
        associate a group of API requests with a single end-goal.

    .PARAMETER AccessToken
        If provided, this will be used as the AccessToken for authentication with the
        REST Api as opposed to requesting a new one.

    .PARAMETER NoStatus
        If this switch is specified, long-running commands will run on the main thread
        with no commandline status update.  When not specified, those commands run in
        the background, enabling the command prompt to provide status information.

    .OUTPUTS
        [PSCustomObject] - The submission that matches the specified SubmissionId.
        [PSCustomObject[]] - The collection of submissions that match the input.

    .EXAMPLE
        Get-Submission -ProductId 00012345678901234567 -SubmissionId 1234567890123456789

        Gets the information for the specified submission.

    .EXAMPLE
        Get-Submission -ProductId 00012345678901234567 -SubmissionId 1234567890123456789 -Detail -Report -Validation

        Gets the information for the specified submission, along with the submission's
        detail, report and validation data.

    .EXAMPLE
        Get-Submission -ProductId 00012345678901234567 -FlightId abcdef01-2345-6789-abcd-ef0123456789

        Gets all of the submissions currently associated with that Flight of the specified Product.

    .EXAMPLE
        Get-Submission -ProductId 00012345678901234567 -FlightId abcdef01-2345-6789-abcd-ef0123456789 -State Published

        Returns the published submission associated with that Flight of the specified Product.
#>
    [CmdletBinding(
        SupportsShouldProcess,
        DefaultParametersetName="Search")]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({if ($_.Length -le 12) { throw "It looks like you supplied an AppId instead of a ProductId.  Use Get-Product with -AppId to find the ProductId for this AppId." } else { $true }})]
        [string] $ProductId,

        [Parameter(ParameterSetName="Search")]
        [string] $FlightId,

        [Parameter(ParameterSetName="Search")]
        [string] $SandboxId,

        [Parameter(ParameterSetName="Search")]
        [ValidateSet('InProgress', 'Published')]
        [string] $State,

        [Parameter(ParameterSetName="Search")]
        [ValidateSet('Live', 'Preview')]
        [string] $Scope = 'Live',

        [Parameter(
            Mandatory,
            ParameterSetName="Known")]
        [string] $SubmissionId,

        [Parameter(ParameterSetName="Known")]
        [switch] $Detail,

        [Parameter(ParameterSetName="Known")]
        [switch] $Report,

        [Parameter(ParameterSetName="Known")]
        [switch] $Validation,

        [Parameter(ParameterSetName="Known")]
        [switch] $WaitUntilReady,

        [Parameter(ParameterSetName="Search")]
        [switch] $SinglePage,

        [string] $ClientRequestId,

        [string] $CorrelationId,

        [string] $AccessToken,

        [switch] $NoStatus
    )

    Write-Log -Message "[$($MyInvocation.MyCommand.Module.Version)] Executing: $($MyInvocation.Line.Trim())" -Level Verbose

    try
    {
        $singleQuery = (-not [String]::IsNullOrWhiteSpace($SubmissionId))
        $telemetryProperties = @{
            [StoreBrokerTelemetryProperty]::ProductId = $ProductId
            [StoreBrokerTelemetryProperty]::FlightId = $FlightId
            [StoreBrokerTelemetryProperty]::SandboxId = $SandboxId
            [StoreBrokerTelemetryProperty]::State = $State
            [StoreBrokerTelemetryProperty]::Scope = $Scope
            [StoreBrokerTelemetryProperty]::GetDetail = $Detail
            [StoreBrokerTelemetryProperty]::GetReport = $Report
            [StoreBrokerTelemetryProperty]::GetValidation = $Validation
            [StoreBrokerTelemetryProperty]::WaitUntilReady = ($WaitUntilReady -eq $true)
            [StoreBrokerTelemetryProperty]::SingleQuery = $singleQuery
            [StoreBrokerTelemetryProperty]::ClientRequestId = $ClientRequesId
            [StoreBrokerTelemetryProperty]::CorrelationId = $CorrelationId
        }

        $commonParams = @{
            'ClientRequestId' = $ClientRequestId
            'CorrelationId' = $CorrelationId
            'AccessToken' = $AccessToken
            'NoStatus' = $NoStatus
        }

        if ($singleQuery)
        {
            $singleQueryParams = @{
                'UriFragment' = "products/$ProductId/submissions/$SubmissionId"
                'Method' = 'Get'
                'Description' =  "Getting submission $SubmissionId for $ProductId"
                'WaitForCompletion' = $WaitUntilReady
                'TelemetryEventName' = "Get-Submission"
                'TelemetryProperties' = $telemetryProperties
            }

            Write-Output (Invoke-SBRestMethod @commonParams @singleQueryParams)

            $additionalParams = @{
                'ProductId' = $ProductId
                'SubmissionId' = $SubmissionId
            }

            if ($Detail)
            {
                Write-Output (Get-SubmissionDetail @commonParams @additionalParams)
            }

            if ($Report)
            {
                Write-Output (Get-SubmissionReport @commonParams @additionalParams)
            }

            if ($Validation)
            {
                Write-Output (Get-SubmissionValidation @commonParams @additionalParams)
            }
        }
        else
        {
            $searchParams = @()
            $searchParams += "scope=$Scope"

            if (-not [String]::IsNullOrWhiteSpace($FlightId))
            {
                $searchParams += "flightId=$FlightId"
            }

            if (-not [String]::IsNullOrWhiteSpace($SandboxId))
            {
                $searchParams += "sandboxId=$SandboxId"
            }

            if (-not [String]::IsNullOrWhiteSpace($State))
            {
                $searchParams += "state=$State"
            }

            $multipleResultParams = @{
                'UriFragment' = "products/$ProductId/submissions`?" + ($searchParams -join '&')
                'Description' = "Getting submissions for $ProductId"
                'SinglePage' = $SinglePage
            }

            return Invoke-SBRestMethodMultipleResult @commonParams @multipleResultParams
        }
    }
    catch
    {
        throw
    }
}

function New-Submission
{
<#
    .SYNOPSIS
        Creates a new submission for the specified Product in the Windows Store.

    .DESCRIPTION
        Creates a new submission for the specified Product in the Windows Store.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER ProductId
        The ID of the Product in the Windows Store.

    .PARAMETER FlightId
        The ID of the Flight for the Product that the new submission is for.

    .PARAMETER SandboxId
        The ID of the Sandbox for the Product that the new submission is for.

    .PARAMETER Scope
        Optionally specify the scope of the new submission.
        Please note: "Preview" is currently limited to Azure products.

    .PARAMETER ExistingPackageRolloutAction
        Use this parameter to specify what should be done if there is a published submission
        currently in the process of a package rollout.  In that scenario, a new submission
        cannot be created until the existing submission's rollout is either completed or rolled back.
        There is no harm in specifying this if the current published submission is _not_ using
        package rollout...this will simply be ignored in that scenario.

    .PARAMETER Force
        When specified, any existing pending submission that matches the set of input parameters
        will be cancelled and removed before continuing with creation of the new submission.

    .PARAMETER WaitUntilReady
        When specified, will not return the newly created submission until the API has indicated
        that all of its resources are ready.  The API creates all of the submission's related
        objects asynchronously, and thus the information in the Submission cannot be "trusted"
        until all of its resources are "ready".
 
    .PARAMETER ClientRequestId
        An optional identifier that should be sent along to the Store to help with identifying
        this request during post-mortem debugging.

    .PARAMETER CorrelationId
        An optional identifier that should be sent along to the Store to help with identifying
        this request during post-mortem debugging.  This is typically supplied when trying to
        associate a group of API requests with a single end-goal.

    .PARAMETER AccessToken
        If provided, this will be used as the AccessToken for authentication with the
        REST Api as opposed to requesting a new one.

    .PARAMETER NoStatus
        If this switch is specified, long-running commands will run on the main thread
        with no commandline status update.  When not specified, those commands run in
        the background, enabling the command prompt to provide status information.

    .OUTPUTS
        [PSCustomObject] - The newly created submission

    .EXAMPLE
        New-Submission -ProductId 00012345678901234567 -Force

        Deletes any existing Pending retail submission for the specified Product, and then creates
        a new one that is cloned from the previous submission.  Because -WaitUntilReady was not
        specified, it's possible that errors may occur when trying to interact/modify the
        Submission.

    .EXAMPLE
        New-Submission -ProductId 00012345678901234567 -FlightId abcdef01-2345-6789-abcd-ef0123456789 -Force -WaitUntilReady

        Deletes any existing Pending submission in the Flight for the specified Product, and then
        creates a new one that is cloned from the previous submission.  Does not return until all
        of the resources for the submission are ready.

    .EXAMPLE
        New-Submission -ProductId 00012345678901234567 -Force -WaitUntilReady -ExistingPackageRolloutAction Completed

        Deletes any existing Pending retail submission for the specified Product.  Then, completes
        any package rollout that may be occurring on the current published Submission.  Finfally,
        ceates a new submission that is cloned from the previous submission.  Does not return until
        all of the resources for the submission are ready.
#>
        [CmdletBinding(
        SupportsShouldProcess,
        DefaultParameterSetName='Retail')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="Methods called within here make use of PSShouldProcess, and the switch is passed on to them inherently.")]
    param(
        [Parameter(
            Mandatory,
            ParameterSetName = 'Retail',
            Position = 0)]
        [Parameter(
            Mandatory,
            ParameterSetName = 'Flight',
            Position = 0)]
        [Parameter(
            Mandatory,
            ParameterSetName = 'Sandbox',
            Position = 0)]
        [ValidateScript({if ($_.Length -le 12) { throw "It looks like you supplied an AppId instead of a ProductId.  Use Get-Product with -AppId to find the ProductId for this AppId." } else { $true }})]
        [string] $ProductId,

        [Parameter(
            Mandatory,
            ParameterSetName = 'Flight',
            Position = 1)]
        [string] $FlightId,

        [Parameter(
            Mandatory,
            ParameterSetName = 'Sandbox',
            Position = 1)]
        [string] $SandboxId,

        [ValidateSet('Live', 'Preview')]
        [string] $Scope = 'Live',

        [ValidateSet('Completed', 'RolledBack')]
        [string] $ExistingPackageRolloutAction,

        [switch] $Force,

        [switch] $WaitUntilReady,

        [string] $ClientRequestId,

        [string] $CorrelationId,

        [string] $AccessToken,

        [switch] $NoStatus
    )

    Write-Log -Message "[$($MyInvocation.MyCommand.Module.Version)] Executing: $($MyInvocation.Line.Trim())" -Level Verbose

    try
    {
        $providedExistingPackageRolloutAction = ($PSBoundParameters.ContainsKey('ExistingPackageRolloutAction'))

        $telemetryProperties = @{
            [StoreBrokerTelemetryProperty]::ProductId = $ProductId
            [StoreBrokerTelemetryProperty]::FlightId = $FlightId
            [StoreBrokerTelemetryProperty]::SandboxId = $SandboxId
            [StoreBrokerTelemetryProperty]::Scope = $Scope
            [StoreBrokerTelemetryProperty]::WaitUntilReady = ($WaitUntilReady -eq $true)
            [StoreBrokerTelemetryProperty]::ClientRequestId = $ClientRequesId
            [StoreBrokerTelemetryProperty]::CorrelationId = $CorrelationId
        }

        $commonParams = @{
            'ProductId' = $ProductId
            'ClientRequestId' = $ClientRequestId
            'CorrelationId' = $CorrelationId
            'AccessToken' = $AccessToken
            'NoStatus' = $NoStatus
        }

        if ($Force -or $providedExistingPackageRolloutAction)
        {
            Write-Log -Message "Force creation requested. Removing any pending submission." -Level Verbose

            $subs = Get-Submission @commonParams -FlightId $FlightId -SandboxId $SandboxId -Scope $Scope
            $inProgressSub = $subs | Where-Object { $_.state -eq [StoreBrokerSubmissionState]::InProgress }

            if ($Force -and ($null -ne $inProgressSub))
            {
                # Prevent users from getting into an unrecoverable state.  They shouldn't delete the Draft
                # submission if it's for a Flight that doesn't have a published submission yet.
                if (($null -ne $FlightId) -and ($subs.Count -eq 1))
                {
                    $message = "This flight does not have a published submission yet.  If you delete this draft submission, you''ll get into an unrecoverable state. You should instead try to fix this existing pending submission [SubmissionId = $($inProgressSub.id)]"
                    Write-Log -Message $message -Level Error
                    throw $message
                }

                # We can't delete a submission that isn't in the InDraft substate.  We'd have to cancel it first,
                # unless it has previously been cancelled.
                if ($inProgressSub.substate -notin @([StoreBrokerSubmissionSubState]::Cancelled, [StoreBrokerSubmissionSubState]::InDraft))
                {
                    $null = Stop-Submission @commonParams -SubmissionId $inProgressSub.id
                }

                $null = Remove-Submission @commonParams -SubmissionId $inProgressSub.id
            }

            # The user may have requested that we also take care of any existing rollout state for them.
            if ($providedExistingPackageRolloutAction)
            {
                $publishedSubmission = $subs | Where-Object { $_.state -eq [StoreBrokerSubmissionState]::Published }

                $rollout = Get-SubmissionRollout @commonParams -SubmissionId $publishedSubmission.id
                # TODO: Verify that I understand what these properties actually mean, compared to v1
                if ($rollout.isEnabled -and ($rollout.state -eq [StoreBrokerRolloutState]::Initialized))
                {
                    if ($ExistingPackageRolloutAction -eq 'Completed')
                    {
                        Write-Log -Message "Finalizing package rollout for existing submission before continuing." -Level Verbose
                        $rollout.state = [StoreBrokerRolloutState]::Completed
                    }
                    elseif ($ExistingPackageRolloutAction -eq 'RolledBack')
                    {
                        Write-Log -Message "Halting package rollout for existing submission before continuing." -Level Verbose
                        $rollout.state = [StoreBrokerRolloutState]::RolledBack
                    }

                    $null = Set-SubmissionRollout @commonParams -SubmissionId $publishedSubmission.id -Object $rollout
                }
            }
        }

        # Convert the input into a Json body.
        $hashBody = @{}
        $hashBody[[StoreBrokerSubmissionProperty]::resourceType] = [StoreBrokerResourceType]::Submission
        $hashBody[[StoreBrokerSubmissionProperty]::targets] = @()
        $hashBody[[StoreBrokerSubmissionProperty]::targets] += @{
            [StoreBrokerSubmissionTargetsProperty]::type = [StoreBrokerSubmissionTargetsValues]::scope
            [StoreBrokerSubmissionTargetsProperty]::value = $Scope
        }

        if (-not [String]::IsNullOrWhiteSpace($FlightId))
        {
            $hashBody[[StoreBrokerSubmissionProperty]::targets] += @{
                [StoreBrokerSubmissionTargetsProperty]::type = [StoreBrokerSubmissionTargetsValues]::flight
                [StoreBrokerSubmissionTargetsProperty]::value = $FlightId
            }
        }

        if (-not [String]::IsNullOrWhiteSpace($SandboxId))
        {
            $hashBody[[StoreBrokerSubmissionProperty]::targets] += @{
                [StoreBrokerSubmissionTargetsProperty]::type = [StoreBrokerSubmissionTargetsValues]::sandbox
                [StoreBrokerSubmissionTargetsProperty]::value = $SandboxId
            }
        }

        $body = Get-JsonBody -InputObject $hashBody
        Write-Log -Message "Body: $body" -Level Verbose

        $params = @{
            "UriFragment" = "products/$ProductId/submissions"
            "Method" = 'Post'
            "Description" = "Creating a new submission for product: $ProductId"
            "Body" = $body
            "ClientRequestId" = $ClientRequestId
            "CorrelationId" = $CorrelationId
            "AccessToken" = $AccessToken
            "TelemetryEventName" = "New-Submission"
            "TelemetryProperties" = $telemetryProperties
            "NoStatus" = $NoStatus
        }

        $cloneResult = Invoke-SBRestMethod @params

        if ($WaitUntilReady)
        {
            Write-Log 'The API will return back a newly cloned submission ID before it is ready to be used.  Will now query for the submission status until it is ready.' -Level Verbose
            return (Get-Submission @commonParams -SubmissionId $cloneResult.id -WaitUntilReady)
        }
        else
        {
            return $cloneResult
        }
    }
    catch
    {
        throw
    }
}

function Remove-Submission
{
<#
    .SYNOPSIS
        Deletes the specified Submission for a Product in the Windows Store.

    .DESCRIPTION
        Deletes the specified Submission for a Product in the Windows Store.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER ProductId
        The ID of the Product in the Windows Store.

    .PARAMETER SubmissionId
        The ID of the Submission for the Product that is to be deleted.

    .PARAMETER ClientRequestId
        An optional identifier that should be sent along to the Store to help with identifying
        this request during post-mortem debugging.

    .PARAMETER CorrelationId
        An optional identifier that should be sent along to the Store to help with identifying
        this request during post-mortem debugging.  This is typically supplied when trying to
        associate a group of API requests with a single end-goal.

    .PARAMETER AccessToken
        If provided, this will be used as the AccessToken for authentication with the
        REST Api as opposed to requesting a new one.

    .PARAMETER NoStatus
        If this switch is specified, long-running commands will run on the main thread
        with no commandline status update.  When not specified, those commands run in
        the background, enabling the command prompt to provide status information.

    .EXAMPLE
        Remove-Submission -ProductId 00012345678901234567 -SubmissionId 1234567890123456789

        Deletes the specified Submission for the Product.
#>
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="Methods called within here make use of PSShouldProcess, and the switch is passed on to them inherently.")]
    [Alias("Delete-Submission")]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({if ($_.Length -le 12) { throw "It looks like you supplied an AppId instead of a ProductId.  Use Get-Product with -AppId to find the ProductId for this AppId." } else { $true }})]
        [string] $ProductId,

        [Parameter(Mandatory)]
        [string] $SubmissionId,

        [string] $ClientRequestId,

        [string] $CorrelationId,

        [string] $AccessToken,

        [switch] $NoStatus
    )

    Write-Log -Message "[$($MyInvocation.MyCommand.Module.Version)] Executing: $($MyInvocation.Line.Trim())" -Level Verbose

    try
    {
        $telemetryProperties = @{
            [StoreBrokerTelemetryProperty]::ProductId = $ProductId
            [StoreBrokerTelemetryProperty]::SubmissionId = $SubmissionId
            [StoreBrokerTelemetryProperty]::ClientRequestId = $ClientRequesId
            [StoreBrokerTelemetryProperty]::CorrelationId = $CorrelationId
        }

        $params = @{
            "UriFragment" = "products/$ProductId/submissions/$SubmissionId"
            "Method" = "Delete"
            "Description" = "Deleting submission $SubmissionId for product: $ProductId"
            "ClientRequestId" = $ClientRequestId
            "CorrelationId" = $CorrelationId
            "AccessToken" = $AccessToken
            "TelemetryEventName" = "Remove-Submission"
            "TelemetryProperties" = $telemetryProperties
            "NoStatus" = $NoStatus
        }

        $null = Invoke-SBRestMethod @params
    }
    catch
    {
        throw
    }
}

function Stop-Submission
{
<#
    .SYNOPSIS
        Stops the specified pending Submission from further processing.

    .DESCRIPTION
        Stops the specified pending Submission from further processing.

        Once a submission has been submitted, it must be stopped/cancelled before it can
        removed/deleted.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER ProductId
        The ID of the Product in the Windows Store.

    .PARAMETER SubmissionId
        The ID of the Submission for the Product that is to be stopped/cancelled.

    .PARAMETER ClientRequestId
        An optional identifier that should be sent along to the Store to help with identifying
        this request during post-mortem debugging.

    .PARAMETER CorrelationId
        An optional identifier that should be sent along to the Store to help with identifying
        this request during post-mortem debugging.  This is typically supplied when trying to
        associate a group of API requests with a single end-goal.

    .PARAMETER AccessToken
        If provided, this will be used as the AccessToken for authentication with the
        REST Api as opposed to requesting a new one.

    .PARAMETER NoStatus
        If this switch is specified, long-running commands will run on the main thread
        with no commandline status update.  When not specified, those commands run in
        the background, enabling the command prompt to provide status information.

    .OUTPUTS
        [PSCustomObject] - The submission that matches the specified SubmissionId.

    .EXAMPLE
        Stop-Submission -ProductId 00012345678901234567 -SubmissionId 1234567890123456789

        Stops/cancels the specified Submission from further processing.
#>
    [Alias('Cancel-Submission')]
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="Methods called within here make use of PSShouldProcess, and the switch is passed on to them inherently.")]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({if ($_.Length -le 12) { throw "It looks like you supplied an AppId instead of a ProductId.  Use Get-Product with -AppId to find the ProductId for this AppId." } else { $true }})]
        [string] $ProductId,

        [Parameter(Mandatory)]
        [string] $SubmissionId,

        [string] $ClientRequestId,

        [string] $CorrelationId,

        [string] $AccessToken,

        [switch] $NoStatus
    )

    Write-Log -Message "[$($MyInvocation.MyCommand.Module.Version)] Executing: $($MyInvocation.Line.Trim())" -Level Verbose

    try
    {
        $telemetryProperties = @{
            [StoreBrokerTelemetryProperty]::ProductId = $ProductId
            [StoreBrokerTelemetryProperty]::SubmissionId = $SubmissionId
            [StoreBrokerTelemetryProperty]::ClientRequestId = $ClientRequesId
            [StoreBrokerTelemetryProperty]::CorrelationId = $CorrelationId
        }

        $params = @{
            "UriFragment" = "products/$ProductId/submissions/$SubmissionId/cancel"
            "Method" = 'Post'
            "Description" = "Cancelling submission $SubmissionId"
            "ClientRequestId" = $ClientRequestId
            "CorrelationId" = $CorrelationId
            "AccessToken" = $AccessToken
            "TelemetryEventName" = "Stop-Submission"
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

function Get-SubmissionDetail
{
<#
    .SYNOPSIS
        Gets the details of a Submission for a Product in the Windows Store.

    .DESCRIPTION
        Gets the details of a Submission for a Product in the Windows Store.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER ProductId
        The ID of the Product in the Windows Store.

    .PARAMETER SubmissionId
        The ID of the Submission for the Product whose details are to be retrieved.

    .PARAMETER ClientRequestId
        An optional identifier that should be sent along to the Store to help with identifying
        this request during post-mortem debugging.

    .PARAMETER CorrelationId
        An optional identifier that should be sent along to the Store to help with identifying
        this request during post-mortem debugging.  This is typically supplied when trying to
        associate a group of API requests with a single end-goal.

    .PARAMETER AccessToken
        If provided, this will be used as the AccessToken for authentication with the
        REST Api as opposed to requesting a new one.

    .PARAMETER NoStatus
        If this switch is specified, long-running commands will run on the main thread
        with no commandline status update.  When not specified, those commands run in
        the background, enabling the command prompt to provide status information.

    .OUTPUTS
        [PSCustomObject] - The submission details

    .EXAMPLE
        Get-SubmissionDetails -ProductId 00012345678901234567 -SubmissionId 1234567890123456789

        Gets the details for the specified Submission.
#>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({if ($_.Length -le 12) { throw "It looks like you supplied an AppId instead of a ProductId.  Use Get-Product with -AppId to find the ProductId for this AppId." } else { $true }})]
        [string] $ProductId,

        [Parameter(Mandatory)]
        [string] $SubmissionId,

        [string] $ClientRequestId,

        [string] $CorrelationId,

        [string] $AccessToken,

        [switch] $NoStatus
    )

    Write-Log -Message "[$($MyInvocation.MyCommand.Module.Version)] Executing: $($MyInvocation.Line.Trim())" -Level Verbose

    try
    {
        $telemetryProperties = @{
            [StoreBrokerTelemetryProperty]::ProductId = $ProductId
            [StoreBrokerTelemetryProperty]::SubmissionId = $SubmissionId
            [StoreBrokerTelemetryProperty]::ClientRequestId = $ClientRequesId
            [StoreBrokerTelemetryProperty]::CorrelationId = $CorrelationId
        }

        $params = @{
            "UriFragment" = "products/$ProductId/submissions/$SubmissionId/detail"
            "Method" = 'Get'
            "Description" = "Getting details of submission $SubmissionId for $ProductId"
            "ClientRequestId" = $ClientRequestId
            "CorrelationId" = $CorrelationId
            "AccessToken" = $AccessToken
            "TelemetryEventName" = "Get-SubmissionDetail"
            "TelemetryProperties" = $telemetryProperties
            "NoStatus" = $NoStatus
        }

        return Invoke-SBRestMethod @params
    }
    catch
    {
        throw
    }
}

function Set-SubmissionDetail
{
<#
    .SYNOPSIS
        Updates the details of a Submission for a Product in the Windows Store.

    .DESCRIPTION
        Updates the details of a Submission for a Product in the Windows Store.

        Can be used to update individual properties, or to replace the entire
        object's contents.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER ProductId
        The ID of the Product in the Windows Store.

    .PARAMETER SubmissionId
        The ID of the Submission for the Product whose details are to be updated.

    .PARAMETER Object
        If specified, the current submission details for this submission will be
        replaced with the exact contents of this object.

    .PARAMETER CertificationNotes
        The new value for this submission's Certification Notes.
        No change will be made if this value is not specified.

    .PARAMETER ReleaseDate
        The new value release date for this submission.
        No change will be made if this value is not specified.

    .PARAMETER ManualPublish
        Change if this submission should be published manually or not.
        If this switch is not specified, no change will be made to the existing object.
        To change the corresponding value, you must explicitly specify either $true or $false
        with this switch. 
    
    .PARAMETER AutoPromote
        Only relevant for Products using Sandboxes.
        Change if this submission should be automatically promoted from a Dev Sandbox to Cert Sandbox.
        If this switch is not specified, no change will be made to the existing object.
        To change the corresponding value, you must explicitly specify either $true or $false
        with this switch. 

    .PARAMETER ClientRequestId
        An optional identifier that should be sent along to the Store to help with identifying
        this request during post-mortem debugging.

    .PARAMETER CorrelationId
        An optional identifier that should be sent along to the Store to help with identifying
        this request during post-mortem debugging.  This is typically supplied when trying to
        associate a group of API requests with a single end-goal.

    .PARAMETER AccessToken
        If provided, this will be used as the AccessToken for authentication with the
        REST Api as opposed to requesting a new one.

    .PARAMETER NoStatus
        If this switch is specified, long-running commands will run on the main thread
        with no commandline status update.  When not specified, those commands run in
        the background, enabling the command prompt to provide status information.

    .EXAMPLE
        Set-SubmissionDetails -ProductId 00012345678901234567 -SubmissionId 1234567890123456789 -Object $object

        Updates the specified Submission to have the exact contents specified in $object.

    .EXAMPLE
        Set-SubmissionDetails -ProductId 00012345678901234567 -SubmissionId 1234567890123456789 -AutoPromote:$false

        Updates the isAutoPromote field of the specified Submission's details to be $false.
        (This of course implies that this Submission is in a Sandbox.)

    .EXAMPLE
        Set-SubmissionDetails -ProductId 00012345678901234567 -SubmissionId 1234567890123456789 -ReleaseDate ((Get-Date).AddDays(2)) -CertificationNotes 'Internal test'

        For the spceified submission, updates the certification notes and sets it to automatically
        publish two days from now.
#>
    [CmdletBinding(SupportsShouldProcess)]
    [Alias('New-SubmissionDetail')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="Methods called within here make use of PSShouldProcess, and the switch is passed on to them inherently.")]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({if ($_.Length -le 12) { throw "It looks like you supplied an AppId instead of a ProductId.  Use Get-Product with -AppId to find the ProductId for this AppId." } else { $true }})]
        [string] $ProductId,

        [Parameter(Mandatory)]
        [string] $SubmissionId,

        [Parameter(
            Mandatory,
            ParameterSetName="Object")]
        [PSCustomObject] $Object,

        # $null means leave as-is, empty string means clear it out.
        [Parameter(ParameterSetName="Individual")]
        [string] $CertificationNotes,

        [Parameter(ParameterSetName="Individual")]
        [DateTime] $ReleaseDate,

        [Parameter(ParameterSetName="Individual")]
        [switch] $ManualPublish,

        # This is only relevant for sandboxes
        [Parameter(ParameterSetName="Individual")]
        [switch] $AutoPromote,

        [string] $ClientRequestId,

        [string] $CorrelationId,

        [string] $AccessToken,

        [switch] $NoStatus
    )

    Write-Log -Message "[$($MyInvocation.MyCommand.Module.Version)] Executing: $($MyInvocation.Line.Trim())" -Level Verbose

    try
    {
        $telemetryProperties = @{
            [StoreBrokerTelemetryProperty]::ProductId = $ProductId
            [StoreBrokerTelemetryProperty]::SubmissionId = $SubmissionId
            [StoreBrokerTelemetryProperty]::UsingObject = ($null -ne $Object)
            [StoreBrokerTelemetryProperty]::UpdateCertificationNotes = ($null -ne $CertificationNotes)
            [StoreBrokerTelemetryProperty]::ClientRequestId = $ClientRequesId
            [StoreBrokerTelemetryProperty]::CorrelationId = $CorrelationId
        }

        Test-ResourceType -Object $Object -ResourceType ([StoreBrokerResourceType]::SubmissionDetail)

        $hashBody = $Object
        if ($null -eq $hashBody)
        {
            # Convert the input into a Json body.
            $hashBody = @{}
            $hashBody[[StoreBrokerSubmissionProperty]::resourceType] = [StoreBrokerResourceType]::SubmissionDetail

            if ($PSBoundParameters.ContainsKey('ReleaseDate'))
            {
                $hashBody[[StoreBrokerSubmissionProperty]::releaseTimeInUtc] = $ReleaseDate.ToUniversalTime().ToString('o')
            }

            if ($PSBoundParameters.ContainsKey('CertificationNotes'))
            {
                $hashBody[[StoreBrokerSubmissionProperty]::certificationNotes] = $CertificationNotes
            }

            # We only set the value if the user explicitly provided a value for this parameter
            # (so for $false, they'd have to pass in -ManualPublish:$false).
            # Otherwise, there'd be no way to know when the user wants to simply keep the
            # existing value.
            if ($PSBoundParameters.ContainsKey('ManualPublish'))
            {
                $hashBody[[StoreBrokerSubmissionProperty]::isManualPublish] = ($ManualPublish -eq $true)
                $telemetryProperties[[StoreBrokerTelemetryProperty]::IsManualPublish] = ($ManualPublish -eq $true)
            }

            # We only set the value if the user explicitly provided a value for this parameter
            # (so for $false, they'd have to pass in -AutoPromote:$false).
            # Otherwise, there'd be no way to know when the user wants to simply keep the
            # existing value.
            if ($PSBoundParameters.ContainsKey('AutoPromote'))
            {
                $hashBody[[StoreBrokerSubmissionProperty]::isAutoPromote] = ($AutoPromote -eq $true)
                $telemetryProperties[[StoreBrokerTelemetryProperty]::IsAutoPromote] = ($AutoPromote -eq $true)
            }
        }

        $body = Get-JsonBody -InputObject $hashBody
        Write-Log -Message "Body: $body" -Level Verbose

        $params = @{
            "UriFragment" = "products/$ProductId/submissions/$SubmissionId/detail"
            "Method" = 'Post'
            "Description" = "Updating detail for submission: $SubmissionId"
            "Body" = $body
            "ClientRequestId" = $ClientRequestId
            "CorrelationId" = $CorrelationId
            "AccessToken" = $AccessToken
            "TelemetryEventName" = "Set-SubmissionDetail"
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

function Update-SubmissionDetail
{
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string] $ProductId,

        [Parameter(Mandatory)]
        [string] $SubmissionId,

        [PSCustomObject] $SubmissionData,

        [switch] $UpdatePublishModeAndDateFromSubmissionData,

        [switch] $UpdateCertificationNotesFromSubmissionData,

        [ValidateSet('Immediate', 'Manual', 'SpecificDate')]
        [string] $TargetPublishMode,

        [DateTime] $TargetPublishDate,

        [string] $CertificationNotes,

        [switch] $IsMinimalObject,

        [string] $ClientRequestId,

        [string] $CorrelationId,

        [string] $AccessToken,

        [switch] $NoStatus
    )

    Write-Log -Message "[$($MyInvocation.MyCommand.Module.Version)] Executing: $($MyInvocation.Line.Trim())" -Level Verbose

    try
    {
        $providedTargetPublishMode = ($PSBoundParameters.ContainsKey('TargetPublishMode'))
        $providedTargetPublishDate = ($PSBoundParameters.ContainsKey('TargetPublishDate'))
        $providedCertificationNotes = ($PSBoundParameters.ContainsKey('CertificationNotes'))

        $providedSubmissionData = ($PSBoundParameters.ContainsKey('SubmissionData'))
        if ((-not $providedSubmissionData) -and
            ($UpdatePublishModeAndDateFromSubmissionData -or $UpdateCertificationNotesFromSubmissionData))
        {
            $message = 'Cannot request -UpdatePublishModeAndDateFromSubmissionData or -UpdateCertificationNotesFromSubmissionData without providing SubmissionData.'
            Write-Log -Message $message -Level Error
            throw $message
        }

        if ((-not $providedTargetPublishMode) -and
            (-not $providedTargetPublishDate) -and
            (-not $providedCertificationNotes) -and
            (-not $UpdatePublishModeAndDateFromSubmissionData) -and
            (-not $UpdateCertificationNotesFromSubmissionData))
        {
            Write-Log -Message 'No modification parameters provided.  Nothing to do.' -Level Verbose
            return
        }

        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

        $params = @{
            'ProductId' = $ProductId
            'SubmissionId' = $SubmissionId
            'ClientRequestId' = $ClientRequestId
            'CorrelationId' = $CorrelationId
            'AccessToken' = $AccessToken
            'NoStatus' = $NoStatus
        }

        $detail = Get-SubmissionDetail @params
        $setObjectPropertyParams = @{
            'InputObject' = $detail
            'SourceObject' = $SubmissionData
            'SkipIfNotDefined' = $IsMinimalObject
        }

        if ($UpdatePublishModeAndDateFromSubmissionData)
        {
            Set-ObjectProperty @setObjectPropertyParams -Name ([StoreBrokerSubmissionProperty]::releaseTimeInUtc) -SourceName 'targetPublishDate'
            if ((-not $IsMinimalObject) -or
                (Test-PropertyExists -InputObject $SubmissionData -Name 'targetPublishMode'))
            {
                Set-ObjectProperty @setObjectPropertyParams -Name ([StoreBrokerProductPropertyProperty]::isManualPublish) -Value ($SubmissionData.targetPublishMode -eq $script:keywordManual)
            }

            # There is no equivalent of changing to "Immediate" from a specific date/time,
            # but we can set it to null which means "now".
            if ($SubmissionData.targetPublishMode -eq $script:keywordImmediate)
            {
                Set-ObjectProperty -InputObject $detail -Name ([StoreBrokerSubmissionProperty]::releaseTimeInUtc) -Value $null
            }
        }

        # If the user passes in a different value for any of the publish/values at the commandline,
        # they override those coming from the config.
        if ($providedTargetPublishMode)
        {
            if (($TargetPublishMode -eq $script:keywordSpecificDate) -and (-not $providedTargetPublishDate))
            {
                $output = "TargetPublishMode was set to '$script:keywordSpecificDate' but TargetPublishDate was not specified."
                Write-Log -Message $output -Level Error
                throw $output
            }

            Set-ObjectProperty -InputObject $detail -Name ([StoreBrokerSubmissionProperty]::isManualPublish) -Value ($TargetPublishMode -eq $script:keywordManual)

            # There is no equivalent of changing to "Immediate" from a specific date/time,
            # but we can set it to null which means "now".
            if ($TargetPublishMode -eq $script:keywordImmediate)
            {
                Set-ObjectProperty -InputObject $detail -Name ([StoreBrokerSubmissionProperty]::releaseTimeInUtc) -Value $null
            }
        }

        if ($providedTargetPublishDate)
        {
            if ($TargetPublishMode -ne $script:keywordSpecificDate)
            {
                $output = "A TargetPublishDate was specified, but the TargetPublishMode was [$TargetPublishMode],  not '$script:keywordSpecificDate'."
                Write-Log -Message $output -Level Error
                throw $output
            }

            Set-ObjectProperty @setObjectPropertyParams -Name ([StoreBrokerSubmissionProperty]::releaseTimeInUtc) -SourceName $TargetPublishDate.ToUniversalTime().ToString('o')
        }

        if ($UpdateCertificationNotesFromSubmissionData)
        {
            Set-ObjectProperty @setObjectPropertyParams -Name ([StoreBrokerSubmissionProperty]::certificationNotes) -SourceName 'notesForCertification'
        }

        # If the user explicitly passes in CertificationNotes at the commandline, it will override
        # the value that might have come from the config file/SubmissionData.
        if ($providedCertificationNotes)
        {
            Set-ObjectProperty -InputObject $detail -Name ([StoreBrokerSubmissionProperty]::certificationNotes) -Value $CertificationNotes
        }

        $null = Set-SubmissionDetail @params -Object $detail

        # Record the telemetry for this event.
        $stopwatch.Stop()
        $telemetryMetrics = @{ [StoreBrokerTelemetryMetric]::Duration = $stopwatch.Elapsed.TotalSeconds }
        $telemetryProperties = @{
            [StoreBrokerTelemetryProperty]::ProductId = $ProductId
            [StoreBrokerTelemetryProperty]::SubmissionId = $SubmissionId
            [StoreBrokerTelemetryProperty]::UpdatePublishModeAndVisibility = $UpdatePublishModeAndVisibility
            [StoreBrokerTelemetryProperty]::TargetPublishMode = $TargetPublishMode
            [StoreBrokerTelemetryProperty]::UpdateCertificationNotes = $UpdateCertificationNotes
            [StoreBrokerTelemetryProperty]::ProvidedCertificationNotes = $providedCertificationNotes
            [StoreBrokerTelemetryProperty]::ProvidedSubmissionData = $providedSubmissionData
            [StoreBrokerTelemetryProperty]::ClientRequestId = $ClientRequesId
            [StoreBrokerTelemetryProperty]::CorrelationId = $CorrelationId
        }

        Set-TelemetryEvent -EventName Update-SubmissionDetail -Properties $telemetryProperties -Metrics $telemetryMetrics
        return
    }
    catch
    {
        throw
    }
}

# This is only relevant for sandboxes
function Push-Submission
{
    [Alias('Promote-Submission')]
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="Methods called within here make use of PSShouldProcess, and the switch is passed on to them inherently.")]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({if ($_.Length -le 12) { throw "It looks like you supplied an AppId instead of a ProductId.  Use Get-Product with -AppId to find the ProductId for this AppId." } else { $true }})]
        [string] $ProductId,

        [Parameter(Mandatory)]
        [string] $SubmissionId,

        [string] $ClientRequestId,

        [string] $CorrelationId,

        [string] $AccessToken,

        [switch] $NoStatus
    )

    Write-Log -Message "[$($MyInvocation.MyCommand.Module.Version)] Executing: $($MyInvocation.Line.Trim())" -Level Verbose

    try
    {
        $telemetryProperties = @{
            [StoreBrokerTelemetryProperty]::ProductId = $ProductId
            [StoreBrokerTelemetryProperty]::SubmissionId = $SubmissionId
            [StoreBrokerTelemetryProperty]::ClientRequestId = $ClientRequesId
            [StoreBrokerTelemetryProperty]::CorrelationId = $CorrelationId
        }

        $params = @{
            "UriFragment" = "products/$ProductId/submissions/$SubmissionId/promote"
            "Method" = 'Post'
            "Description" = "Promoting submission $SubmissionId"
            "ClientRequestId" = $ClientRequestId
            "CorrelationId" = $CorrelationId
            "AccessToken" = $AccessToken
            "TelemetryEventName" = "Push-Submission"
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

function Publish-Submission
{
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="Methods called within here make use of PSShouldProcess, and the switch is passed on to them inherently.")]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({if ($_.Length -le 12) { throw "It looks like you supplied an AppId instead of a ProductId.  Use Get-Product with -AppId to find the ProductId for this AppId." } else { $true }})]
        [string] $ProductId,

        [Parameter(Mandatory)]
        [string] $SubmissionId,

        [string] $ClientRequestId,

        [string] $CorrelationId,

        [string] $AccessToken,

        [switch] $NoStatus
    )

    Write-Log -Message "[$($MyInvocation.MyCommand.Module.Version)] Executing: $($MyInvocation.Line.Trim())" -Level Verbose

    try
    {
        $telemetryProperties = @{
            [StoreBrokerTelemetryProperty]::ProductId = $ProductId
            [StoreBrokerTelemetryProperty]::SubmissionId = $SubmissionId
            [StoreBrokerTelemetryProperty]::ClientRequestId = $ClientRequesId
            [StoreBrokerTelemetryProperty]::CorrelationId = $CorrelationId
        }

        $params = @{
            "UriFragment" = "products/$ProductId/submissions/$SubmissionId/publish"
            "Method" = 'Post'
            "Description" = "Publishing submission $SubmissionId"
            "ClientRequestId" = $ClientRequestId
            "CorrelationId" = $CorrelationId
            "AccessToken" = $AccessToken
            "TelemetryEventName" = "Publish-Submission"
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

function Get-SubmissionReport
{
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({if ($_.Length -le 12) { throw "It looks like you supplied an AppId instead of a ProductId.  Use Get-Product with -AppId to find the ProductId for this AppId." } else { $true }})]
        [string] $ProductId,

        [Parameter(Mandatory)]
        [string] $SubmissionId,

        [switch] $SinglePage,

        [string] $ClientRequestId,

        [string] $CorrelationId,

        [string] $AccessToken,

        [switch] $NoStatus
    )

    Write-Log -Message "[$($MyInvocation.MyCommand.Module.Version)] Executing: $($MyInvocation.Line.Trim())" -Level Verbose

    try
    {
        $telemetryProperties = @{
            [StoreBrokerTelemetryProperty]::ProductId = $ProductId
            [StoreBrokerTelemetryProperty]::SubmissionId = $SubmissionId
            [StoreBrokerTelemetryProperty]::ClientRequestId = $ClientRequesId
            [StoreBrokerTelemetryProperty]::CorrelationId = $CorrelationId
        }

        $params = @{
            "UriFragment" = "products/$ProductId/submissions/$SubmissionId/reports"
            "Description" = "Getting reports of submission $SubmissionId for $ProductId"
            "ClientRequestId" = $ClientRequestId
            "CorrelationId" = $CorrelationId
            "AccessToken" = $AccessToken
            "TelemetryEventName" = "Get-SubmissionReport"
            "TelemetryProperties" = $telemetryProperties
            "SinglePage" = $SinglePage
            "NoStatus" = $NoStatus
        }

        return Invoke-SBRestMethodMultipleResult @params
    }
    catch
    {
        throw
    }
}

function Submit-Submission
{
    [Alias('Commit-Submission')]
    [Alias('Copmlete-Submission')]
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="Methods called within here make use of PSShouldProcess, and the switch is passed on to them inherently.")]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({if ($_.Length -le 12) { throw "It looks like you supplied an AppId instead of a ProductId.  Use Get-Product with -AppId to find the ProductId for this AppId." } else { $true }})]
        [string] $ProductId,

        [Parameter(Mandatory)]
        [string] $SubmissionId,

        [switch] $Auto,

        [string] $ClientRequestId,

        [string] $CorrelationId,

        [string] $AccessToken,

        [switch] $NoStatus
    )

    Write-Log -Message "[$($MyInvocation.MyCommand.Module.Version)] Executing: $($MyInvocation.Line.Trim())" -Level Verbose

    try
    {
        $telemetryProperties = @{
            [StoreBrokerTelemetryProperty]::ProductId = $ProductId
            [StoreBrokerTelemetryProperty]::SubmissionId = $SubmissionId
            [StoreBrokerTelemetryProperty]::Auto = $Auto
            [StoreBrokerTelemetryProperty]::ClientRequestId = $ClientRequesId
            [StoreBrokerTelemetryProperty]::CorrelationId = $CorrelationId
        }

        $getParams = @()
        if ($Auto)
        {
            $getParams += "auto=$Auto"
        }

        $params = @{
            "UriFragment" = "products/$ProductId/submissions/$SubmissionId/submit`?" + ($getParams -join '&')
            "Method" = 'Post'
            "Description" = "Submitting submission $SubmissionId"
            "ClientRequestId" = $ClientRequestId
            "CorrelationId" = $CorrelationId
            "AccessToken" = $AccessToken
            "TelemetryEventName" = "Submit-Submission"
            "TelemetryProperties" = $telemetryProperties
            "NoStatus" = $NoStatus
        }

        $result = Invoke-SBRestMethod @params

        $product = Get-Product -ProductId $ProductId -ClientRequestId $ClientRequestId -CorrelationId $CorrelationId -AccessToken $AccessToken -NoStatus:$NoStatus
        $appId = ($product.externalIds | Where-Object { $_.type -eq 'StoreId' }).value
        Write-Log -Message @(
            "The submission has been successfully submitted.",
            "This is just the beginning though.",
            "It still has multiple phases of validation to get through, and there's no telling how long that might take.",
            "You can view the progress of the submission validation on the Dev Portal here:",
            "    https://dev.windows.com/en-us/dashboard/apps/$appId/submissions/$submissionId/",
            "or by running this command:",
            "    Get-Submission -ProductId $AppId -SubmissionId $submissionId",
            "You can automatically monitor this submission with this command:",
            "    Start-SubmissionMonitor -Product $ProductId -SubmissionId $SubmissionId -EmailNotifyTo $env:username")

        return $result
    }
    catch
    {
        throw
    }
}

function Get-SubmissionValidation
{
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({if ($_.Length -le 12) { throw "It looks like you supplied an AppId instead of a ProductId.  Use Get-Product with -AppId to find the ProductId for this AppId." } else { $true }})]
        [string] $ProductId,

        [Parameter(Mandatory)]
        [string] $SubmissionId,

        [switch] $WaitForCompletion,

        [string] $ClientRequestId,

        [string] $CorrelationId,

        [string] $AccessToken,

        [switch] $NoStatus
    )

    Write-Log -Message "[$($MyInvocation.MyCommand.Module.Version)] Executing: $($MyInvocation.Line.Trim())" -Level Verbose

    try
    {
        $telemetryProperties = @{
            [StoreBrokerTelemetryProperty]::ProductId = $ProductId
            [StoreBrokerTelemetryProperty]::SubmissionId = $SubmissionId
            [StoreBrokerTelemetryProperty]::WaitForCompletion = ($WaitForCompletion -eq $true)
            [StoreBrokerTelemetryProperty]::ClientRequestId = $ClientRequesId
            [StoreBrokerTelemetryProperty]::CorrelationId = $CorrelationId
        }

        $params = @{
            "UriFragment" = "products/$ProductId/submissions/$SubmissionId/validation"
            "Method" = 'Get'
            "Description" = "Getting validation of submission $SubmissionId for $ProductId"
            "WaitForCompletion" = $WaitForCompletion
            "ClientRequestId" = $ClientRequestId
            "CorrelationId" = $CorrelationId
            "AccessToken" = $AccessToken
            "TelemetryEventName" = "Get-SubmissionValidation"
            "TelemetryProperties" = $telemetryProperties
            "NoStatus" = $NoStatus
        }

        $result = Invoke-SBRestMethod @params
        return @($result.items)
    }
    catch
    {
        throw
    }
}

function Update-Submission
{
    [CmdletBinding(
        SupportsShouldProcess,
        DefaultParametersetName="AddPackages")]
    [OutputType([Object[]])]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({if ($_.Length -le 12) { throw "It looks like you supplied an AppId instead of a ProductId.  Use Get-Product with -AppId to find the ProductId for this AppId." } else { $true }})]
        [string] $ProductId,

        [string] $FlightId,

        [string] $SandboxId,

        [ValidateScript({if (Test-Path -Path $_ -PathType Leaf) { $true } else { throw "$_ cannot be found." }})]
        [string] $JsonPath,

        [PSCustomObject] $JsonObject,

        [ValidateScript({if (Test-Path -Path $_ -PathType Leaf) { $true } else { throw "$_ cannot be found." }})]
        [string] $ZipPath,

        [ValidateScript({if (Test-Path -Path $_ -PathType Container) { $true } else { throw "$_ cannot be found." }})]
        [string] $ContentPath,

        [Alias('AutoCommit')]
        [switch] $AutoSubmit,

        [string] $SubmissionId,

        [ValidateSet('Immediate', 'Manual', 'SpecificDate')]
        [string] $TargetPublishMode,

        [DateTime] $TargetPublishDate,

        [ValidateSet('Public', 'Private', 'StopSelling')]
        [string] $Visibility,

        [ValidateSet('Completed', 'RolledBack')]
        [string] $ExistingPackageRolloutAction,

        [ValidateRange(0, 100)]
        [float] $PackageRolloutPercentage,

        [switch] $IsMandatoryUpdate,

        [DateTime] $MandatoryUpdateEffectiveDate,

        [switch] $Force,

        [Parameter(ParameterSetName="AddPackages")]
        [switch] $AddPackages,

        [Parameter(ParameterSetName="ReplacePackages")]
        [switch] $ReplacePackages,

        [Parameter(ParameterSetName="UpdatePackages")]
        [switch] $UpdatePackages,

        [Parameter(ParameterSetName="UpdatePackages")]
        [int] $RedundantPackagesToKeep = 1,

        [string] $CertificationNotes,

        [switch] $UpdateListingText,

        [Alias('UpdateScreenshotsAndCaptions')]
        [switch] $UpdateImagesAndCaptions,

        [switch] $UpdatePublishModeAndVisibility,

        [switch] $UpdatePricingAndAvailability,

        [switch] $UpdateAppProperties,

        [switch] $UpdateGamingOptions,

        [Alias('UpdateTrailers')]
        [switch] $UpdateVideos,

        [Alias('UpdateNotesForCertification')]
        [switch] $UpdateCertificationNotes,

        # Normally, every single field is updated in a request, so if a field is missing or null,
        # is is updated to be null.  If this is set, then only the non-null/non-empty fields will
        # be updated.
        [switch] $IsMinimalObject,

        [string] $ClientRequestId,

        [string] $CorrelationId,

        [string] $AccessToken,

        [switch] $NoStatus
    )

    Write-Log -Message "[$($MyInvocation.MyCommand.Module.Version)] Executing: $($MyInvocation.Line.Trim())" -Level Verbose
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    # Make sure that we're working with full paths (since we do use non-native PowerShell commands)
    $pathsToResolve = @('JsonPath', 'ZipPath', 'ContentPath')
    foreach ($path in $pathsToResolve)
    {
        if ($PSBoundParameters.ContainsKey($path))
        {
            $pathVar = Get-Variable -Name $path
            $pathVar.Value = Resolve-UnverifiedPath -Path $pathVar.Value
        }
   }

    # Check for specified options that are invalid for Flight submission updates
    if (-not [String]::IsNullOrWhiteSpace($FlightId))
    {
        $unsupportedFlightingOptions = @(
            'UpdateListingText',
            'UpdateImagesAndCaptions',
            'UpdatePublishModeAndVisibility',
            'UpdatePricingAndAvailability',
            'UpdateAppProperties',
            'UpdateGamingOptions',
            'UpdateVideos'
        )

        foreach ($option in $unsupportedFlightingOptions)
        {
            if ($PSBoundParameters.ContainsKey($option))
            {
                $message = "[$option] is not supported for Flight submission updates."
                Write-Log -Message $message -Level Error
                throw $message
            }
        }
    }

    $isContentPathTemporary = $false

    if ((-not [String]::IsNullOrWhiteSpace($ZipPath)) -and (-not [String]::IsNullOrWhiteSpace($ContentPath)))
    {
        $message = "You should specify either ZipPath OR ContentPath.  Not both."
        Write-Log -Message $message -Level Error
        throw $message
    }

    if ($Force -and (-not [System.String]::IsNullOrEmpty($SubmissionId)))
    {
        $message = "You can't specify Force AND supply a SubmissionId."
        Write-Log -Message $message -Level Error
        throw $message
    }

    $CorrelationId = Get-CorrelationId -CorrelationId $CorrelationId -Identifier $ProductId

    $commonParams = @{
        'ClientRequestId' = $ClientRequestId
        'CorrelationId' = $CorrelationId
        'AccessToken' = $AccessToken
        'NoStatus' = $NoStatus
    }

    if (([String]::IsNullOrWhiteSpace($JsonPath)))
    {
        if ($null -eq $JsonObject)
        {
            $message = "You need to specify either JsonPath or JsonObject"
            Write-Log -Message $message -Level Error
            throw $message
        }
        else
        {
            $jsonSubmission = $JsonObject
        }
    }
    elseif ($null -eq $JsonObject)
    {
        Write-Log -Message "Reading in the submission content from: $JsonPath" -Level Verbose
        if ($PSCmdlet.ShouldProcess($JsonPath, "Get-Content"))
        {
            $jsonSubmission = [string](Get-Content $JsonPath -Encoding UTF8) | ConvertFrom-Json
        }
    }
    else
    {
        $message = "You can't specify both JsonPath and JsonObject"
        Write-Log -Message $message -Level Error
        throw $message
    }

    $product = Get-Product @commonParams -ProductId $ProductId
    $appId = ($product.externalIds | Where-Object { $_.type -eq 'StoreId' }).value

    # Extra layer of validation to protect users from trying to submit a payload to the wrong product
    $jsonProductId = $jsonSubmission.productId
    $jsonAppId = $jsonSubmission.appId
    if ([String]::IsNullOrWhiteSpace($jsonProductId))
    {
        $configPath = '.\newconfig.json'

        Write-Log -Level Warning -Message @(
            "The config file used to generate this submission did not have a ProductId defined in it.",
            "The ProductId entry in the config helps ensure that payloads are not submitted to the wrong product.",
            "Please update your app's StoreBroker config file by adding a `"productId`" property with",
            "your app's ProductId to the `"appSubmission`" section ([$ProductId]).",
            "If you're unclear on what change, needs to be done, you can re-generate your config file using",
            "   New-StoreBrokerConfigFile -ProductId $ProductId -Path `"$configPath`"",
            "and then diff the new config file against your current one to see the requested productId change.")

        # May be an older json file that still uses the AppId.  If so, do the conversion to check that way.
        if (-not ([String]::IsNullOrWhiteSpace($jsonAppId)))
        {
            $jsonProductId = $product.id

            if ($jsonAppId -ne $appId)
            {
                $output = @()
                $output += "The AppId [$jsonAppId))] in the submission content is not for the intended ProductId [$ProductId]."
                $output += "You either entered the wrong ProductId at the commandline, or you're referencing the wrong submission content to upload."

                $newLineOutput = ($output -join [Environment]::NewLine)
                Write-Log -Message $newLineOutput -Level Error
                throw $newLineOutput
            }
        }
    }

    if ((-not [String]::IsNullOrWhiteSpace($jsonProductId)) -and ($ProductId -ne $jsonProductId))
    {
        $output = @()
        $output += "The ProductId [$jsonProductId] in the submission content does not match the intended ProductId [$ProductId]."
        $output += "You either entered the wrong ProductId at the commandline, or you're referencing the wrong submission content to upload."

        $newLineOutput = ($output -join [Environment]::NewLine)
        Write-Log -Message $newLineOutput -Level Error
        throw $newLineOutput
    }

    # This is to handle the scenario where a user has specified BOTH ProductId _and_ AppId in their
    # config, but they don't refer to the same product.   We would have exited earlier if
    # only the AppId was specified and didn't match the ProductId from the commandline.
    if ((-not [String]::IsNullOrWhiteSpace($jsonAppId)) -and ($jsonAppId -ne $appId))
    {
        $output = @()
        $output += "You have both ProductId [$jsonProductId] _and_ AppId [$jsonAppId] specified in the submission content,"
        $output += "however they don't reference the same product.  Review and correct the config file that was used with"
        $output += "New-SubmissionPackage, and once fixed, create a corrected package and try this command again."

        $newLineOutput = ($output -join [Environment]::NewLine)
        Write-Log -Message $newLineOutput -Level Error
        throw $newLineOutput
    }

    if ($UpdateGamingOptions)
    {
        $message = @(
            'Gaming Options support has not been made available in v2 of the API.',
            'To make updates to Gaming Options for the time being, please use the Dev Portal.',
            'To quickly get to this product in the Dev Portal, you can use:'
            "   Open-DevPortal -AppId $AppId")
        Write-Log -Message $message -Level Error
        throw ($message -join [Environment]::NewLine)
    }

    # Identify potentially incorrect usage of this method by checking to see if no modification
    # switch was provided by the user
    if ((-not $AddPackages) -and
        (-not $ReplacePackages) -and
        (-not $UpdateListingText) -and
        (-not $UpdateImagesAndCaptions) -and
        (-not $UpdatePublishModeAndVisibility) -and
        (-not $UpdatePricingAndAvailability) -and
        (-not $UpdateAppProperties) -and
        (-not $UpdateGamingOptions) -and
        (-not $UpdateVideos) -and
        (-not $UpdateCertificationNotes) -and
        ($null -eq $PSBoundParameters['CertificationNotes']))
    {
        Write-Log -Level Warning -Message @(
            "You have not specified any `"modification`" switch for updating the submission.",
            "This means that the new submission will be identical to the current one.",
            "If this was not your intention, please read-up on the documentation for this command:",
            "     Get-Help Update-Submission -ShowWindow")
    }

    $commonParams['ProductId'] = $ProductId
    try
    {
        if ([System.String]::IsNullOrEmpty($SubmissionId))
        {
            $newSubmissionParams = $commonParams.PSObject.Copy() # Get a new instance, not a reference
            $newSubmissionParams['Force'] = $Force
            $newSubmissionParams['WaitUntilReady'] = $true
            if (-not [String]::IsNullOrEmpty($FlightId))
            {
                $newSubmissionParams['FlightId'] = $FlightId
            }

            if (-not [String]::IsNullOrEmpty($SandboxId))
            {
                $newSubmissionParams['SandboxId'] = $SandboxId
            }

            if ($PSBoundParameters.ContainsKey('ExistingPackageRolloutAction')) { $newSubmissionParams['ExistingPackageRolloutAction'] = $ExistingPackageRolloutAction }

            $submission = New-Submission @newSubmissionParams
            Write-Log "New Submission: $($submission | ConvertTo-Json -Depth 20)" -Level Verbose
            $SubmissionId = $submission.id
        }
        else
        {
            $submission = Get-Submission @commonParams -SubmissionId $SubmissionId
            if (($submission.state -ne [StoreBrokerSubmissionState]::InProgress) -or
                ($submission.subState -ne [StoreBrokerSubmissionSubState]::InDraft))
            {
                $output = @()
                $output += "We can only modify a submission that is: $([StoreBrokerSubmissionState]::InProgress)/$([StoreBrokerSubmissionSubState]::InDraft) state."
                $output += "The submission that you requested to modify ($SubmissionId) is: $($submission.state)/$($submission.subState)."

                $newLineOutput = ($output -join [Environment]::NewLine)
                Write-Log -Message $newLineOutput -Level Error
                throw $newLineOutput
            }
        }

        $commonParams['SubmissionId'] = $SubmissionId

        if ($PSCmdlet.ShouldProcess("Update Submission elements"))
        {
            # If we know that we'll be doing anything with binary content, ensure that it's accessible unzipped.
            if ($UpdateListingText -or $UpdateImagesAndCaptions -or $UpdateVideos -or $AddPackages -or $ReplacePackages -or $UpdatePackages)
            {
                if ([String]::IsNullOrEmpty($ContentPath))
                {
                    Add-Type -AssemblyName System.IO.Compression.FileSystem
                    $isContentPathTemporary = $true
                    $ContentPath = New-TemporaryDirectory
                    Write-Log -Message "Unzipping archive (Item: $ZipPath) to (Target: $ContentPath)." -Level Verbose
                    [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipPath, $ContentPath)
                    Write-Log -Message "Unzip complete." -Level Verbose
                }

                $packageParams = $commonParams.PSObject.Copy() # Get a new instance, not a reference
                $packageParams.Add('SubmissionData', $jsonSubmission)
                $packageParams.Add('ContentPath', $ContentPath)
                if ($AddPackages) { $packageParams.Add('AddPackages', $AddPackages) }
                if ($ReplacePackages) { $packageParams.Add('ReplacePackages', $ReplacePackages) }
                if ($UpdatePackages) {
                    $packageParams.Add('UpdatePackages', $UpdatePackages)
                    $packageParams.Add('RedundantPackagesToKeep', $RedundantPackagesToKeep)
                }
                $null = Update-ProductPackage @packageParams

                $listingParams = $commonParams.PSObject.Copy() # Get a new instance, not a reference
                $listingParams.Add('SubmissionData', $jsonSubmission)
                $listingParams.Add('ContentPath', $ContentPath)
                $listingParams.Add('UpdateListingText', $UpdateListingText)
                $listingParams.Add('UpdateImagesAndCaptions', $UpdateImagesAndCaptions)
                $listingParams.Add('UpdateVideos', $UpdateVideos)
                $listingParams.Add('IsMinimalObject', $IsMinimalObject)
                $null = Update-Listing @listingParams
            }

            if ($UpdateAppProperties -or $UpdateGamingOptions)
            {
                $propertyParams = $commonParams.PSObject.Copy() # Get a new instance, not a reference
                $propertyParams.Add('SubmissionData', $jsonSubmission)
                $propertyParams.Add('ContentPath', $ContentPath)
                $propertyParams.Add('UpdateCategoryFromSubmissionData', $UpdateAppProperties)
                $propertyParams.Add('UpdatePropertiesFromSubmissionData', $UpdateAppProperties)
                $propertyParams.Add('IsMinimalObject', $IsMinimalObject)
                $propertyParams.Add('UpdateGamingOptions', $UpdateGamingOptions)
                # NOTE: This pairing seems odd, but is correct for now.  API v2 puts this _localizable_
                # data in a non-localized property object
                $propertyParams.Add('UpdateContactInfoFromSubmissionData', $UpdateListingText)
                $null = Update-ProductProperty @commonParams -SubmissionData $jsonSubmission
            }

            $detailParams = $commonParams.PSObject.Copy() # Get a new instance, not a reference
            $detailParams.Add('SubmissionData', $jsonSubmission)
            $detailParams.Add('UpdatePublishModeAndDateFromSubmissionData', $UpdatePublishModeAndVisibility)
            $detailParams.Add('UpdateCertificationNotesFromSubmissionData', $UpdateCerificationNotes)
            if ($PSBoundParameters.ContainsKey('TargetPublishMode')) { $detailParams.Add("TargetPublishMode", $TargetPublishMode) }
            if ($PSBoundParameters.ContainsKey('TargetPublishDate')) { $detailParams.Add("TargetPublishDate", $TargetPublishDate) }
            if ($PSBoundParameters.ContainsKey('CertificationNotes')) { $detailParams.Add("CertificationNotes", $CertificationNotes) }
            $detailParams.Add('IsMinimalObject', $IsMinimalObject)
            $null = Update-SubmissionDetail @detailParams

            if ($UpdatePublishModeAndVisibility -or ($PSBoundParameters.ContainsKey('Visibility')))
            {
                $availabilityParams = $commonParams.PSObject.Copy() # Get a new instance, not a reference
                $availabilityParams.Add('SubmissionData', $jsonSubmission)
                $availabilityParams.Add('UpdateVisibilityFromSubmissionData', $UpdatePublishModeAndVisibility)
                if ($PSBoundParameters.ContainsKey('Visibility')) { $availabilityParams.Add("Visibility", $Visibility) }
                $availabilityParams.Add('IsMinimalObject', $IsMinimalObject)
                $null = Update-ProductAvailability @availabilityParams
            }

            if ($UpdatePricingAndAvailability)
            {
                # TODO: Figure out how to do pricing in v2
                # $jsonContent.pricing

                # TODO: No equivalent for:
                # $jsonContent.allowTargetFutureDeviceFamilies
                # $jsonContent.allowMicrosoftDecideAppAvailabilityToFutureDeviceFamilies
                # $jsonContent.enterpriseLicensing
            }

            if ($PSBoundParameters.ContainsKey('PackageRolloutPercentage'))
            {
                $rolloutParams = $commonParams.PSObject.Copy() # Get a new instance, not a reference
                $rolloutParams.Add('State', [StoreBrokerRolloutState]::Initialized)
                $rolloutParams.Add('Percentage', $PackageRolloutPercentage)
                $rolloutParams.Add('Enabled', $true)

                $null = Update-SubmissionRollout @rolloutParams
            }

            if ($IsMandatoryUpdate)
            {
                $configurationParams = $commonParams.PSObject.Copy() # Get a new instance, not a reference
                $configurationParams.Add('IsMandatoryUpdate', $true)
                if ($PSBoundParameters.ContainsKey('MandatoryUpdateEffectiveDate')) { $configurationParams.Add('MandatoryUpdateEffectiveDate', $MandatoryUpdateEffectiveDate) }

                $null = Update-ProductPackageConfiguration @configurationParams
            }
        }

        Write-Log -Message @(
            "Successfully cloned the existing submission and modified its content.",
            "You can view it on the Dev Portal here:",
            "    https://dev.windows.com/en-us/dashboard/apps/$appId/submissions/$SubmissionId/")

        if ($AutoSubmit)
        {
            Write-Log -Message "User requested -AutoSubmit.  Ensuring that all packages have been processed and submission validation has completed before submitting the submission." -Level Verbose
            Wait-ProductPackageProcessed @commonParams
            $validation = Get-SubmissionValidation @commonParams -WaitForCompletion

            if ($null -eq $validation)
            {
                Write-Log -Message "No issues found during validation." -Level Verbose
            }
            else
            {
                Write-Log -Level Verbose -Message @(
                    "Issues found during validation: ",
                    (Format-SimpleTableString -Object $validation))
            }

            $hasValidationErrors = ($validation | Where-Object { $_.severity -eq 'Error' }).Length -gt 0
            if ($hasValidationErrors)
            {
                $message = 'Unable to continue with submission because of validation errors.'
                Write-Log -Message $message -Level Error
                throw $message
            }
            else
            {
                Write-Log -Message "Submitting the submission since -AutoSubmit was requested." -Level Verbose
                $null = Submit-Submission @commonParams -Auto
            }
        }
        else
        {
            Write-Log -Message @(
                "When you're ready to commit, run this command:",
                "  Submit-Submission -ProductId $ProductId -SubmissionId $SubmissionId")
        }

        # Record the telemetry for this event.
        $stopwatch.Stop()
        $telemetryMetrics = @{ [StoreBrokerTelemetryMetric]::Duration = $stopwatch.Elapsed.TotalSeconds }
        $telemetryProperties = @{
            [StoreBrokerTelemetryProperty]::ProductId = $ProductId
            [StoreBrokerTelemetryProperty]::AppId = $AppId
            [StoreBrokerTelemetryProperty]::FlightId = $FlightId
            [StoreBrokerTelemetryProperty]::SandboxId = $SandboxId
            [StoreBrokerTelemetryProperty]::SubmissionId = $SubmissionId
            [StoreBrokerTelemetryProperty]::ZipPath = (Get-PiiSafeString -PlainText $ZipPath)
            [StoreBrokerTelemetryProperty]::ContentPath = (Get-PiiSafeString -PlainText $ContentPath)
            [StoreBrokerTelemetryProperty]::AutoSubmit = ($AutoSubmit -eq $true)
            [StoreBrokerTelemetryProperty]::Force = ($Force -eq $true)
            [StoreBrokerTelemetryProperty]::PackageRolloutPercentage = $PackageRolloutPercentage
            [StoreBrokerTelemetryProperty]::IsMandatoryUpdate = ($IsMandatoryUpdate -eq $true)
            [StoreBrokerTelemetryProperty]::AddPackages = ($AddPackages -eq $true)
            [StoreBrokerTelemetryProperty]::ReplacePackages = ($ReplacePackages -eq $true)
            [StoreBrokerTelemetryProperty]::UpdatePackages = ($UpdatePackages -eq $true)
            [StoreBrokerTelemetryProperty]::RedundantPackagesToKeep = $RedundantPackagesToKeep
            [StoreBrokerTelemetryProperty]::UpdateListingText = ($UpdateListingText -eq $true)
            [StoreBrokerTelemetryProperty]::UpdateImagesAndCaptions = ($UpdateImagesAndCaptions -eq $true)
            [StoreBrokerTelemetryProperty]::UpdateVideos = ($UpdateVideos -eq $true)
            [StoreBrokerTelemetryProperty]::UpdatePublishModeAndVisibility = ($UpdatePublishModeAndVisibility -eq $true)
            [StoreBrokerTelemetryProperty]::UpdatePricingAndAvailability = ($UpdatePricingAndAvailability -eq $true)
            [StoreBrokerTelemetryProperty]::UpdateGamingOptions = ($UpdateGamingOptions -eq $true)
            [StoreBrokerTelemetryProperty]::UpdateAppProperties = ($UpdateAppProperties -eq $true)
            [StoreBrokerTelemetryProperty]::UpdateCertificationNotes = ($UpdateCertificationNotes -eq $true)
            [StoreBrokerTelemetryProperty]::ProvidedCertificationNotes = (-not [String]::IsNullOrWhiteSpace($CertificationNotes))
            [StoreBrokerTelemetryProperty]::IsMinimalObject = ($IsMinimalObject -eq $true)
            [StoreBrokerTelemetryProperty]::ClientRequestId = $ClientRequesId
            [StoreBrokerTelemetryProperty]::CorrelationId = $CorrelationId
        }

        Set-TelemetryEvent -EventName Update-Submission -Properties $telemetryProperties -Metrics $telemetryMetrics

        return $SubmissionId
    }
    catch
    {
        throw
    }
    finally
    {
        if ($isContentPathTemporary -and (-not [String]::IsNullOrWhiteSpace($ContentPath)))
        {
            Write-Log -Message "Deleting temporary content directory: $ContentPath" -Level Verbose
            $null = Remove-Item -Force -Recurse $ContentPath -ErrorAction SilentlyContinue
            Write-Log -Message "Deleting temporary directory complete." -Level Verbose
        }
    }
}
