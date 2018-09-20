Add-Type -TypeDefinition @"
   public enum StoreBrokerSubmissionProperty
   {
       certificationNotes,
       isAutoPromote,
       isManualPublish,
       releaseTimeInUtc,
       resourceType,
       revisionToken,
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
        [ValidateSet('Live', 'Preview')]  # Preview is currently limited to Azure
        [string] $Scope = 'Live',

        [Parameter(
            Mandatory,
            ParameterSetName="Known")]
        [string] $SubmissionId,

        [Parameter(ParameterSetName="Known")]
        [switch] $Detail,

        [Parameter(ParameterSetName="Known")]
        [switch] $Reports,

        [Parameter(ParameterSetName="Known")]
        [switch] $Validation,

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
            [StoreBrokerTelemetryProperty]::GetReports = $Reports
            [StoreBrokerTelemetryProperty]::GetValidation = $Validation
            [StoreBrokerTelemetryProperty]::SingleQuery = $singleQuery
            [StoreBrokerTelemetryProperty]::ClientRequestId = $ClientRequesId
            [StoreBrokerTelemetryProperty]::CorrelationId = $CorrelationId
        }

        $getParams = @()
        $getParams += "scope=$Scope"

        if (-not [String]::IsNullOrWhiteSpace($FlightId))
        {
            $getParams += "flightId=$FlightId"
        }

        if (-not [String]::IsNullOrWhiteSpace($SandboxId))
        {
            $getParams += "sandboxId=$SandboxId"
        }

        if (-not [String]::IsNullOrWhiteSpace($State))
        {
            $getParams += "state=$State"
        }

        $params = @{
            "ClientRequestId" = $ClientRequestId
            "CorrelationId" = $CorrelationId
            "AccessToken" = $AccessToken
            "TelemetryEventName" = "Get-Submission"
            "TelemetryProperties" = $telemetryProperties
            "NoStatus" = $NoStatus
        }

        if ($singleQuery)
        {
            $params["UriFragment"] = "products/$ProductId/submissions/$SubmissionId"
            $params["Method" ] = 'Get'
            $params["Description"] =  "Getting submission $SubmissionId for $ProductId"

            Write-Output (Invoke-SBRestMethod @params)

            $params = @{
                'ProductId' = $ProductId
                'SubmissionId' = $SubmissionId
                'ClientRequestId' = $ClientRequesId
                'CorrelationId' = $CorrelationId
                'AccessToken' = $AccessToken
                'NoStatus' = $NoStatus
            }

            if ($Detail)
            {
                Write-Output (Get-SubmissionDetail @params)
            }

            if ($Reports)
            {
                Write-Output (Get-SubmissionReport @params)
            }

            if ($Validation)
            {
                Write-Output (Get-SubmissionValidation @params)
            }
        }
        else
        {
            $params["UriFragment"] = "products/$ProductId/submissions`?" + ($getParams -join '&')
            $params["Description"] =  "Getting submissions for $ProductId"
            $params["SinglePage" ] = $SinglePage

            return Invoke-SBRestMethodMultipleResult @params
        }
    }
    catch
    {
        throw
    }
}

