Add-Type -TypeDefinition @"
   public enum StoreBrokerListingProperty
   {
       description,
       devStudio,
       features,
       keywords,
       languageCode,
       licenseTerm,
       minimumHardware,
       recommendedHardware,
       releaseNotes,
       resourceType,
       revisionToken,
       shortDescription,
       shortTitle,
       shouldOverridePackageLogos,
       title,
       trademark,
       voiceTitle
   }
"@

function Get-Listing
{
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({if ($_.Length -le 12) { throw "It looks like you supplied an AppId instead of a ProductId.  Use Get-Product with -AppId to find the ProductId for this AppId." } else { $true }})]
        [string] $ProductId,

        [Parameter(Mandatory)]
        [string] $SubmissionId,

        [string] $LanguageCode,

        [string] $FeatureGroupId,

        [switch] $SinglePage,

        [string] $ClientRequestId,

        [string] $CorrelationId,

        [string] $AccessToken,

        [switch] $NoStatus
    )

    Write-Log -Message "[$($MyInvocation.MyCommand.Module.Version)] Executing: $($MyInvocation.Line.Trim())" -Level Verbose

    try
    {
        $singleQuery = (-not [String]::IsNullOrWhiteSpace($LanguageCode))
        $telemetryProperties = @{
            [StoreBrokerTelemetryProperty]::ProductId = $ProductId
            [StoreBrokerTelemetryProperty]::SubmissionId = $SubmissionId
            [StoreBrokerTelemetryProperty]::LanguageCode = $LanguageCode
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

        $params = @{
            "ClientRequestId" = $ClientRequestId
            "CorrelationId" = $CorrelationId
            "AccessToken" = $AccessToken
            "TelemetryEventName" = "Get-Listing"
            "TelemetryProperties" = $telemetryProperties
            "NoStatus" = $NoStatus
        }

        if ($singleQuery)
        {
            $params["UriFragment"] = "products/$ProductId/listings/$LanguageCode`?" + ($getParams -join '&')
            $params["Method" ] = 'Get'
            $params["Description"] =  "Getting $LanguageCode listing for $ProductId"

            return Invoke-SBRestMethod @params
        }
        else
        {
            $params["UriFragment"] = "products/$ProductId/listings`?" + ($getParams -join '&')
            $params["Description"] =  "Getting listings for $ProductId"
            $params["SinglePage" ] = $SinglePage

            return Invoke-SBRestMethodMultipleResult @params
        }
    }
    catch
    {
        throw
    }
}

