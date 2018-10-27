# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

Add-Type -TypeDefinition @"
   public enum StoreBrokerListingImageProperty
   {
       fileName,
       description,
       resourceType,
       revisionToken,
       orientation,
       state,
       type
   }
"@


function Get-ListingImage
{
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({if ($_.Length -le 12) { throw "It looks like you supplied an AppId instead of a ProductId.  Use Get-Product with -AppId to find the ProductId for this AppId." } else { $true }})]
        [string] $ProductId,

        [Parameter(Mandatory)]
        [string] $SubmissionId,

        [Parameter(Mandatory)]
        [Alias('LangCode')]
        [string] $LanguageCode,

        [string] $ImageId,

        [switch] $SinglePage,

        [string] $ClientRequestId,

        [string] $CorrelationId,

        [string] $AccessToken,

        [switch] $NoStatus
    )

    Write-Log -Message "[$($MyInvocation.MyCommand.Module.Version)] Executing: $($MyInvocation.Line.Trim())" -Level Verbose

    try
    {
        $singleQuery = (-not [String]::IsNullOrWhiteSpace($ImageId))
        $telemetryProperties = @{
            [StoreBrokerTelemetryProperty]::ProductId = $ProductId
            [StoreBrokerTelemetryProperty]::SubmissionId = $SubmissionId
            [StoreBrokerTelemetryProperty]::LanguageCode = $LanguageCode
            [StoreBrokerTelemetryProperty]::ImageId = $ImageId
            [StoreBrokerTelemetryProperty]::SingleQuery = $singleQuery
            [StoreBrokerTelemetryProperty]::ClientRequestId = $ClientRequesId
            [StoreBrokerTelemetryProperty]::CorrelationId = $CorrelationId
        }

        $getParams = @()
        if (-not [String]::IsNullOrWhiteSpace($SubmissionId))
        {
            $getParams += "submissionId=$SubmissionId"
        }

        $params = @{
            "ClientRequestId" = $ClientRequestId
            "CorrelationId" = $CorrelationId
            "AccessToken" = $AccessToken
            "TelemetryEventName" = "Get-ListingImage"
            "TelemetryProperties" = $telemetryProperties
            "NoStatus" = $NoStatus
        }

        if ($singleQuery)
        {
            $params["UriFragment"] = "products/$ProductId/listings/$LanguageCode/images/$ImageId`?" + ($getParams -join '&')
            $params["Method" ] = 'Get'
            $params["Description"] =  "Getting [$LanguageCode] listing image $ImageId for $ProductId"

            return Invoke-SBRestMethod @params
        }
        else
        {
            $params["UriFragment"] = "products/$ProductId/listings/$LanguageCode/images`?" + ($getParams -join '&')
            $params["Description"] =  "Getting [$LanguageCode] listing images for $ProductId"
            $params["SinglePage" ] = $SinglePage

            return Invoke-SBRestMethodMultipleResult @params
        }
    }
    catch
    {
        throw
    }
 }

