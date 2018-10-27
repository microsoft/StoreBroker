# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

Add-Type -TypeDefinition @"
   public enum StoreBrokerPackageProperty
   {
       fileName,
       resourceType,
       revisionToken,
       state
   }
"@

function Get-ProductPackage
{
    [CmdletBinding(
        SupportsShouldProcess,
        DefaultParametersetName="Search")]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({if ($_.Length -le 12) { throw "It looks like you supplied an AppId instead of a ProductId.  Use Get-Product with -AppId to find the ProductId for this AppId." } else { $true }})]
        [string] $ProductId,

        [Parameter(Mandatory)]
        [string] $SubmissionId,

        [Parameter(
            Mandatory,
            ParameterSetName="Known")]
        [string] $PackageId,

        [string] $FeatureGroupId,

        [Parameter(ParameterSetName="Search")]
        [switch] $SinglePage,

        [Parameter(ParameterSetName="Known")]
        [switch] $WithSasUri,

        [string] $ClientRequestId,

        [string] $CorrelationId,

        [string] $AccessToken,

        [switch] $NoStatus
    )

    Write-Log -Message "[$($MyInvocation.MyCommand.Module.Version)] Executing: $($MyInvocation.Line.Trim())" -Level Verbose

    $singleQuery = (-not [String]::IsNullOrWhiteSpace($PackageId))
    $telemetryProperties = @{
        [StoreBrokerTelemetryProperty]::ProductId = $ProductId
        [StoreBrokerTelemetryProperty]::SubmissionId = $SubmissionId
        [StoreBrokerTelemetryProperty]::PackageId = $PackageId
        [StoreBrokerTelemetryProperty]::SingleQuery = $singleQuery
        [StoreBrokerTelemetryProperty]::FeatureGroupId = $FeatureGroupId
        [StoreBrokerTelemetryProperty]::ClientRequestId = $ClientRequesId
        [StoreBrokerTelemetryProperty]::CorrelationId = $CorrelationId
    }

    $getParams = @()
    if (-not [String]::IsNullOrWhiteSpace($SubmissionId))
    {
        $getParams += "submissionId=$SubmissionId"
    }

    if (-not [String]::IsNullOrWhiteSpace($FeatureGroupId))
    {
        $getParams += "featureGroupId=$FeatureGroupId"
    }

    if ($WithSasUri)
    {
        $getParams += "withSasUri=true"
    }

    $params = @{
        "ClientRequestId" = $ClientRequestId
        "CorrelationId" = $CorrelationId
        "AccessToken" = $AccessToken
        "TelemetryEventName" = "Get-ProductPackage"
        "TelemetryProperties" = $telemetryProperties
        "NoStatus" = $NoStatus
    }

    if ($singleQuery)
    {
        $params["UriFragment"] = "products/$ProductId/packages/$PackageId`?" + ($getParams -join '&')
        $params["Method" ] = 'Get'
        $params["Description"] =  "Getting package $PackageId for $ProductId"

        return Invoke-SBRestMethod @params
    }
    else
    {
        $params["UriFragment"] = "products/$ProductId/packages`?" + ($getParams -join '&')
        $params["Description"] =  "Getting packages for $ProductId"
        $params["SinglePage" ] = $SinglePage

        return Invoke-SBRestMethodMultipleResult @params
    }
}