function New-Listing
{
    [CmdletBinding(
        SupportsShouldProcess,
        DefaultParametersetName="Individual")]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({if ($_.Length -le 12) { throw "It looks like you supplied an AppId instead of a ProductId.  Use Get-Product with -AppId to find the ProductId for this AppId." } else { $true }})]
        [string] $ProductId,

        [Parameter(Mandatory)]
        [string] $SubmissionId,

        [Parameter(Mandatory)]
        [Alias('LangCode')]
        [string] $LanguageCode,

        [string] $FeatureGroupId,

        [Parameter(
            Mandatory,
            ParameterSetName="Object")]
        [PSCustomObject] $Object,

        [Parameter(ParameterSetName="Individual")]
        [string] $Title,

        [Parameter(ParameterSetName="Individual")]
        [string] $ShortTitle,

        [Parameter(ParameterSetName="Individual")]
        [string] $VoiceTitle,

        [Parameter(ParameterSetName="Individual")]
        [string] $ReleaseNotes,

        [Parameter(ParameterSetName="Individual")]
        [string[]] $Keywords,

        [Parameter(ParameterSetName="Individual")]
        [string] $Trademark,

        [Parameter(ParameterSetName="Individual")]
        [string] $LicenseTerm,

        [Parameter(ParameterSetName="Individual")]
        [string[]] $Features,

        [Parameter(ParameterSetName="Individual")]
        [string[]] $MinimumHardware,

        [Parameter(ParameterSetName="Individual")]
        [string[]] $RecommendedHardware,

        [Parameter(ParameterSetName="Individual")]
        [string] $DevStudio,

        [Parameter(ParameterSetName="Individual")]
        [switch] $ShouldOverridePackageLogos,

        [Parameter(ParameterSetName="Individual")]
        [string] $Description,

        [Parameter(ParameterSetName="Individual")]
        [string] $ShortDescription,

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

        Test-ResourceType -Object $Object -ResourceType ([StoreBrokerResourceType]::Listing)

        $hashBody = $Object
        if ($null -eq $hashBody)
        {
            # Convert the input into a Json body.
            $hashBody = @{}
            $hashBody[[StoreBrokerListingProperty]::resourceType] = [StoreBrokerResourceType]::Listing
            $hashBody[[StoreBrokerListingProperty]::languageCode] = $LanguageCode

            if (-not [String]::IsNullOrWhiteSpace($Title))
            {
                $hashBody[[StoreBrokerListingProperty]::title] = $Title
            }

            if (-not [String]::IsNullOrWhiteSpace($ShortTitle))
            {
                $hashBody[[StoreBrokerListingProperty]::shortTitle] = $ShortTitle
            }

            if (-not [String]::IsNullOrWhiteSpace($VoiceTitle))
            {
                $hashBody[[StoreBrokerListingProperty]::voiceTitle] = $VoiceTitle
            }

            if (-not [String]::IsNullOrWhiteSpace($ReleaseNotes))
            {
                $hashBody[[StoreBrokerListingProperty]::releaseNotes] = $ReleaseNotes
            }

            if ($null -ne $Keywords)
            {
                $hashBody[[StoreBrokerListingProperty]::keywords] = @($Keywords)
            }

            if (-not [String]::IsNullOrWhiteSpace($Trademark))
            {
                $hashBody[[StoreBrokerListingProperty]::trademark] = $Trademark
            }

            if (-not [String]::IsNullOrWhiteSpace($LicenseTerm))
            {
                $hashBody[[StoreBrokerListingProperty]::licenseTerm] = $LicenseTerm
            }

            if ($null -ne $Features)
            {
                $hashBody[[StoreBrokerListingProperty]::features] = @($Features)
            }

            if ($null -ne $MinimumHardware)
            {
                $hashBody[[StoreBrokerListingProperty]::minimumHardware] = @($MinimumHardware)
            }

            if ($null -ne $RecommendedHardware)
            {
                $hashBody[[StoreBrokerListingProperty]::recommendedHardware] = @($RecommendedHardware)
            }

            if (-not [String]::IsNullOrWhiteSpace($DevStudio))
            {
                $hashBody[[StoreBrokerListingProperty]::devStudio] = $DevStudio
            }

            # We only set the value if the user explicitly provided a value for this parameter
            # (so for $false, they'd have to pass in -ShouldOverridePackageLogos:$false).
            # Otherwise, there'd be no way to know when the user wants to simply keep the
            # existing value.
            if ($null -ne $PSBoundParameters['ShouldOverridePackageLogos'])
            {
                $hashBody[[StoreBrokerListingProperty]::shouldOverridePackageLogos] = ($ShouldOverridePackageLogos -eq $true)
                $telemetryProperties[[StoreBrokerTelemetryProperty]::ShouldOverridePackageLogos] = ($ShouldOverridePackageLogos -eq $true)
            }

            if (-not [String]::IsNullOrWhiteSpace($Description))
            {
                $hashBody[[StoreBrokerListingProperty]::description] = $Description
            }

            if (-not [String]::IsNullOrWhiteSpace($ShortDescription))
            {
                $hashBody[[StoreBrokerListingProperty]::shortDescription] = $ShortDescription
            }
        }

        $body = Get-JsonBody -InputObject $hashBody
        Write-Log -Message "Body: $body" -Level Verbose

        $params = @{
            "UriFragment" = "products/$ProductId/listings`?" + ($getParams -join '&')
            "Method" = 'Post'
            "Description" = "Creating new $LanguageCode listing for $ProductId (SubmissionId: $SubmissionId)"
            "Body" = $body
            "ClientRequestId" = $ClientRequestId
            "CorrelationId" = $CorrelationId
            "AccessToken" = $AccessToken
            "TelemetryEventName" = "New-Listing"
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

function Remove-Listing
{
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="Methods called within here make use of PSShouldProcess, and the switch is passed on to them inherently.")]
    [Alias("Delete-Listing")]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({if ($_.Length -le 12) { throw "It looks like you supplied an AppId instead of a ProductId.  Use Get-Product with -AppId to find the ProductId for this AppId." } else { $true }})]
        [string] $ProductId,

        [Parameter(Mandatory)]
        [string] $SubmissionId,

        [Parameter(Mandatory)]
        [Alias('LangCode')]
        [string] $LanguageCode,

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
            [StoreBrokerTelemetryProperty]::LanguageCode = $LanguageCode
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
            "UriFragment" = "products/$ProductId/listings/$LanguageCode" + ($getParams -join '&')
            "Method" = "Delete"
            "Description" = "Deleting the $LanguageCode listing for $ProductId (SubmissionId: $SubmissionId)"
            "ClientRequestId" = $ClientRequestId
            "CorrelationId" = $CorrelationId
            "AccessToken" = $AccessToken
            "TelemetryEventName" = "Remove-Listing"
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