function New-ListingImage
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

        [Parameter(Mandatory)]
        [Alias('LangCode')]
        [string] $LanguageCode,

        [Parameter(
            Mandatory,
            ParameterSetName="Object")]
        [PSCustomObject[]] $Object,

        [Parameter(
            Mandatory,
            ParameterSetName="Individual")]
        [string] $FileName,

        [Parameter(
            Mandatory,
            ParameterSetName="Individual")]
        [ValidateSet(
            'HeroImage414x180', 'HeroImage846x468', 'HeroImage558x756', 'HeroImage414x468', 'HeroImage558x558', 'HeroImage2400x1200',
            'Screenshot', 'ScreenshotWXGA', 'ScreenshotHD720', 'ScreenshotWVGA',
            'SmallMobileTile', 'SmallXboxLiveTile', 'LargeMobileTile', 'LargeXboxLiveTile', 'Tile',
            'DesktopIcon', 'Icon', 'AchievementIcon', 'ChallengePromoIcon', 'RewardDisplayIcon', 'Icon150X150', 'Icon71X71',
            'Doublewide', 'Panoramic', 'Square', 'MobileScreenshot', 'XboxScreenshot', 'SurfaceHubScreenshot', 'HoloLensScreenshot',
            'BoxArt', 'BrandedKeyArt', 'PosterArt', 'FeaturedPromotionalArt', 'PromotionalArt16x9', 'TitledHeroArt')]
        [string] $Type,

        [Parameter(ParameterSetName="Individual")]
        [int] $Orientation = 0,

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
            [StoreBrokerTelemetryProperty]::LanguageCode = $LanguageCode
            [StoreBrokerTelemetryProperty]::Type = $Type
            [StoreBrokerTelemetryProperty]::Orientation = $Orientation
            [StoreBrokerTelemetryProperty]::ClientRequestId = $ClientRequesId
            [StoreBrokerTelemetryProperty]::CorrelationId = $CorrelationId
        }

        $getParams = @()
        if (-not [String]::IsNullOrWhiteSpace($SubmissionId))
        {
            $getParams += "submissionId=$SubmissionId"
        }

        Test-ResourceType -Object $Object -ResourceType ([StoreBrokerResourceType]::ListingImage)

        $hashBody = $Object
        if ($null -eq $hashBody)
        {
            # Convert the input into a Json body.
            $hashBody = @{}
            $hashBody[[StoreBrokerListingImageProperty]::resourceType] = [StoreBrokerResourceType]::ListingImage
            $hashBody[[StoreBrokerListingImageProperty]::fileName] = $FileName
            $hashBody[[StoreBrokerListingImageProperty]::type] = $Type
            $hashBody[[StoreBrokerListingImageProperty]::orientation] = $Orientation
        }

        $body = Get-JsonBody -InputObject $hashBody
        Write-Log -Message "Body: $body" -Level Verbose

        $uriFragment = "products/$ProductId/listings/$LanguageCode/images`?" + ($getParams -join '&')
        $description = "Creating new $LanguageCode listing image for $ProductId (SubmissionId: $SubmissionId)"
        $isbulkOperation = $Object.Count -gt 1
        if ($isbulkOperation)
        {
            $uriFragment = "products/$ProductId/listings/$LanguageCode/images/bulk`?" + ($getParams -join '&')
            $description = "Bulk creating $LanguageCode listing images for $ProductId (SubmissionId: $SubmissionId)"
        }

        $params = @{
            "UriFragment" = $uriFragment
            "Method" = 'Post'
            "Description" = $description
            "Body" = $body
            "ClientRequestId" = $ClientRequestId
            "CorrelationId" = $CorrelationId
            "AccessToken" = $AccessToken
            "TelemetryEventName" = "New-ListingImage"
            "TelemetryProperties" = $telemetryProperties
            "NoStatus" = $NoStatus
        }

        $result = Invoke-SBRestMethod @params
        if ($isbulkOperation)
        {
            $finalResult = @()
            $finalResult += $result.value

            if ($null -ne $result.nextLink)
            {
                $params = @{
                    "UriFragment" = $result.nextLink
                    "Description" = "Getting remaining results"
                    "ClientRequestId" = $ClientRequestId
                    "CorrelationId" = $CorrelationId
                    "AccessToken" = $AccessToken
                    "TelemetryEventName" = "New-ListingImage"
                    "TelemetryProperties" = $telemetryProperties
                    "NoStatus" = $NoStatus
                }

                $finalResult += Invoke-SBRestMethodMultipleResult @params
            }

            return $finalResult
        }
        else
        {
            return $result
        }
    }
    catch
    {
        throw
    }
}