function New-Submission
{
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

        [int] $WaitSeconds = -1, # 0 means no wait.  We'll use -1 to indicate not to send it, which causes it to use the server side default of 60 seconds.

        [ValidateSet('Live', 'Preview')]  # Preview is currently limited to Azure
        [string] $Scope = 'Live',

        [ValidateSet('Completed', 'RolledBack')]
        [string] $ExistingPackageRolloutAction,

        [switch] $Force,

        [string] $ClientRequestId,

        [string] $CorrelationId,

        [string] $AccessToken,

        [switch] $NoStatus
    )

    Write-Log -Message "[$($MyInvocation.MyCommand.Module.Version)] Executing: $($MyInvocation.Line.Trim())" -Level Verbose

    try
    {
        $providedExistingPackageRolloutAction = ($null -ne $PSBoundParameters['ExistingPackageRolloutAction'])

        $telemetryProperties = @{
            [StoreBrokerTelemetryProperty]::ProductId = $ProductId
            [StoreBrokerTelemetryProperty]::FlightId = $FlightId
            [StoreBrokerTelemetryProperty]::SandboxId = $SandboxId
            [StoreBrokerTelemetryProperty]::Scope = $Scope
            [StoreBrokerTelemetryProperty]::WaitSeconds = $WaitSeconds
            [StoreBrokerTelemetryProperty]::ClientRequestId = $ClientRequesId
            [StoreBrokerTelemetryProperty]::CorrelationId = $CorrelationId
        }

        if ($Force -or $providedExistingPackageRolloutAction)
        {
            Write-Log -Message "Force creation requested. Removing any pending submission." -Level Verbose

            $commonParams = @{
                'ProductId' = $ProductId
                'ClientRequestId' = $ClientRequestId
                'CorrelationId' = $CorrelationId
                'AccessToken' = $AccessToken
                'NoStatus' = $NoStatus
            }

            $getSubmissionParams = $commonParams.PSObject.Copy() # Get a new instance, not a reference
            $getSubmissionParams['FlightId'] = $FlightId
            $getSubmissionParams['SandboxId'] = $SandboxId
            $getSubmissionParams['Scope'] = $Scope

            $subs = Get-Submission @getSubmissionParams
            $inProgressSub = $subs | Where-Object { $_.state -eq [StoreBrokerSubmissionState]::InProgress }
            $commonParams['SubmissionId'] = $inProgressSub.id

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

                # We can't delete a submission that isn't in the InDraft substate.  We'd have to cancel it first.
                if ($inProgressSub.substate -ne [StoreBrokerSubmissionSubState]::InDraft)
                {
                    $null = Stop-Submission @commonParams
                }

                $null = Remove-Submission @commonParams
            }

            # The user may have requested that we also take care of any existing rollout state for them.
            if ($providedExistingPackageRolloutAction)
            {
                $publishedSubmission = $subs | Where-Object { $_.state -eq [StoreBrokerSubmissionState]::Published }
                $commonParams['SubmissionId'] = $publishedSubmission.id

                $rollout = Get-SubmissionRollout @commonParams
                # TODO: Verify that I understand what these properties actually mean, compared to v1
                if ($rollout.isEnabled -and ($rollout.state -eq [StoreBrokerRolloutState]::Initialized))
                {
                    $setSubmissionRolloutParams = $commonParams.PSObject.Copy() # Get a new instance, not a reference

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

                    $setSubmissionRolloutParams['Object'] = $rollout
                    $null = Set-SubmissionRollout @setSubmissionRolloutParams
                }
            }
        }

        $getParams = @()
        if ($WaitSeconds -ge 0)
        {
            $getParams += "waitSeconds=$WaitSeconds"
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
            "UriFragment" = "products/$ProductId/submissions`?" + ($getParams -join '&')
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

        return (Invoke-SBRestMethod @params)

    }
    catch
    {
        throw
    }
}