function Set-Listing
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
        [Alias('LangCode')]
        [string] $LanguageCode,

        [string] $FeatureGroupId,

        [Parameter(
            Mandatory,
            ParameterSetName="Object")]
        [PSCustomObject] $Object,

        [Parameter(ParameterSetName="Individual")]
        [string] $Title,

        [Parameter(ParameterSetName="Individual")]
        [string] $ShortTitle,

        [Parameter(ParameterSetName="Individual")]
        [string] $VoiceTitle,

        [Parameter(ParameterSetName="Individual")]
        [string] $ReleaseNotes,

        [Parameter(ParameterSetName="Individual")]
        [string[]] $Keywords,

        [Parameter(ParameterSetName="Individual")]
        [string] $Trademark,

        [Parameter(ParameterSetName="Individual")]
        [string] $LicenseTerm,

        [Parameter(ParameterSetName="Individual")]
        [string[]] $Features,

        [Parameter(ParameterSetName="Individual")]
        [string[]] $MinimumHardware,

        [Parameter(ParameterSetName="Individual")]
        [string[]] $RecommendedHardware,

        [Parameter(ParameterSetName="Individual")]
        [string] $DevStudio,

        [Parameter(ParameterSetName="Individual")]
        [switch] $ShouldOverridePackageLogos,

        [Parameter(ParameterSetName="Individual")]
        [string] $Description,

        [Parameter(ParameterSetName="Individual")]
        [string] $ShortDescription,

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
            $LanguageCode = $Object.languageCode
        }

        $telemetryProperties = @{
            [StoreBrokerTelemetryProperty]::ProductId = $ProductId
            [StoreBrokerTelemetryProperty]::SubmissionId = $SubmissionId
            [StoreBrokerTelemetryProperty]::LanguageCode = $LanguageCode
            [StoreBrokerTelemetryProperty]::FeatureGroupId = $FeatureGroupId
            [StoreBrokerTelemetryProperty]::UsingObject = ($null -ne $Object)
            [StoreBrokerTelemetryProperty]::RevisionToken = $RevisionToken
            [StoreBrokerTelemetryProperty]::ClientRequestId = $ClientRequesId
            [StoreBrokerTelemetryProperty]::CorrelationId = $CorrelationId
        }

        $getParams = @()
        if (-not [String]::IsNullOrWhiteSpace($SubmissionId))
        {
            $getParams += "submissionId=$SubmissionId"
        }

        Test-ResourceType -Object $Object -ResourceType ([StoreBrokerResourceType]::Listing)

        $hashBody = $Object
        if ($null -eq $hashBody)
        {
            # Convert the input into a Json body.
            $hashBody = @{}
            $hashBody[[StoreBrokerListingProperty]::resourceType] = [StoreBrokerResourceType]::Listing
            $hashBody[[StoreBrokerListingProperty]::revisionToken] = $RevisionToken
            $hashBody[[StoreBrokerListingProperty]::languageCode] = $LanguageCode

            # Very specifically choosing to NOT use [String]::IsNullOrWhiteSpace for any
            # of these checks, because we need a way to be able to clear these notes out.
            #So, a $null means do nothing, while empty string / whitespace means clear out the value.
            if ($null -ne $Title)
            {
                $hashBody[[StoreBrokerListingProperty]::title] = $Title
            }

            if ($null -ne $ShortTitle)
            {
                $hashBody[[StoreBrokerListingProperty]::shortTitle] = $ShortTitle
            }

            if ($null -ne $VoiceTitle)
            {
                $hashBody[[StoreBrokerListingProperty]::voiceTitle] = $VoiceTitle
            }

            if ($null -ne $ReleaseNotes)
            {
                $hashBody[[StoreBrokerListingProperty]::releaseNotes] = $ReleaseNotes
            }

            if ($null -ne $Keywords)
            {
                $hashBody[[StoreBrokerListingProperty]::keywords] = @($Keywords)
            }

            if ($null -ne $Trademark)
            {
                $hashBody[[StoreBrokerListingProperty]::trademark] = $Trademark
            }

            if ($null -ne $LicenseTerm)
            {
                $hashBody[[StoreBrokerListingProperty]::licenseTerm] = $LicenseTerm
            }

            if ($null -ne $Features)
            {
                $hashBody[[StoreBrokerListingProperty]::features] = @($Features)
            }

            if ($null -ne $MinimumHardware)
            {
                $hashBody[[StoreBrokerListingProperty]::minimumHardware] = @($MinimumHardware)
            }

            if ($null -ne $RecommendedHardware)
            {
                $hashBody[[StoreBrokerListingProperty]::recommendedHardware] = @($RecommendedHardware)
            }

            if ($null -ne $DevStudio)
            {
                $hashBody[[StoreBrokerListingProperty]::devStudio] = $DevStudio
            }

            # We only set the value if the user explicitly provided a value for this parameter
            # (so for $false, they'd have to pass in -ShouldOverridePackageLogos:$false).
            # Otherwise, there'd be no way to know when the user wants to simply keep the
            # existing value.
            if ($null -ne $PSBoundParameters['ShouldOverridePackageLogos'])
            {
                $hashBody[[StoreBrokerListingProperty]::shouldOverridePackageLogos] = ($ShouldOverridePackageLogos -eq $true)
                $telemetryProperties[[StoreBrokerTelemetryProperty]::ShouldOverridePackageLogos] = ($ShouldOverridePackageLogos -eq $true)
            }

            if ($null -ne $Description)
            {
                $hashBody[[StoreBrokerListingProperty]::description] = $Description
            }

            if ($null -ne $ShortDescription)
            {
                $hashBody[[StoreBrokerListingProperty]::shortDescription] = $ShortDescription
            }
        }

        $body = Get-JsonBody -InputObject $hashBody

        $params = @{
            "UriFragment" = "products/$ProductId/listings/$LanguageCode`?" + ($getParams -join '&')
            "Method" = 'Put'
            "Description" = "Updating $LanguageCode listing for $ProductId (SubmissionId: $SubmissionId)"
            "Body" = $body
            "ClientRequestId" = $ClientRequestId
            "CorrelationId" = $CorrelationId
            "AccessToken" = $AccessToken
            "TelemetryEventName" = "Set-Listing"
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

function Update-Listing
{
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string] $ProductId,

        [Parameter(Mandatory)]
        [string] $SubmissionId,

        [Parameter(Mandatory)]
        [PSCustomObject] $SubmissionData,

        [ValidateScript({if (Test-Path -Path $_ -PathType Container) { $true } else { throw "$_ cannot be found." }})]
        [string] $ContentPath, # NOTE: The main wrapper should unzip the zip (if there is one), so that all subsequent functions only operate on a Contentpath

        [switch] $UpdateListingText,

        [Alias('UpdateScreenshotsAndCaptions')]
        [switch] $UpdateImagesAndCaptions,

        [Alias('UpdateTrailers')]
        [switch] $UpdateVideos,

        [string] $ClientRequestId,

        [string] $CorrelationId,

        [string] $AccessToken,

        [switch] $NoStatus
    )

    Write-Log -Message "[$($MyInvocation.MyCommand.Module.Version)] Executing: $($MyInvocation.Line.Trim())" -Level Verbose

    try
    {
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

        $commonParams = @{
            'ProductId' = $ProductId
            'SubmissionId' = $SubmissionId
            'ClientRequestId' = $ClientRequestId
            'CorrelationId' = $CorrelationId
            'AccessToken' = $AccessToken
            'NoStatus' = $NoStatus
        }

        $listingObjectParams = $commonParams.PSObject.Copy() # Get a new instance, not a reference
        $listingObjectParams['SubmissionData'] = $SubmissionData
        $listingObjectParams['ContentPath'] = $ContentPath

        # Determine what our current listings are.
        $currentListings = Get-Listing @commonParams

        # We need to keep track of languages in $currentListings that don't have a match in
        # $SubmissionData (so that we can remove them), as well which languages occur in $SubmissionData
        # that aren't in $currentListings so that we can add them.  We don't simply delete all and start
        # over due to the increased time/cost that we'd have by doing so.
        [System.Collections.ArrayList]$existingLangCodes = @()
        [System.Collections.ArrayList]$missingLangCodes = @()
        [System.Collections.ArrayList]$listingsToDelete = @()

        # First we update all of the language listings that were already cloned and exist in our input.
        Write-Log -Message 'Updating the cloned listings with information supplied by user data.' -Level Verbose
        foreach ($listing in $currentListings)
        {
            $suppliedListing = $SubmissionData.listings.($listing.languageCode).baseListing
            if ($null -eq $suppliedListing)
            {
                $null = $listingsToDelete.Add($listing.languageCode)
                continue
            }

            $langCode = $listing.languageCode
            $null = $existingLangCodes.Add($langCode)

            if ($UpdateListingText)
            {
                # Updating the existing Listing submission with the user's supplied content
                $listing.shortTitle = $suppliedListing.shortTitle
                $listing.voiceTitle = $suppliedListing.voiceTitle
                $listing.releaseNotes = $suppliedListing.releaseNotes
                $listing.keywords = $suppliedListing.keywords
                $listing.trademark = $suppliedListing.copyrightAndTrademarkInfo
                $listing.licenseTerm = $suppliedListing.licenseTerms
                $listing.features = $suppliedListing.features
                $listing.recommendedHardware = $suppliedListing.minimumHardware
                $listing.devStudio = $suppliedListing.devStudio
                $listing.title = $suppliedListing.title
                $listing.description = $suppliedListing.description
                $listing.shortDescription = $suppliedListing.shortDescription

                # TODO: Not currently supported by the v2 object model
                # suppliedListing.websiteUrl
                # suppliedListing.privacyPolicy
                # suppliedListing.supportContact
            }

            if ($UpdateImagesAndCaptions)
            {
                $hasAlternateIcons = (($suppliedListing.images |
                    Where-Object { $_.imageType -in ('Icon', 'Icon150x150', 'Icon71x71') }).Count -gt 0)
                $listing.shouldOverridePackageLogos = $hasAlternateIcons
            }

            if ($UpdateListingText -or $UpdateImagesAndCaptions)
            {
                $null = Set-Listing @commonParams -Object $listing
            }

            if ($UpdateImagesAndCaptions)
            {
                $null = Update-ListingImage @listingObjectParams -LanguageCode $langCode
            }

            if ($UpdateVideos)
            {
                $null = Update-ListingVideo @listingObjectParams -LanguageCode $langCode
            }
        }

        # Now we have to see what languages exist in the user's supplied content that we didn't already
        # have cloned submissions for
        $SubmissionData.listings |
            Get-Member -Type NoteProperty |
                ForEach-Object {
                    $langCode = $_.Name
                    if (-not $existingLangCodes.Contains($langCode))
                    {
                        $null = $missingLangCodes.Add($langCode)
                    }
                }

        Write-Log -Message 'Now adding listings for languages that don''t already exist.' -Level Verbose
        if (($missingLangCodes.Count -gt 0) -and (-not $UpdateListingText) -and ($UpdateImagesAndCaptions -or $UpdateVideos))
        {
            $message = @('There are new listings that need to be created, and you have indicated that you want',
                        'to update images and/or videos, but not the metadata.  This will create an inconsistent user experience.')
            Write-Log -Message $message -Level Error
            throw ($message -join [Environment]::NewLine)
        }

        foreach ($langCode in $missingLangCodes)
        {
            if ($UpdateListingText)
            {
                $suppliedListing = $SubmissionData.listings.$langCode.baselisting

                $listingParams = $commonParams.PSObject.Copy() # Get a new instance, not a reference
                $listingParams['LanguageCode'] = $langCode
                $listingParams['Title'] = $suppliedListing.title
                $listingParams['ShortTitle'] = $suppliedListing.shortTitle
                $listingParams['VoiceTitle'] = $suppliedListing.voiceTitle
                $listingParams['ReleaseNotes'] = $suppliedListing.releaseNotes
                $listingParams['Keywords'] = $suppliedListing.keywords
                $listingParams['Trademark'] = $suppliedListing.trademark
                $listingParams['LicenseTerm'] = $suppliedListing.licenseTerm
                $listingParams['Features'] = $suppliedListing.features
                $listingParams['MinimumHardware'] = $suppliedListing.minimumHardware
                $listingParams['RecommendedHardware'] = $suppliedListing.recommendedHardware
                $listingParams['DevStudio'] = $suppliedListing.devStudio
                $listingParams['Description'] = $suppliedListing.description
                $listingParams['ShortDescription'] = $suppliedListing.shortDescription

                # TODO: Not currently supported by the v2 object model
                # suppliedListing.websiteUrl
                # suppliedListing.privacyPolicy
                # suppliedListing.supportContact

                if ($UpdateImagesAndCaptions)
                {
                    $hasAlternateIcons = (($suppliedListing.images |
                        Where-Object { $_.imageType -in ('Icon', 'Icon150x150', 'Icon71x71') }).Count -gt 0)

                    $listingParams['ShouldOverridePackageLogos'] = $hasAlternateIcons
                }

                $null = New-Listing @listingParams

                # In theory, we could always do this for NEW listings regardless of the value
                # of the switch, as new listings won't validate if they don't have at least
                # one screenshot.  However, we definitely CAN'T do either of these if we're
                # not also updating metadata, as there won't be a language listing that they
                # could be associated with.
                if ($UpdateImagesAndCaptions)
                {
                    $null = Update-ListingImage @listingObjectParams -LanguageCode $langCode
                }

                if ($UpdateVideos)
                {
                    $null = Update-ListingVideo @listingObjectParams -LanguageCode $langCode
                }
            }
        }

        # We only need to remove listings if we're updating listing text.  If we're not removing listings,
        # then we shouldn't remove the images or videos for listings, even if the user specified
        # UpdateImagesAndCaptions or UpdateVideos.  And if we are removing listings, then we MUST
        # remove the corresponding images and videos, otherwise we risk these dangling images/videos
        # from getting auto re-linked should the user ever add that deleted language listing back.
        if ($UpdateListingText)
        {
            Write-Log -Message 'Now removing listings for languages that were cloned by the submission but don''t have current user data.' -Level Verbose
            foreach ($langCode in $listingsToDelete)
            {
                $null = Remove-Listing @commonParams -LanguageCode $langCode
                $null = Update-ListingImage @commonParams -LanguageCode $langCode -RemoveOnly
                $null = Update-ListingVideo @commonParams -LanguageCode $langCode -RemoveOnly
            }
        }

        # Record the telemetry for this event.
        $stopwatch.Stop()
        $telemetryMetrics = @{ [StoreBrokerTelemetryMetric]::Duration = $stopwatch.Elapsed.TotalSeconds }
        $telemetryProperties = @{
            [StoreBrokerTelemetryProperty]::ProductId = $ProductId
            [StoreBrokerTelemetryProperty]::SubmissionId = $SubmissionId
            [StoreBrokerTelemetryProperty]::ContentPath = (Get-PiiSafeString -PlainText $ContentPath)
            [StoreBrokerTelemetryProperty]::UpdateListingText = $UpdateListingText
            [StoreBrokerTelemetryProperty]::UpdateImagesAndCaptions = $UpdateImagesAndCaptions
            [StoreBrokerTelemetryProperty]::UpdateVideos = $UpdateVideos
            [StoreBrokerTelemetryProperty]::ClientRequestId = $ClientRequesId
            [StoreBrokerTelemetryProperty]::CorrelationId = $CorrelationId
        }

        Set-TelemetryEvent -EventName Update-Listing -Properties $telemetryProperties -Metrics $telemetryMetrics
        return
    }
    catch
    {
        throw
    }
}