function Wait-ProductPackageProcessed
{
<#
    .SYNOPSIS
        A helper method for making it simple to ensure that all specifeid packages
        in a submission have been successfully processed.

    .DESCRIPTION
        Before a submission can be submitted, the submission must pass validation
        (which can be checked via Get-SubmissionValidation).  However, Submission
        Validation will return back inaccurate results for packages unless they
        have all entered the Processed state.

        This function can be used to verify that either all (or a subset of)
        packages for a submission have reached the Processed state.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER ProductId
        The ID of the product that the packages are assigned to.

    .PARAMETER SubmissionId
        The submission of the Product that the packages are assigned to.

    .PARAMETER PackageId
        The list of packages in SubmissionId to check.  If no PackageId's are specified,
        all packages assigned to the specified submission will be checked.

    .PARAMETER RetryAfter
        The number of seconds to wait before checking to see if a package's status has changed.

    .PARAMETER FeatureGroupId
        The Azure FeatureGroup that the packages are associated with.  Only relevant for Azure
        clients.

    .PARAMETER FailOnFirstError
        By default, this function will wait until all packages have either entered a final
        state of success ("Processed") or failure ("ProcessFailed").  If specified, as soon
        as it has been detected that a package has entered the "ProcessFailed" state, the
        function will immediately fail.

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
        Wait-ProductPackageProcessed -ProductId 00012345678901234567 -SubmissionId 1234567890123456789

        Waits until all packages currently attached to the specified submission have either
        completed or failed Processing.  If any failed processing, will throw an exception once
        all have been checked.

    .EXAMPLE
        Wait-ProductPackageProcessed -ProductId 00012345678901234567 -SubmissionId 1234567890123456789 -FailOnFirstError

        Waits until all packages currently attached to the specified submission have finished
        processing.  If any package checked has failed processing, this will immediately throw an
        exception without checking the status of any other packages.

    .EXAMPLE
        Wait-ProductPackageProcessed -ProductId 00012345678901234567 -SubmissionId 1234567890123456789 -ProductId @('pcs-ws-0123456789012345678-9012345678901234567')

        Only checks the specified PackageId for the indicated submission, even if that submission
        has additional packages.  Will return back as soon as the specified package has completed
        processing, or will throw an exception if it has failed processing.
#>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({if ($_.Length -le 12) { throw "It looks like you supplied an AppId instead of a ProductId.  Use Get-Product with -AppId to find the ProductId for this AppId." } else { $true }})]
        [string] $ProductId,

        [Parameter(Mandatory)]
        [string] $SubmissionId,

        [string[]] $PackageId,

        [ValidateRange(0, 3600)]
        [int] $RetryAfter = 180,

        [string] $FeatureGroupId,

        [switch] $FailOnFirstError,

        [string] $ClientRequestId,

        [string] $CorrelationId,

        [string] $AccessToken,

        [switch] $NoStatus
    )

    Write-Log -Message "[$($MyInvocation.MyCommand.Module.Version)] Executing: $($MyInvocation.Line.Trim())" -Level Verbose

    $CorrelationId = Get-CorrelationId -CorrelationId $CorrelationId -Identifier 'Wait-ProductPackageProcessed'

    $telemetryProperties = @{
        [StoreBrokerTelemetryProperty]::ProductId = $ProductId
        [StoreBrokerTelemetryProperty]::SubmissionId = $SubmissionId
        [StoreBrokerTelemetryProperty]::PackageId = $PackageId -join ', '
        [StoreBrokerTelemetryProperty]::ClientRequestId = $ClientRequesId
        [StoreBrokerTelemetryProperty]::CorrelationId = $CorrelationId
    }

    Set-TelemetryEvent -EventName Wait-ProductPackageProcessed -Properties $telemetryProperties

    $commonParams = @{
        'ProductId' = $ProductId
        'SubmissionId' = $SubmissionId
        'FeatureGroupId' = $FeatureGroupId
        'ClientRequestId' = $ClientRequestId
        'CorrelationId' = $CorrelationId
        'AccessToken' = $AccessToken
        'NoStatus' = $NoStatus
    }

    if ($PackageId.Count -eq 0)
    {
        $packages = Get-ProductPackage @commonParams
        $PackageId = $packages |
            Where-Object { $_.state -ne [StoreBrokerFileState]::Processed } |
            Select-Object -ExpandProperty id
    }

    $processFailed = @()
    $i = 0
    while ($i -lt $PackageId.Count)
    {
        $id = $PackageId[$i]
        $package = Get-ProductPackage @commonParams -PackageId $id

        if ($package.state -eq [StoreBrokerFileState]::Processed)
        {
            $i++
            continue
        }

        if ($package.state -eq [StoreBrokerFileState]::ProcessFailed)
        {
            $processFailed += $id

            if ($FailOnFirstError)
            {
                break
            }

            $i++
            continue
        }

        Write-Log -Message "Package [$id] current state is [$($package.state)].  Waiting $RetryAfter seconds before checking again."

        if ($package.state -eq [StoreBrokerFileState]::PendingUpload)
        {
            Write-Log -Message "The Store will not start to process the package until its state is set to $([StoreBrokerFileState]::Uploaded).  Until then, this function will keep checking this package's status indefinitely." -Level Warning
        }

        Start-Sleep -Seconds $RetryAfter
    }

    if ($processFailed.Count -gt 0)
    {
        $output = "One or more packages are in the ProcessFailed state: $($processFailed -join ',')"
        Write-Log -Message $output -Level Error
        throw $output
    }
}