function Remove-ListingImage
{
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="Methods called within here make use of PSShouldProcess, and the switch is passed on to them inherently.")]
    [Alias("Delete-ListingImage")]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({if ($_.Length -le 12) { throw "It looks like you supplied an AppId instead of a ProductId.  Use Get-Product with -AppId to find the ProductId for this AppId." } else { $true }})]
        [string] $ProductId,

        [Parameter(Mandatory)]
        [string] $SubmissionId,

        [Parameter(Mandatory)]
        [Alias('LangCode')]
        [string] $LanguageCode,

        [Parameter(Mandatory)]
        [string] $ImageId,

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
            [StoreBrokerTelemetryProperty]::LanguageCode = $LanguageCode
            [StoreBrokerTelemetryProperty]::ImageId = $ImageId
            [StoreBrokerTelemetryProperty]::ClientRequestId = $ClientRequesId
            [StoreBrokerTelemetryProperty]::CorrelationId = $CorrelationId
        }

        $getParams = @()
        if (-not [String]::IsNullOrWhiteSpace($SubmissionId))
        {
            $getParams += "submissionId=$SubmissionId"
        }

        $params = @{
            "UriFragment" = "products/$ProductId/listings/$LanguageCode/images/$ImageId`?" + ($getParams -join '&')
            "Method" = "Delete"
            "Description" = "Deleting image $ImageId from the $LanguageCode listing for $ProductId (SubmissionId: $SubmissionId)"
            "ClientRequestId" = $ClientRequestId
            "CorrelationId" = $CorrelationId
            "AccessToken" = $AccessToken
            "TelemetryEventName" = "Remove-ListingImage"
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

function Set-ListingImage
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

        [Parameter(Mandatory)]
        [Alias('LangCode')]
        [string] $LanguageCode,

        [Parameter(
            Mandatory,
            ParameterSetName="Individual")]
        [string] $ImageId,

        [Parameter(
            Mandatory,
            ParameterSetName="Object")]
        [PSCustomObject] $Object,

        # Can't change filename or type once it's been created.  Would need to delete and re-create.

        [Parameter(
            Mandatory,
            ParameterSetName="Individual")]
        [ValidateSet('PendingUpload', 'Uploaded')]
        [string] $State,

        [Parameter(ParameterSetName="Individual")]
        [int] $Orientation = 0,

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
            $ImageId = $Object.id
        }

        $telemetryProperties = @{
            [StoreBrokerTelemetryProperty]::ProductId = $ProductId
            [StoreBrokerTelemetryProperty]::SubmissionId = $SubmissionId
            [StoreBrokerTelemetryProperty]::LanguageCode = $LanguageCode
            [StoreBrokerTelemetryProperty]::ImageId = $ImageId
            [StoreBrokerTelemetryProperty]::State = $State
            [StoreBrokerTelemetryProperty]::Orientation = $Orientation
            [StoreBrokerTelemetryProperty]::RevisionToken = $RevisionToken
            [StoreBrokerTelemetryProperty]::ClientRequestId = $ClientRequesId
            [StoreBrokerTelemetryProperty]::CorrelationId = $CorrelationId
        }

        $getParams = @()
        if (-not [String]::IsNullOrWhiteSpace($SubmissionId))
        {
            $getParams += "submissionId=$SubmissionId"
        }

        Test-ResourceType -Object $Object -ResourceType ([StoreBrokerResourceType]::ListingImage)

        $hashBody = $Object
        if ($null -eq $hashBody)
        {
            # Convert the input into a Json body.
            $hashBody = @{}
            $hashBody[[StoreBrokerListingImageProperty]::revisionToken] = $RevisionToken
            $hashBody[[StoreBrokerListingImageProperty]::resourceType] = [StoreBrokerResourceType]::ListingImage
            $hashBody[[StoreBrokerListingImageProperty]::orientation] = $Orientation
            $hashBody[[StoreBrokerListingImageProperty]::state] = $State
        }

        $body = Get-JsonBody -InputObject $hashBody
        Write-Log -Message "Body: $body" -Level Verbose

        $params = @{
            "UriFragment" = "products/$ProductId/listings/$LanguageCode/images/$ImageId`?" + ($getParams -join '&')
            "Method" = 'Put'
            "Description" = "Updating listing image $ImageId for $ProductId (SubmissionId: $SubmissionId)"
            "Body" = $body
            "ClientRequestId" = $ClientRequestId
            "CorrelationId" = $CorrelationId
            "AccessToken" = $AccessToken
            "TelemetryEventName" = "Set-ListingImage"
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

function Update-ListingImage
{
    [CmdletBinding(
        SupportsShouldProcess,
        DefaultParametersetName="Update")]
    param(
        [Parameter(Mandatory)]
        [string] $ProductId,

        [Parameter(Mandatory)]
        [string] $SubmissionId,

        [Parameter(
            Mandatory,
            ParameterSetName="Update")]
        [PSCustomObject] $SubmissionData,

        [Parameter(
            Mandatory,
            ParameterSetName="Update")]
        [ValidateScript({if (Test-Path -Path $_ -PathType Container) { $true } else { throw "$_ cannot be found." }})]
        [string] $ContentPath, # NOTE: The main wrapper should unzip the zip (if there is one), so that all internal helpers only operate on a Contentpath

        [Parameter(Mandatory)]
        [Alias('LangCode')]
        [string] $LanguageCode,

        [Parameter(ParameterSetName="RemoveOnly")]
        [switch] $RemoveOnly,

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

        $params = @{
            'ProductId' = $ProductId
            'SubmissionId' = $SubmissionId
            'LanguageCode' = $LanguageCode
            'ClientRequestId' = $ClientRequestId
            'CorrelationId' = $CorrelationId
            'AccessToken' = $AccessToken
            'NoStatus' = $NoStatus
        }

        $currentImages = Get-ListingImage @params

        # First we delete all of the existing images
        Write-Log -Message "Removing all [$LanguageCode] listing images." -Level Verbose
        foreach ($image in $currentImages)
        {
            $null = Remove-ListingImage @params -ImageId $image.id
        }

        if (-not $RemoveOnly)
        {
            # Then we proceed with adding/uploading all of the current images
            Write-Log -Message "Creating [$LanguageCode] listing images." -Level Verbose
            foreach ($image in $SubmissionData.listings.$LanguageCode.baseListing.images)
            {
                # TODO: Determine if we should expose Orientation to the PDP and then here.
                $type = Get-ValidImageType -Type $image.imageType
                $imageSubmission = New-ListingImage @params -FileName (Split-Path -Path $image.fileName -Leaf) -Type $type
                $null = Set-StoreFile -FilePath (Join-Path -Path $ContentPath -ChildPath $image.fileName) -SasUri $imageSubmission.fileSasUri -NoStatus:$NoStatus

                Add-Member -InputObject $imageSubmission -Name ([StoreBrokerListingImageProperty]::state.ToString()) -Value ([StoreBrokerFileState]::Uploaded.ToString()) -Type NoteProperty -Force

                $imageSubmission.state = [StoreBrokerFileState]::Uploaded.ToString()
                $imageSubmission.description = $image.description

                $null = Set-ListingImage @params -Object $imageSubmission
            }
        }

        # Record the telemetry for this event.
        $stopwatch.Stop()
        $telemetryMetrics = @{ [StoreBrokerTelemetryMetric]::Duration = $stopwatch.Elapsed.TotalSeconds }
        $telemetryProperties = @{
            [StoreBrokerTelemetryProperty]::ProductId = $ProductId
            [StoreBrokerTelemetryProperty]::SubmissionId = $SubmissionId
            [StoreBrokerTelemetryProperty]::ContentPath = (Get-PiiSafeString -PlainText $ContentPath)
            [StoreBrokerTelemetryProperty]::LanguageCode = $LanguageCode
            [StoreBrokerTelemetryProperty]::RemoveOnly = $RemoveOnly
            [StoreBrokerTelemetryProperty]::ClientRequestId = $ClientRequesId
            [StoreBrokerTelemetryProperty]::CorrelationId = $CorrelationId
        }

        Set-TelemetryEvent -EventName Update-ListingImage -Properties $telemetryProperties -Metrics $telemetryMetrics
        return
    }
    catch
    {
        throw
    }
}

function Get-ValidImageType
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Type
    )

    # We only have entries to translate v1 type names to v2 typenames.
    # For all other types, we'll return them as-is.
    $imageTypeMap = @{
        'StoreLogo9x16'               = 'PosterArt'
        'StoreLogoSquare'             = 'BoxArt'
        'PromotionalArtwork2400X1200' = 'HeroImage2400x1200'
        'XboxBrandedKeyArt'           = 'BrandedKeyArt'
        'XboxTitledHeroArt'           = 'TitledHeroArt'
        'XboxFeaturedPromotionalArt'  = 'FeaturedPromotionalArt'
        'SquareIcon358X358'           = 'Square'
        'BackgroundImage1000X800'     = 'Panoramic'
        'PromotionalArtwork414X180'   = 'HeroImage414x180'
    }

    $translatedType = $imageTypeMap[$Type]
    if ([String]::IsNullOrWhiteSpace($translatedType))
    {
        return $Type
    }
    else
    {
        Write-Log -Message "Translated v1 image type [$Type] to [$translatedType]." -Level Verbose
        return $translatedType
    }
}