function Remove-Submission
{
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

            if ($null -ne $PSBoundParameters['ReleaseDate'])
            {
                $hashBody[[StoreBrokerSubmissionProperty]::releaseTimeInUtc] = $ReleaseDate.ToUniversalTime().ToString('o')
            }

            if ($null -ne $PSBoundParameters['CertificationNotes'])
            {
                $hashBody[[StoreBrokerSubmissionProperty]::certificationNotes] = $CertificationNotes
            }

            # We only set the value if the user explicitly provided a value for this parameter
            # (so for $false, they'd have to pass in -ManualPublish:$false).
            # Otherwise, there'd be no way to know when the user wants to simply keep the
            # existing value.
            if ($null -ne $PSBoundParameters['ManualPublish'])
            {
                $hashBody[[StoreBrokerSubmissionProperty]::isManualPublish] = ($ManualPublish -eq $true)
                $telemetryProperties[[StoreBrokerTelemetryProperty]::IsManualPublish] = ($ManualPublish -eq $true)
            }

            # We only set the value if the user explicitly provided a value for this parameter
            # (so for $false, they'd have to pass in -AutoPromote:$false).
            # Otherwise, there'd be no way to know when the user wants to simply keep the
            # existing value.
            if ($null -ne $PSBoundParameters['AutoPromote'])
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

        [string] $ClientRequestId,

        [string] $CorrelationId,

        [string] $AccessToken,

        [switch] $NoStatus
    )

    Write-Log -Message "[$($MyInvocation.MyCommand.Module.Version)] Executing: $($MyInvocation.Line.Trim())" -Level Verbose

    try
    {
        $providedTargetPublishMode = ($null -ne $PSBoundParameters['TargetPublishMode'])
        $providedTargetPublishDate = ($null -ne $PSBoundParameters['TargetPublishDate'])
        $providedCertificationNotes = ($null -ne $PSBoundParameters['CertificationNotes'])

        $providedSubmissionData = ($null -ne $PSBoundParameters['SubmissionData'])
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

        if ($UpdatePublishModeAndDateFromSubmissionData)
        {
            $detail.isManualPublish = ($SubmissionData.targetPublishMode -eq $script:keywordManual)
            $detail.releaseTimeInUtc = $SubmissionData.targetPublishDate

            # There is no equivalent of changing to "Immediate" from a specific date/time,
            # but we can set it to null which means "now".
            if ($SubmissionData.targetPublishMode -eq $script:keywordImmediate)
            {
                $detail.releaseTimeInUtc = $null
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

            $detail.isManualPublish = ($TargetPublishMode -eq $script:keywordManual)

            # There is no equivalent of changing to "Immediate" from a specific date/time,
            # but we can set it to null which means "now".
            if ($TargetPublishMode -eq $script:keywordImmediate)
            {
                $detail.releaseTimeInUtc = $null
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

            $PatchedSubmission.targetPublishDate = $TargetPublishDate.ToUniversalTime().ToString('o')
        }

        if ($UpdateCertificationNotesFromSubmissionData)
        {
            $detail.certificationNotes = $SubmissionData.notesForCertification
        }

        # If the user explicitly passes in CertificationNotes at the commandline, it will override
        # the value that might have come from the config file/SubmissionData.
        if ($providedCertificationNotes)
        {
            $detail.certificationNotes = $CertificationNotes
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
            "UriFragment" = "products/$ProductId/submissions/$SubmissionId/validation"
            "Method" = 'Get'
            "Description" = "Getting validation of submission $SubmissionId for $ProductId"
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

        [string] $ClientRequestId,

        [string] $CorrelationId,

        [string] $AccessToken,

        [switch] $NoStatus
    )

    Write-Log -Message "[$($MyInvocation.MyCommand.Module.Version)] Executing: $($MyInvocation.Line.Trim())" -Level Verbose
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

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
    if ([String]::IsNullOrWhiteSpace($jsonProductId))
    {
        $configPath = Join-Path -Path ([System.Environment]::GetFolderPath('Desktop')) -ChildPath 'newconfig.json'

        Write-Log -Level Warning -Message @(
            "The config file used to generate this submission did not have a ProductId defined in it.",
            "The ProductId entry in the config helps ensure that payloads are not submitted to the wrong product.",
            "Please update your app's StoreBroker config file by adding a `"productId`" property with",
            "your app's ProductId to the `"appSubmission`" section ([$ProductId]).",
            "If you're unclear on what change, needs to be done, you can re-generate your config file using",
            "   New-StoreBrokerConfigFile -ProductId $ProductId -Path `"$configPath`"",
            "and then diff the new config file against your current one to see the requested productId change.")

        # May be an older json file that still uses the AppId.  If so, do the conversion to check that way.
        if (-not ([String]::IsNullOrWhiteSpace($jsonSubmission.appId)))
        {
            $jsonProductId = $product.id

            if ($jsonSubmission.appId -ne $appId)
            {
                $output = @()
                $output += "The AppId [$($jsonSubmission.appId))] in the submission content is not for the intended ProductId [$ProductId]."
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
            $newSubmissionParams['FlightId'] = $FlightId
            $newSubmissionParams['Force'] = $Force
            if ($null -ne $PSBoundParameters['ExistingPackageRolloutAction']) { $newSubmissionParams['ExistingPackageRolloutAction'] = $ExistingPackageRolloutAction }

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
                $null = Update-Listing @listingParams
            }

            if ($UpdateAppProperties -or $UpdateGamingOptions)
            {
                $propertyParams = $commonParams.PSObject.Copy() # Get a new instance, not a reference
                $propertyParams.Add('SubmissionData', $jsonSubmission)
                $propertyParams.Add('ContentPath', $ContentPath)
                $propertyParams.Add('UpdateCategoryFromSubmissionData', $UpdateAppProperties)
                $propertyParams.Add('UpdatePropertiesFromSubmissionData', $UpdateAppProperties)
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
            if ($null -ne $PSBoundParameters['TargetPublishMode']) { $detailParams.Add("TargetPublishMode", $TargetPublishMode) }
            if ($null -ne $PSBoundParameters['TargetPublishDate']) { $detailParams.Add("TargetPublishDate", $TargetPublishDate) }
            if ($null -ne $PSBoundParameters['CertificationNotes']) { $detailParams.Add("CertificationNotes", $CertificationNotes) }
            $null = Update-SubmissionDetail @detailParams

            if ($UpdatePublishModeAndVisibility -or ($null -ne $PSBoundParameters['Visibility']))
            {
                $availabilityParams = $commonParams.PSObject.Copy() # Get a new instance, not a reference
                $availabilityParams.Add('SubmissionData', $jsonSubmission)
                $availabilityParams.Add('UpdateVisibilityFromSubmissionData', $UpdatePublishModeAndVisibility)
                if ($null -ne $PSBoundParameters['Visibility']) { $availabilityParams.Add("Visibility", $Visibility) }
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

            if ($null -ne $PSBoundParameters['PackageRolloutPercentage'])
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
                if ($null -ne $PSBoundParameters['MandatoryUpdateEffectiveDate']) { $configurationParams.Add('MandatoryUpdateEffectiveDate', $MandatoryUpdateEffectiveDate) }

                $null = Update-ProductPackageConfiguration @configurationParams
            }
        }

        Write-Log -Message @(
            "Successfully cloned the existing submission and modified its content.",
            "You can view it on the Dev Portal here:",
            "    https://dev.windows.com/en-us/dashboard/apps/$appId/submissions/$SubmissionId/")

        if ($AutoSubmit)
        {
            Write-Log -Message "Submitting the submission since -AutoSubmit was requested." -Level Verbose
            Submit-Submission @commonParams -Auto
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