function New-ProductPackage
{
    [CmdletBinding(
        SupportsShouldProcess,
        DefaultParametersetName="Object")]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({if ($_.Length -le 12) { throw "It looks like you supplied an AppId instead of a ProductId.  Use Get-Product with -AppId to find the ProductId for this AppId." } else { $true }})]
        [string] $ProductId,

        [string] $SubmissionId,

        [string] $FeatureGroupId,

        [Parameter(
            Mandatory,
            ParameterSetName="Object")]
        [PSCustomObject] $Object,

        [Parameter(
            Mandatory,
            ParameterSetName="Individual")]
        [string] $FileName,

        [string] $ClientRequestId,

        [string] $CorrelationId,

        [string] $AccessToken,

        [switch] $NoStatus
    )

    Write-Log -Message "[$($MyInvocation.MyCommand.Module.Version)] Executing: $($MyInvocation.Line.Trim())" -Level Verbose

    $telemetryProperties = @{
        [StoreBrokerTelemetryProperty]::ProductId = $ProductId
        [StoreBrokerTelemetryProperty]::SubmissionId = $SubmissionId
        [StoreBrokerTelemetryProperty]::FeatureGroupId = $FeatureGroupId
        [StoreBrokerTelemetryProperty]::UsingObject = ($null -ne $Object)
        [StoreBrokerTelemetryProperty]::ClientRequestId = $ClientRequesId
        [StoreBrokerTelemetryProperty]::CorrelationId = $CorrelationId
    }

    $getParams = @()
    if (-not [String]::IsNullOrWhiteSpace($SubmissionId))
    {
        $getParams += "submissionId=$SubmissionId"
    }

    if (-not [String]::IsNullOrWhiteSpace($FeatureGroupId))
    {
        $getParams += "featureGroupId=$FeatureGroupId"
    }

    Test-ResourceType -Object $Object -ResourceType ([StoreBrokerResourceType]::Package)

    $hashBody = $Object
    if ($null -eq $hashBody)
    {
        # Convert the input into a Json body.
        $hashBody = @{}
        $hashBody[[StoreBrokerPackageProperty]::resourceType] = [StoreBrokerResourceType]::Package
        $hashBody[[StoreBrokerPackageProperty]::fileName] = $FileName
    }

    $body = Get-JsonBody -InputObject $hashBody
    Write-Log -Message "Body: $body" -Level Verbose

    $params = @{
        "UriFragment" = "products/$ProductId/packages`?" + ($getParams -join '&')
        "Method" = 'Post'
        "Description" = "Creating new package for $ProductId (SubmissionId: $SubmissionId)"
        "Body" = $body
        "ClientRequestId" = $ClientRequestId
        "CorrelationId" = $CorrelationId
        "AccessToken" = $AccessToken
        "TelemetryEventName" = "New-ProductPackage"
        "TelemetryProperties" = $telemetryProperties
        "NoStatus" = $NoStatus
    }

    return Invoke-SBRestMethod @params
}

function Set-ProductPackage
{
    [CmdletBinding(
        SupportsShouldProcess,
        DefaultParametersetName="Object")]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({if ($_.Length -le 12) { throw "It looks like you supplied an AppId instead of a ProductId.  Use Get-Product with -AppId to find the ProductId for this AppId." } else { $true }})]
        [string] $ProductId,

        [Parameter(Mandatory)]
        [string] $SubmissionId,

        [Parameter(
            Mandatory,
            ParameterSetName="Individual")]
        [string] $PackageId,

        [string] $FeatureGroupId,

        [Parameter(
            Mandatory,
            ParameterSetName="Object")]
        [PSCustomObject] $Object,

        [Parameter(
            Mandatory,
            ParameterSetName="Individual")]
        [ValidateSet('PendingUpload', 'Uploaded')]
        [string] $State = 'PendingUpload',

        [Parameter(
            Mandatory,
            ParameterSetName="Individual")]
        [string] $RevisionToken,

        [string] $ClientRequestId,

        [string] $CorrelationId,

        [string] $AccessToken,

        [switch] $NoStatus
    )

    Write-Log -Message "[$($MyInvocation.MyCommand.Module.Version)] Executing: $($MyInvocation.Line.Trim())" -Level Verbose

    try
    {
        if ($null -ne $Object)
        {
            $PackageId = $Object.id
        }

        $telemetryProperties = @{
            [StoreBrokerTelemetryProperty]::ProductId = $ProductId
            [StoreBrokerTelemetryProperty]::SubmissionId = $SubmissionId
            [StoreBrokerTelemetryProperty]::PackageId = $PackageId
            [StoreBrokerTelemetryProperty]::FeatureGroupId = $FeatureGroupId
            [StoreBrokerTelemetryProperty]::UsingObject = ($null -ne $Object)
            [StoreBrokerTelemetryProperty]::State = $State
            [StoreBrokerTelemetryProperty]::RevisionToken = $RevisionToken
            [StoreBrokerTelemetryProperty]::ClientRequestId = $ClientRequesId
            [StoreBrokerTelemetryProperty]::CorrelationId = $CorrelationId
        }

        $getParams = @()
        if (-not [String]::IsNullOrWhiteSpace($SubmissionId))
        {
            $getParams += "submissionId=$SubmissionId"
        }

        if (-not [String]::IsNullOrWhiteSpace($FeatureGroupId))
        {
            $getParams += "featureGroupId=$FeatureGroupId"
        }

        Test-ResourceType -Object $Object -ResourceType ([StoreBrokerResourceType]::Package)

        $hashBody = $Object
        if ($null -eq $hashBody)
        {
            # Convert the input into a Json body.
            $hashBody = @{}
            $hashBody[[StoreBrokerPackageProperty]::resourceType] = [StoreBrokerResourceType]::Package
            $hashBody[[StoreBrokerPackageProperty]::revisionToken] = $RevisionToken
            $hashBody[[StoreBrokerPackageProperty]::state] = $State
        }

        $body = Get-JsonBody -InputObject $hashBody
        Write-Log -Message "Body: $body" -Level Verbose

        $params = @{
            "UriFragment" = "products/$ProductId/packages/$PackageId`?" + ($getParams -join '&')
            "Method" = 'Put'
            "Description" = "Updating package $PackageId for $ProductId (SubmissionId: $SubmissionId)"
            "Body" = $body
            "ClientRequestId" = $ClientRequestId
            "CorrelationId" = $CorrelationId
            "AccessToken" = $AccessToken
            "TelemetryEventName" = "Set-ProductPackage"
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

function Remove-ProductPackage
{
    [Alias('Delete-ProductPackage')]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({if ($_.Length -le 12) { throw "It looks like you supplied an AppId instead of a ProductId.  Use Get-Product with -AppId to find the ProductId for this AppId." } else { $true }})]
        [string] $ProductId,

        [Parameter(Mandatory)]
        [string] $SubmissionId,

        [Parameter(Mandatory)]
        [string] $PackageId,

        [string] $FeatureGroupId,

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
            [StoreBrokerTelemetryProperty]::PackageId = $PackageId
            [StoreBrokerTelemetryProperty]::FeatureGroupId = $FeatureGroupId
            [StoreBrokerTelemetryProperty]::ClientRequestId = $ClientRequesId
            [StoreBrokerTelemetryProperty]::CorrelationId = $CorrelationId
        }

        $getParams = @()
        if (-not [String]::IsNullOrWhiteSpace($SubmissionId))
        {
            $getParams += "submissionId=$SubmissionId"
        }

        if (-not [String]::IsNullOrWhiteSpace($FeatureGroupId))
        {
            $getParams += "featureGroupId=$FeatureGroupId"
        }

        $params = @{
            "UriFragment" = "products/$ProductId/packages/$PackageId`?" + ($getParams -join '&')
            "Method" = 'Delete'
            "Description" = "Removing package $PackageId for $ProductId (SubmissionId: $SubmissionId)"
            "ClientRequestId" = $ClientRequestId
            "CorrelationId" = $CorrelationId
            "AccessToken" = $AccessToken
            "TelemetryEventName" = "Remove-ProductPackage"
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

function Update-ProductPackage
{
    [CmdletBinding(
        SupportsShouldProcess,
        DefaultParametersetName="AddPackages")]
    param(
        [Parameter(Mandatory)]
        [string] $ProductId,

        [Parameter(Mandatory)]
        [string] $SubmissionId,

        [Parameter(Mandatory)]
        [PSCustomObject] $SubmissionData,

        [ValidateScript({if (Test-Path -Path $_ -PathType Container) { $true } else { throw "$_ cannot be found." }})]
        [string] $ContentPath, # NOTE: The main wrapper should unzip the zip (if there is one), so that all internal helpers only operate on a Contentpath

        [Parameter(ParameterSetName="AddPackages")]
        [switch] $AddPackages,

        [Parameter(ParameterSetName="ReplacePackages")]
        [switch] $ReplacePackages,

        [Parameter(ParameterSetName="UpdatePackages")]
        [switch] $UpdatePackages,

        [Parameter(ParameterSetName="UpdatePackages")]
        [int] $RedundantPackagesToKeep = 1,

        [string] $ClientRequestId,

        [string] $CorrelationId,

        [string] $AccessToken,

        [switch] $NoStatus
    )

    Write-Log -Message "[$($MyInvocation.MyCommand.Module.Version)] Executing: $($MyInvocation.Line.Trim())" -Level Verbose

    try
    {
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

        $ContentPath = Resolve-UnverifiedPath -Path $ContentPath

        if (($AddPackages -or $ReplacePackages -or $UpdatePackages) -and ($SubmissionData.applicationPackages.Count -eq 0))
        {
            $output = @()
            $output += "Your submission doesn't contain any packages, so you cannot Add, Replace or Update packages."
            $output += "Please check your input settings to New-SubmissionPackage and ensure you're providing a value for AppxPath."
            $output = $output -join [Environment]::NewLine
            Write-Log -Message $output -Level Error
            throw $output
        }

        if ((-not $AddPackages) -and (-not $ReplacePackages) -and (-not $UpdatePackages))
        {
            Write-Log -Message 'No modification parameters provided.  Nothing to do.' -Level Verbose
            return
        }

        $params = @{
            'ProductId' = $ProductId
            'SubmissionId' = $SubmissionId
            'ClientRequestId' = $ClientRequestId
            'CorrelationId' = $CorrelationId
            'AccessToken' = $AccessToken
            'NoStatus' = $NoStatus
        }

        if ($ReplacePackages)
        {
            # Get all of the current packages in the submission and delete them
            $packages = Get-ProductPackage @params
            foreach ($package in $packages)
            {
                $null = Remove-ProductPackage @params -PackageId ($package.id)
            }
        }
        elseif ($UpdatePackages)
        {
            # TODO -- Better understand the current object model so that we can accurately determine
            # which packages are redundant.
            # TODO: BE CAREFUL ABOUT KEEPING PRE-WIN 10 PACKAGES!!!
        }

        # Regardless of which method we're following, the last thing that we'll do is get these new
        # packages associated with this submission.
        foreach ($package in $SubmissionData.applicationPackages)
        {
            $packageSubmission = New-ProductPackage @params -FileName (Split-Path -Path $package.fileName -Leaf)
            $null = Set-StoreFile -FilePath (Join-Path -Path $ContentPath -ChildPath $package.fileName) -SasUri $packageSubmission.fileSasUri -NoStatus:$NoStatus
            $packageSubmission.state = [StoreBrokerFileState]::Uploaded.ToString()
            $null = Set-ProductPackage @params -Object $packageSubmission
        }

        # Record the telemetry for this event.
        $stopwatch.Stop()
        $telemetryMetrics = @{ [StoreBrokerTelemetryMetric]::Duration = $stopwatch.Elapsed.TotalSeconds }
        $telemetryProperties = @{
            [StoreBrokerTelemetryProperty]::ProductId = $ProductId
            [StoreBrokerTelemetryProperty]::SubmissionId = $SubmissionId
            [StoreBrokerTelemetryProperty]::ContentPath = (Get-PiiSafeString -PlainText $ContentPath)
            [StoreBrokerTelemetryProperty]::AddPackages = ($AddPackages -eq $true)
            [StoreBrokerTelemetryProperty]::ReplacePackages = ($ReplacePackages -eq $true)
            [StoreBrokerTelemetryProperty]::UpdatePackages = ($UpdatePackages -eq $true)
            [StoreBrokerTelemetryProperty]::RedundantPackagesToKeep = $RedundantPackagesToKeep
            [StoreBrokerTelemetryProperty]::ClientRequestId = $ClientRequesId
            [StoreBrokerTelemetryProperty]::CorrelationId = $CorrelationId
        }

        Set-TelemetryEvent -EventName Update-ProductPackage -Properties $telemetryProperties -Metrics $telemetryMetrics
        return
    }
    catch
    {
        throw
    }
}
