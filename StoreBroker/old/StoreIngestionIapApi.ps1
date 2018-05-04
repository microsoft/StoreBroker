# Copyright (C) Microsoft Corporation.  All rights reserved.

function Get-InAppProducts
{
<#
    .SYNOPSIS
        Retrieves all IAP's associated across all applications for this
        developer account.

    .DESCRIPTION
        Retrieves all IAP's associated across all applications for this
        developer account.
        Pipe the result of this command into Format-InAppProducts for a
        pretty-printed display of the results.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER MaxResults
        The number of IAP's that should be returned in the query.
        Defaults to 100.

    .PARAMETER StartAt
        The 0-based index (of all IAP's) that the returned results should
        start returning from.
        Defaults to 0.

    .PARAMETER GetAll
        If this switch is specified, the cmdlet will automatically loop in batches
        to get all of the IAP's for this developer account (all applications).
        Using this will ignore the provided value for -StartAt, but will use the
        value provided for -MaxResults as its per-query limit.
        WARNING: This might take a while depending on how many applications and
        IAP's are in your developer account.

    .PARAMETER NoStatus
        If this switch is specified, long-running commands will run on the main thread
        with no commandline status update.  When not specified, those commands run in
        the background, enabling the command prompt to provide status information.

    .EXAMPLE
        Get-InAppProducts

        Gets all of the IAP's associated with all applications in this developer account,
        with the console window showing progress while awaiting the response
        from the REST request.

    .EXAMPLE
        Get-InAppProducts -NoStatus

        Gets all of the IAP's associated with all applications in this developer account,
        but the request happens in the foreground and there is no additional status
        shown to the user until a response is returned from the REST request.

    .EXAMPLE
        $iaps = Get-InAppProducts

        Retrieves all of the IAP's associated with this developer account,
        and saves the results in a variable called $iaps that can be used for
        further processing.

    .EXAMPLE
        Get-InAppProducts | Format-InAppProducts

        Gets all of the IAP's associated with all applications in this developer account,
        and then displays it in a pretty-printed, formatted result.
#>
    [CmdletBinding(SupportsShouldProcess)]
    [Alias('Get-Iaps')]
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
        "UriFragment" = "inappproducts/"
        "Description" = "Getting IAP's"
        "MaxResults" = $MaxResults
        "StartAt" = $StartAt
        "AccessToken" = $AccessToken
        "TelemetryEventName" = "Get-InAppProducts"
        "GetAll" = $GetAll
        "NoStatus" = $NoStatus
    }

    return (Invoke-SBRestMethodMultipleResult @params)
}

function Format-InAppProducts
{
<#
    .SYNOPSIS
        Pretty-prints the results of Get-InAppProducts

    .DESCRIPTION
        This method is intended to be used by callers of Get-InAppProducts.
        It takes the result from Get-InAppProducts and presents it in a more easily
        viewable manner.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER IapData
        The output returned from Get-InAppProducts.
        Supports Pipeline input.

    .EXAMPLE
        Format-InAppProducts (Get-InAppProducts)

        Explicitly gets the result from Get-InAppProducts and passes that in as the input
        to Format-InAppProducts for pretty-printing.

    .EXAMPLE
        Get-InAppProducts | Format-InAppProducts

        Pipes the result of Get-InAppProducts directly into Format-InAppProducts
        for pretty-printing.
#>
    [CmdletBinding()]
    [Alias('Format-Iaps')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "", Justification="Formatting method designed to mimic the actual API method.")]
    param(
        [Parameter(
            Mandatory,
            ValueFromPipeline)]
        [PSCustomObject] $IapData
    )

    Begin
    {
        Set-TelemetryEvent -EventName Format-InAppProducts

        Write-Log -Message "Displaying IAP's..." -Level Verbose

        $publishedSubmissionField = @{ label="lastPublishedSubmission"; Expression={ if (([String]::IsNullOrEmpty($_.lastPublishedInAppProductSubmission.id)) -or ($_.lastPublishedInAppProductSubmission.id -eq "0")) { "<None>" } else { $_.lastPublishedInAppProductSubmission.id } }; }
        $pendingSubmissionField = @{ label="pendingSubmission"; Expression={ if (($null -eq $_.pendingInAppProductSubmission) -or ($_.pendingInAppProductSubmission.id -eq "0")) { "<None>" } else { $_.pendingInAppProductSubmission.id } }; }
        $applicationsField = @{ label="applications"; Expression={ if ($_.applications.totalCount -eq 0) { "<None>" } else { $_.applications.value.id -join ", " } }; }

        $iaps = @()
    }

    Process
    {
        $iaps += $IapData
    }

    End
    {
        Write-Log -Message $($iaps | Sort-Object productId | Format-Table id, productId, productType, $publishedSubmissionField, $pendingSubmissionField, $applicationsField | Out-String)
    }
}

function Get-InAppProduct
{
<#
    .SYNOPSIS
        Retrieves the detail for the specified IAP associated with the developer account.

    .DESCRIPTION
        Retrieves the detail for the specified IAP associated with the developer account.

        Pipe the result of this command into Format-InAppProduct for a pretty-printed display
        of the result.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER IapId
        The ID for the In-App Product that you want to retrieve the information for.

    .PARAMETER NoStatus
        If this switch is specified, long-running commands will run on the main thread
        with no commandline status update.  When not specified, those commands run in
        the background, enabling the command prompt to provide status information.

    .EXAMPLE
        Get-InAppProduct 0ABCDEF12345

        Gets the detail for this IAP with the console window showing progress while awaiting
        the response from the REST request.

    .EXAMPLE
        Get-InAppProduct 0ABCDEF12345 -NoStatus

        Gets the detail for this IAP, but the request happens in the foreground and there is
        no additional status shown to the user until a response is returned from the REST request.

    .EXAMPLE
        $iap = Get-InAppProduct 0ABCDEF12345

        Retrieves the detail for this IAP , and saves the results in a variable called $iap
        that can be used for further processing.

    .EXAMPLE
        Get-InAppProduct 0ABCDEF12345| Format-InAppProduct

        Gets the detail for this IAP, and then displays it in a pretty-printed, formatted result.
#>
    [CmdletBinding(SupportsShouldProcess)]
    [Alias('Get-Iap')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="Methods called within here make use of PSShouldProcess, and the switch is passed on to them inherently.")]
    param(
        [Parameter(Mandatory)]
        [string] $IapId,

        [string] $AccessToken = "",

        [switch] $NoStatus
    )

    Write-Log -Message "[$($MyInvocation.MyCommand.Module.Version)] Executing: $($MyInvocation.Line.Trim())" -Level Verbose

    $telemetryProperties = @{ [StoreBrokerTelemetryProperty]::IapId = $IapId }

    $params = @{
        "UriFragment" = "inappproducts/$iapId"
        "Method" = "Get"
        "Description" = "Getting data for IAP: $IapId"
        "AccessToken" = $AccessToken
        "TelemetryEventName" = "Get-InAppProduct"
        "TelemetryProperties" = $telemetryProperties
        "NoStatus" = $NoStatus
    }

    return (Invoke-SBRestMethod @params)
}

function Format-InAppProduct
{
<#
    .SYNOPSIS
        Pretty-prints the results of Get-InAppProduct

    .DESCRIPTION
        This method is intended to be used by callers of Get-InAppProduct.
        It takes the result from Get-InAppProduct and presents it in a more easily
        viewable manner.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER IapData
        The output returned from Get-InAppProduct.
        Supports Pipeline input.

    .EXAMPLE
        Format-InAppProduct $(Get-InAppProduct 0ABCDEF12345)

        Explicitly gets the result from Get-InAppProduct and passes that in as the input
        to Format-InAppProduct for pretty-printing.

    .EXAMPLE
        Get-InAppProduct 0ABCDEF12345 | Format-InAppProduct

        Pipes the result of Get-InAppProduct directly into Format-InAppProduct for pretty-printing.
#>
    [CmdletBinding()]
    [Alias('Format-Iap')]
    param(
        [Parameter(
            Mandatory,
            ValueFromPipeline)]
        [PSCustomObject] $IapData
    )

    Begin
    {
        Set-TelemetryEvent -EventName Format-InAppProduct

        Write-Log -Message "Displaying IAP..." -Level Verbose

        $indentLength = 5
        $output = @()
    }

    Process
    {
        $output += ""
        $output += "Id                        : $($IapData.id)"
        $output += "Product ID                : $($IapData.productId)"
        $output += "Product Type              : $($IapData.productType)"
        $output += "Application Id's          :"
        $output += $IapData.applications.value.id | Format-SimpleTableString -IndentationLevel $indentLength
        $output += "Last Published Submission : {0}" -f $(if (($null -eq $IapData.lastPublishedInAppProductSubmission.id) -or ($_.lastPublishedInAppProductSubmission.id -eq "0")) { "---" } else { $IapData.lastPublishedInAppProductSubmission.id } )
        $output += "Pending Submission        : {0}" -f $(if (($null -eq $IapData.pendingInAppProductSubmission.id) -or ($_.pendingInAppProductSubmission.id -eq "0")) { "---" } else { $IapData.pendingInAppProductSubmission.id } )
    }

    End
    {
        Write-Log -Message $output
    }
}

function Get-ApplicationInAppProducts
{
<#
    .SYNOPSIS
        Retrieves all IAP's associated with the specified application for this
        developer account.

    .DESCRIPTION
        Retrieves all IAP's associated with the specified application for this
        developer account.
        Pipe the result of this command into Format-ApplicationInAppProducts for a
        pretty-printed display of the results.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER AppId
        The Application ID for the application that you want to retrieve the information
        about.

    .PARAMETER MaxResults
        The number of IAP's for this application that should be returned in the query.
        Defaults to 100.

    .PARAMETER StartAt
        The 0-based index (of all IAP's for this app) that the returned
        results should start returning from.
        Defaults to 0.

    .PARAMETER GetAll
        If this switch is specified, the cmdlet will automatically loop in batches
        to get all of the IAP's for this application.  Using this will ignore
        the provided value for -StartAt, but will use the value provided for
        -MaxResults as its per-query limit.
        WARNING: This might take a while depending on how many applications and
        IAP's are in your developer account.

    .PARAMETER NoStatus
        If this switch is specified, long-running commands will run on the main thread
        with no commandline status update.  When not specified, those commands run in
        the background, enabling the command prompt to provide status information.

    .EXAMPLE
        Get-ApplicationInAppProducts 0ABCDEF12345

        Gets all of the IAP's associated with this applications in this developer account,
        with the console window showing progress while awaiting the response
        from the REST request.

    .EXAMPLE
        Get-ApplicationInAppProducts 0ABCDEF12345 -NoStatus

        Gets all of the IAP's associated with this applications in this developer account,
        but the request happens in the foreground and there is no additional status
        shown to the user until a response is returned from the REST request.

    .EXAMPLE
        $iaps = Get-ApplicationInAppProducts 0ABCDEF12345

        Retrieves all of the IAP's for the specified application, and saves the results
        variable called $iaps that can be used for further processing.

    .EXAMPLE
        Get-ApplicationInAppProducts 0ABCDEF12345 | Format-ApplicationInAppProducts

        Gets all of the IAP's associated with this applications in this developer account,
        and then displays it in a pretty-printed, formatted result.
#>
    [CmdletBinding(SupportsShouldProcess)]
    [Alias('Get-ApplicationIaps')]
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

    Write-Log -Message "[$($MyInvocation.MyCommand.Module.Version)] Executing: $($MyInvocation.Line.Trim())" -Level Verbose

    $telemetryProperties = @{ [StoreBrokerTelemetryProperty]::AppId = $AppId }

    $params = @{
        "UriFragment" = "applications/$AppId/listinappproducts/"
        "Description" = "Getting IAP's for AppId: $AppId"
        "MaxResults" = $MaxResults
        "StartAt" = $StartAt
        "AccessToken" = $AccessToken
        "TelemetryEventName" = "Get-ApplicationInAppProducts"
        "TelemetryProperties" = $telemetryProperties
        "GetAll" = $GetAll
        "NoStatus" = $NoStatus
    }

    return (Invoke-SBRestMethodMultipleResult @params)
}

function Format-ApplicationInAppProducts
{
<#
    .SYNOPSIS
        Pretty-prints the results of Get-ApplicationInAppProducts

    .DESCRIPTION
        This method is intended to be used by callers of Get-ApplicationInAppProducts.
        It takes the result from Get-ApplicationInAppProducts and presents it in a more easily
        viewable manner.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER ApplicationIapData
        The output returned from Get-ApplicationInAppProducts.
        Supports Pipeline input.

    .EXAMPLE
        Format-ApplicationInAppProducts (Get-ApplicationInAppProducts 0ABCDEF12345)

        Explicitly gets the result from Get-ApplicationInAppProducts and passes that in as the input
        to Format-ApplicationInAppProducts for pretty-printing.

    .EXAMPLE
        Get-ApplicationInAppProducts 0ABCDEF12345 | Format-ApplicationInAppProducts

        Pipes the result of Get-ApplicationInAppProducts directly into Format-ApplicationInAppProducts
        for pretty-printing.
#>
    [CmdletBinding()]
    [Alias('Format-ApplicationIaps')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "", Justification="Formatting method designed to mimic the actual API method.")]
    param(
        [Parameter(
            Mandatory,
            ValueFromPipeline)]
        [PSCustomObject] $ApplicationIapData
    )

    Begin
    {
        Set-TelemetryEvent -EventName Format-ApplicationInAppProducts

        Write-Log -Message "Displaying Application IAP's..." -Level Verbose

        $iaps = @()
    }

    Process
    {
        $iaps += $ApplicationIapData
    }

    End
    {
        Write-Log -Message $($iaps | Format-Table inAppProductId | Out-String)
    }
}

function New-InAppProduct
{
    <#
    .SYNOPSIS
        Creates a new In-App Product associated with this developer account.

    .DESCRIPTION
        Creates a new In-App Product associated with this developer account.

    .PARAMETER ProductId
        An ID of your choosing that must be unique across all IAP's in your
        developer account.  You will refer to this IAP in your code with via
        this ID.

    .PARAMETER ProductType
        Indicates what kind of IAP this is.
        One of: NotSet, Consumable, Durable, Subscription

    .PARAMETER ApplicationIds
        The list of Application ID's that this IAP should be associated with.

    .PARAMETER AccessToken
        If provided, this will be used as the AccessToken for authentication with the
        REST Api as opposed to requesting a new one.

    .PARAMETER NoStatus
        If this switch is specified, long-running commands will run on the main thread
        with no commandline status update.  When not specified, those commands run in
        the background, enabling the command prompt to provide status information.

    .EXAMPLE
        New-InAppProduct "First IAP" Consumable 0ABCDEF12345,7890HGFEDCBA

        Creates a new consumable IAP that will be referred to as "First IAP" in your code.
        This IAP will be associated with two different Applications.

    .EXAMPLE
        New-InAppProduct "Second IAP" Durable 0ABCDEF12345 -NoStatus

        Creates a new durable IAP that will be referred to as "Second IAP" in your code.
        This IAP will be associated with a single Applications.
        The request happens in the foreground and there is no additional
        status shown to the user until a response is returned from the REST request.
#>
    [CmdletBinding(SupportsShouldProcess)]
    [Alias('New-Iap')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="Methods called within here make use of PSShouldProcess, and the switch is passed on to them inherently.")]
    param(
        [Parameter(Mandatory)]
        [string] $ProductId,

        [Parameter(Mandatory)]
        [ValidateSet('NotSet', 'Consumable', 'Durable', 'Subscription')]
        [string] $ProductType,

        [Parameter(Mandatory)]
        [string[]] $ApplicationIds,

        [string] $AccessToken = "",

        [switch] $NoStatus
    )

    Write-Log -Message "[$($MyInvocation.MyCommand.Module.Version)] Executing: $($MyInvocation.Line.Trim())" -Level Verbose

    # Convert the input into a Json body.
    $hashBody = @{}
    $hashBody["productId"] = $ProductId
    $hashBody["productType"] = $ProductType
    $hashBody["applicationIds"] = $ApplicationIds

    $body = $hashBody | ConvertTo-Json

    $telemetryProperties = @{
        [StoreBrokerTelemetryProperty]::ProductId = $ProductId
        [StoreBrokerTelemetryProperty]::ProductType = $ProductType
    }

    $params = @{
        "UriFragment" = "inappproducts/"
        "Method" = "Post"
        "Description" = "Creating a new IAP called: $productId"
        "Body" = $body
        "AccessToken" = $AccessToken
        "TelemetryEventName" = "New-InAppProduct"
        "TelemetryProperties" = $telemetryProperties
        "NoStatus" = $NoStatus
    }

    return (Invoke-SBRestMethod @params)
}

function Remove-InAppProduct
{
    <#
    .SYNOPSIS
        Deletes the specified In-App Product from the developer's account.

    .DESCRIPTION
        Deletes the specified In-App Product from the developer's account.

    .PARAMETER IapId
        The ID for the In-App Product that is being removed.

    .PARAMETER AccessToken
        If provided, this will be used as the AccessToken for authentication with the
        REST Api as opposed to requesting a new one.

    .PARAMETER NoStatus
        If this switch is specified, long-running commands will run on the main thread
        with no commandline status update.  When not specified, those commands run in
        the background, enabling the command prompt to provide status information.

    .EXAMPLE
        Remove-InAppProduct 0ABCDEF12345

        Removes the specified In-App Product from the developer's account,
        with the console window showing progress while awaiting the response
        from the REST request.

    .EXAMPLE
        Remove-InAppProduct 0ABCDEF12345 -NoStatus

        Removes the specified In-App Product from the developer's account,
        but the request happens in the foreground and there is no additional status
        shown to the user until a response is returned from the REST request.
#>
    [CmdletBinding(SupportsShouldProcess)]
    [Alias('Remove-Iap')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="Methods called within here make use of PSShouldProcess, and the switch is passed on to them inherently.")]
    param(
        [Parameter(Mandatory)]
        [string] $IapId,

        [string] $AccessToken = "",

        [switch] $NoStatus
    )

    Write-Log -Message "[$($MyInvocation.MyCommand.Module.Version)] Executing: $($MyInvocation.Line.Trim())" -Level Verbose

    $telemetryProperties = @{ [StoreBrokerTelemetryProperty]::IapId = $IapId }

    $params = @{
        "UriFragment" = "inappproducts/$IapId"
        "Method" = "Delete"
        "Description" = "Deleting IAP: $IapId"
        "Body" = $body
        "AccessToken" = $AccessToken
        "TelemetryEventName" = "Remove-InAppProduct"
        "TelemetryProperties" = $telemetryProperties
        "NoStatus" = $NoStatus
    }

    $null = Invoke-SBRestMethod @params
}

function Get-InAppProductSubmission
{
<#
    .SYNOPSIS
        Retrieves the details of a specific In-App Product submission.

    .DESCRIPTION
        Retrieves the details of a specific In-App Product submission.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER IapId
        The ID for the In-App Product that you want to retrieve the information about.

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
        Get-InAppProductSubmission 0ABCDEF12345 01234567-89ab-cdef-0123-456789abcdef 1234567890123456789

        Gets all of the detail known for this In-App Product's submission,
        with the console window showing progress while awaiting the response
        from the REST request.

    .EXAMPLE
        Get-InAppProductSubmission 0ABCDEF12345 01234567-89ab-cdef-0123-456789abcdef 1234567890123456789 -NoStatus

        Gets all of the detail known for this In-App Product's submission,
        but the request happens in the foreground and there is no additional status
        shown to the user until a response is returned from the REST request.

    .EXAMPLE
        $submission = Get-InAppProductSubmission 0ABCDEF12345 1234567890123456789

        Retrieves all of the In-App Product's submission detail, and saves the results in
        a variable called $submission that can be used for further processing.

    .EXAMPLE
        Get-InAppProductSubmission 0ABCDEF12345 1234567890123456789 | Format-InAppProductSubmission

        Pretty-print the results by piping them into Format-InAppProductSubmission.
#>
    [CmdletBinding(SupportsShouldProcess)]
    [Alias('Get-IapSubmission')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="Methods called within here make use of PSShouldProcess, and the switch is passed on to them inherently.")]
    param(
        [Parameter(Mandatory)]
        [string] $IapId,

        [Parameter(Mandatory)]
        [string] $SubmissionId,

        [string] $AccessToken = "",

        [switch] $NoStatus
    )

    Write-Log -Message "[$($MyInvocation.MyCommand.Module.Version)] Executing: $($MyInvocation.Line.Trim())" -Level Verbose

    $telemetryProperties = @{
        [StoreBrokerTelemetryProperty]::IapId = $IapId
        [StoreBrokerTelemetryProperty]::SubmissionId = $SubmissionId
    }

    $params = @{
        "UriFragment" = "inappproducts/$IapId/submissions/$SubmissionId"
        "Method" = "Get"
        "Description" = "Getting SubmissionId: $SubmissionId for IapId: $IapId"
        "AccessToken" = $AccessToken
        "TelemetryEventName" = "Get-InAppProductSubmission"
        "TelemetryProperties" = $telemetryProperties
        "NoStatus" = $NoStatus
    }

    return (Invoke-SBRestMethod @params)
}

function Format-InAppProductSubmission
{
<#
    .SYNOPSIS
        Pretty-prints the results of Get-InAppProductSubmission

    .DESCRIPTION
        This method is intended to be used by callers of Get-InAppProductSubmission.
        It takes the result from Get-InAppProductSubmission and presents it in a more easily
        viewable manner.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER IapSubmissionData
        The output returned from Get-InAppProductSubmission.
        Supports Pipeline input.

    .EXAMPLE
        Format-InAppProductSubmission $(Get-InAppProductSubmission 0ABCDEF12345 1234567890123456789)

        Explicitly gets the result from Get-InAppProductSubmission and passes that in as the input
        to Format-InAppProductSubmission for pretty-printing.

    .EXAMPLE
        Get-InAppProductSubmission 0ABCDEF12345 1234567890123456789 | Format-InAppProductSubmission

        Pipes the result of Get-InAppProductSubmission directly into Format-InAppProductSubmission for pretty-printing.
#>
    [CmdletBinding()]
    [Alias('Format-IapSubmission')]
    param(
        [Parameter(
            Mandatory,
            ValueFromPipeline)]
        [PSCustomObject] $IapSubmissionData
    )

    Begin
    {
        Set-TelemetryEvent -EventName Format-InAppProductSubmission

        Write-Log -Message "Displaying IAP Submission..." -Level Verbose

        $indentLength = 5
        $output = @()
    }

    Process
    {
        $output += ""
        $output += "Submission Id                       : $($IapSubmissionData.id)"
        $output += "Friendly Name                       : $($IapSubmissionData.friendlyName)"
        $output += "Content Type                        : $($IapSubmissionData.contentType)"
        $output += "Lifetime                            : $($IapSubmissionData.lifetime)"
        $output += "Tag                                 : {0}" -f $(if ([String]::IsNullOrEmpty($IapSubmissionData.tag)) { "<None>" } else { "$($IapSubmissionData.tag)" })
        $output += "Keywords                            : {0}" -f $(if ([String]::IsNullOrEmpty($IapSubmissionData.tag)) { "<None>" } else { "$($IapSubmissionData.keywords -join ', ')" })
        $output += ""

        $output += "Visibility                          : $($IapSubmissionData.visibility)"
        $output += "Publish Mode                        : $($IapSubmissionData.targetPublishMode)"
        if ($null -ne $IapSubmissionData.targetPublishDate)
        {
            $output += "Publish Date                        : $(Get-Date -Date $IapSubmissionData.targetPublishDate -Format R)"
        }

        $output += "File Upload Url                     : {0}" -f $(if ($IapSubmissionData.fileUploadUrl) { $IapSubmissionData.fileUploadUrl } else { "<None>" })
        $output += ""

        $output += "Pricing                             : $($IapSubmissionData.pricing.priceId)"

        $marketSpecificPricings = $IapSubmissionData.pricing.marketSpecificPricings
        if (($marketSpecificPricings | Get-Member -type NoteProperty).count -gt 0)
        {
            $output += "Market Specific Pricing             :"
            foreach ($market in ($marketSpecificPricings | Get-Member -type NoteProperty))
            {
                $marketName = $market.Name
                $output += "$(" " * $indentLength)${marketName}: $($marketSpecificPricings.$marketName)"
            }

            $output += ""
        }

        $sales = $IapSubmissionData.pricing.sales
        if ($sales.count -gt 0)
        {
            $output += "Sales                              :"
            foreach ($sale in $sales)
            {
                $output += "Name                                : $($sale.name)"
                $output += "Base Pricing                        : $($sale.basePriceId)"
                $output += "Start Date                          : $(Get-Date -Date $sale.startDate -Format R)"
                $output += "End Date                            : $(Get-Date -Date $sale.endDate -Format R)"

                $marketSpecificPricings = $sale.marketSpecificPricings
                if (($marketSpecificPricings | Get-Member -type NoteProperty).count -gt 0)
                {
                    $output += "Market Specific Pricing             :"
                    foreach ($market in ($marketSpecificPricings | Get-Member -type NoteProperty))
                    {
                        $marketName = $market.Name
                        $output += "$(" " * $indentLength * 2)${marketName}: $($marketSpecificPricings.$marketName)"
                    }

                    $output += ""
                }
            }
        }

        $output += "Listings                            : {0}" -f $(if ($IapSubmissionData.listings.count -eq 0) { "<None>" } else { "" })
        $listings = $IapSubmissionData.listings
        foreach ($listing in ($listings | Get-Member -type NoteProperty))
        {
            $lang = $listing.Name
            $output += ""
            $output += "$(" " * $indentLength)$lang"
            $output += "$(" " * $indentLength)----------"
            $output += "$(" " * $indentLength)Title               : $($listings.$lang.title)"
            $output += "$(" " * $indentLength)Description         : $($listings.$lang.description)"

            if ($null -ne $listings.$lang.icon)
            {
                $output += "$(" " * $indentLength)Icon         : $($listings.$lang.icon.FileName) | $($listings.$lang.icon.FileStatus)"
            }
        }

        $output += ""
        $output += "Status                                 : $($IapSubmissionData.status)"
        $output += "Status Details [Errors]                : {0}" -f $(if ($IapSubmissionData.statusDetails.errors.count -eq 0) { "<None>" } else { "" })
        $output += $IapSubmissionData.statusDetails.errors | Format-SimpleTableString -IndentationLevel $indentLength
        $output += ""

        $output += "Status Details [Warnings]              : {0}" -f $(if ($IapSubmissionData.statusDetails.warnings.count -eq 0) { "<None>" } else { "" })
        $output += $IapSubmissionData.statusDetails.warnings | Format-SimpleTableString -IndentationLevel $indentLength
        $output += ""

        $output += "Status Details [Certification Reports] : {0}" -f $(if ($IapSubmissionData.statusDetails.certificationReports.count -eq 0) { "<None>" } else { "" })
        foreach ($report in $IapSubmissionData.statusDetails.certificationReports)
        {
            $output += $(" " * $indentLength) + $(Get-Date -Date $report.date -Format R) + ": $($report.reportUrl)"
        }
    }

    End
    {
        Write-Log -Message $output
    }
}

function Get-InAppProductSubmissionStatus
{
<#
    .SYNOPSIS
        Retrieves just the status of a specific In-App Product submission.

    .DESCRIPTION
        Retrieves just the status of a specific In-App Product submission.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER IapId
        The ID for the In-App Product that you want to retrieve the information about.

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
        Get-InAppProductSubmissionStatus 0ABCDEF12345 01234567-89ab-cdef-0123-456789abcdef 1234567890123456789

        Gets just the status of this In-App Product's submission, with the console window showing
        progress while awaiting the response from the REST request.

    .EXAMPLE
        Get-InAppProductSubmissionStatus 0ABCDEF12345 01234567-89ab-cdef-0123-456789abcdef 1234567890123456789 -NoStatus

        Gets just the status of this In-App Product's submission, but the request happens in the
        foreground and there is no additional status shown to the user until a response is
        returned from the REST request.

    .EXAMPLE
        $submission = Get-InAppProductSubmissionStatus 0ABCDEF12345 1234567890123456789

        Retrieves just the status of this In-App Product's submission, and saves the results in
        a variable called $submission that can be used for further processing.
#>
    [CmdletBinding(SupportsShouldProcess)]
    [Alias('Get-IapSubmissionStatus')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="Methods called within here make use of PSShouldProcess, and the switch is passed on to them inherently.")]
    param(
        [Parameter(Mandatory)]
        [string] $IapId,

        [Parameter(Mandatory)]
        [string] $SubmissionId,

        [string] $AccessToken = "",

        [switch] $NoStatus
    )

    Write-Log -Message "[$($MyInvocation.MyCommand.Module.Version)] Executing: $($MyInvocation.Line.Trim())" -Level Verbose

    $telemetryProperties = @{
        [StoreBrokerTelemetryProperty]::IapId = $IapId
        [StoreBrokerTelemetryProperty]::SubmissionId = $SubmissionId
    }

    $params = @{
        "UriFragment" = "inappproducts/$IapId/submissions/$SubmissionId/status"
        "Method" = "Get"
        "Description" = "Getting status of SubmissionId: $SubmissionId for IapId: $IapId"
        "AccessToken" = $AccessToken
        "TelemetryEventName" = "Get-InAppProductSubmissionStatus"
        "TelemetryProperties" = $telemetryProperties
        "NoStatus" = $NoStatus
    }

    return (Invoke-SBRestMethod @params)
}

function Remove-InAppProductSubmission
{
    <#
    .SYNOPSIS
        Deletes the specified In-App Product submission from a developer account.

    .DESCRIPTION
        Deletes the specified In-App Product submission from a developer account.
        An IAP can only have a single "pending" submission at any given time,
        and submissions cannot be modified via the REST API once started.
        Therefore, before a new IAP submission can be submitted,
        this method must be called to remove any existing pending submission.

    .PARAMETER IapId
        The ID for the In-App Product that has the pending submission to be removed.

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
        Remove-InAppProductSubmission 0ABCDEF12345 1234567890123456789

        Removes the specified application In-App Product submission from the developer account,
        with the console window showing progress while awaiting the response
        from the REST request.

    .EXAMPLE
        Remove-InAppProductSubmission 0ABCDEF12345 1234567890123456789 -NoStatus

        Removes the specified In-App Product submission from the developer account,
        but the request happens in the foreground and there is no additional status
        shown to the user until a response is returned from the REST request.
#>
    [CmdletBinding(SupportsShouldProcess)]
    [Alias('Remove-IapSubmission')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="Methods called within here make use of PSShouldProcess, and the switch is passed on to them inherently.")]
    param(
        [Parameter(Mandatory)]
        [string] $IapId,

        [Parameter(Mandatory)]
        [string] $SubmissionId,

        [string] $AccessToken = "",

        [switch] $NoStatus
    )

    Write-Log -Message "[$($MyInvocation.MyCommand.Module.Version)] Executing: $($MyInvocation.Line.Trim())" -Level Verbose

    $telemetryProperties = @{
        [StoreBrokerTelemetryProperty]::IapId = $IapId
        [StoreBrokerTelemetryProperty]::SubmissionId = $SubmissionId
    }

    $params = @{
        "UriFragment" = "inappproducts/$IapId/submissions/$SubmissionId"
        "Method" = "Delete"
        "Description" = "Deleting submission: $SubmissionId for IAP: $IapId"
        "AccessToken" = $AccessToken
        "TelemetryEventName" = "Remove-InAppProductSubmission"
        "TelemetryProperties" = $telemetryProperties
        "NoStatus" = $NoStatus
    }

    $null = Invoke-SBRestMethod @params
}

function New-InAppProductSubmission
{
<#
    .SYNOPSIS
        Creates a submission for an existing In-App Product.

    .DESCRIPTION
        Creates a submission for an existing In-App Product.

        You cannot create a new In-App Product submission if there is an existing pending
        application submission for this IAP already.  You can use -Force to work around
        this.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER IapId
        The ID for the In-App Product that the new submission is for.

    .PARAMETER Force
        If this switch is specified, any existing pending submission for IapId
        will be removed before continuing with creation of the new submission.

    .PARAMETER AccessToken
        If provided, this will be used as the AccessToken for authentication with the
        REST Api as opposed to requesting a new one.

    .PARAMETER NoStatus
        If this switch is specified, long-running commands will run on the main thread
        with no commandline status update.  When not specified, those commands run in
        the background, enabling the command prompt to provide status information.

    .EXAMPLE
        New-InAppProductSubmission 0ABCDEF12345 -NoStatus

        Creates a new In-App Product submission for the IAP 0ABCDEF12345 that
        is an exact clone of the currently published submission, but the request happens
        in the foreground and there is no additional status shown to the user until a
        response is returned from the REST request.
        If successful, will return back the PSCustomObject representing the newly created
        In-App Product submission.

    .EXAMPLE
        New-InAppProductSubmission 0ABCDEF12345 -Force

        First checks for any existing pending submission for the IAP 0ABCDEF12345.
        If one is found, it will be removed.  After that check has completed, this will create
        a new submission that is an exact clone of the currently published submission,
        with the console window showing progress while awaiting the response from the REST request.
        If successful, will return back the PSCustomObject representing the newly created
        application submission.

    .OUTPUTS
        PSCustomObject representing the newly created application submission.
#>
    [CmdletBinding(SupportsShouldProcess)]
    [Alias('New-IapSubmission')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="Methods called within here make use of PSShouldProcess, and the switch is passed on to them inherently.")]
    param(
        [Parameter(Mandatory)]
        [string] $IapId,

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
        if ($Force)
        {
            Write-Log -Message "Force creation requested.  Ensuring that there is no existing pending submission." -Level Verbose

            $iap = Get-InAppProduct -IapId $IapId -AccessToken $AccessToken -NoStatus:$NoStatus
            $pendingSubmissionId = $iap.pendingInAppProductSubmission.id

            if ($null -ne $pendingSubmissionId)
            {
                Remove-InAppProductSubmission -IapId $IapId -SubmissionId $pendingSubmissionId -AccessToken $AccessToken -NoStatus:$NoStatus
            }
        }

        # Finally, we can POST with a null body to create a clone of the currently published submission
        $telemetryProperties = @{ [StoreBrokerTelemetryProperty]::IapId = $IapId }

        $params = @{
            "UriFragment" = "inappproducts/$IapId/submissions"
            "Method" = "Post"
            "Description" = "Cloning current submission for IAP: $IapId"
            "AccessToken" = $AccessToken
            "TelemetryEventName" = "New-InAppProductSubmission"
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

function Update-InAppProductSubmission
{
<#
    .SYNOPSIS
        Creates a new submission for an existing In-App Product on the developer account
        by cloning the existing submission and modifying specific parts of it.

    .DESCRIPTION
        Creates a new submission for an existing In-App Product on the developer account
        by cloning the existing submission and modifying specific parts of it. The
        parts that will be modified depend solely on the switches that are passed in.

        You cannot submit a new application submission if there is an existing pending
        application submission for this IAP already.  You can use -Force to work around
        this.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER IapId
        The ID for the In-App Product that the new submission is for.

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
        value from the previous submission.  Users should provide this in local time and it
        will be converted automatically to UTC.

    .PARAMETER TargetPublishDate
        Indicates when the submission will be published once it has passed certification.
        Specifying a value here is only valid when TargetPublishMode is set to 'SpecificDate'.
        The value specified here takes precendence over the value from SubmissionDataPath if
        -UpdatePublishModeAndVisibility is specified.  If -UpdatePublishModeAndVisibility
        is not specified and the value 'Default' is used, this submission will simply use the
        value from the previous submission.

    .PARAMETER Visibility
        Indicates the store visibility of the IAP once the submission has been published.
        The value specified here takes precendence over the value from SubmissionDataPath if
        -UpdatePublishModeAndVisibility is specified.  If -UpdatePublishModeAndVisibility
        is not specified and the value 'Default' is used, this submission will simply use the
        value from the previous submission.

    .PARAMETER AutoCommit
        If this switch is specified, will automatically commit the submission
        (which starts the certification process) once the Package has been uploaded
        (if PackagePath was specified), or immediately after the submission has been modified.

    .PARAMETER SubmissionId
        If a submissionId is provided, instead of trying to clone the currently published
        submission and operating against that clone, this will operate against an already
        existing pending submission (that was likely cloned previously).

    .PARAMETER Force
        If this switch is specified, any existing pending submission for IapId
        will be removed before continuing with creation of the new submission.

    .PARAMETER UpdateListings
        Replaces the listings array in the final, patched submission with the listings array
        from SubmissionDataPath.  Ensures that the images originally part of each listing in the
        cloned submission are marked as "PendingDelete" in the final, patched submission.

    .PARAMETER UpdatePublishModeAndVisibility
        Updates the following fields using values from SubmissionDataPath:
           targetPublishMode, targetPublishDate and visibility.

    .PARAMETER UpdatePricingAndAvailability
        Updates the following fields using values from SubmissionDataPath:
            base pricing, market-specific pricing and sales pricing information.

    .PARAMETER UpdateProperties
        Updates the following fields using values from SubmissionDataPath:
            product lifetime, content type, keywords, tag

    .PARAMETER AccessToken
        If provided, this will be used as the AccessToken for authentication with the
        REST Api as opposed to requesting a new one.

    .PARAMETER NoStatus
        If this switch is specified, long-running commands will run on the main thread
        with no commandline status update.  When not specified, those commands run in
        the background, enabling the command prompt to provide status information.

    .EXAMPLE
        Update-InAppProductSubmission 0ABCDEF12345 "c:\foo.json"

        Creates a new submission for the In-App Product 0ABCDEF12345, that is a clone of
        the currently published submission.
        Even though "c:\foo.json" was provided, because no switches were specified to indicate
        what to copy from it, the cloned submission was not further modified, and is thus still
        an exact copy of the currently published submission.
        If successful, will return back the pending submission id and url that should be
        used with Upload-SubmissionPackage.

    .EXAMPLE
        Update-InAppProductSubmission 0ABCDEF12345 "c:\foo.json" -UpdateProperties -NoStatus

        Creates a new submission for the In-App Product 0ABCDEF12345, that is a clone of
        the currently published submission.
        The properties of the submission will be updated to match those defined in c:\foo.json.
        The request happens in the foreground and there is no additional status shown to the user
        until a response is returned from the REST request.
        If successful, will return back the pending submission id and url that
        should be used with Upload-SubmissionPackage.

    .EXAMPLE
        Update-InAppProductSubmission 0ABCDEF12345 "c:\foo.json" "c:\foo.zip" -AutoCommit -SubmissionId 1234567890123456789 -UpdateListings

        Retrieves submission 1234567890123456789 from the IAP  0ABCDEF12345, updates the mestadata
        listing to match those in c:\foo.json.  If successful, this then attempts to upload "c:\foo.zip"
        (which would contain the listing icons).  If that is also successful, it then goes ahead and
        commits the submission so that the certification process can start. The pending
        submissionid and url that were used with with Upload-SubmissionPackage
        are still returned in this scenario, even though the upload url can no longer actively be used.

    .OUTPUTS
        An array of the following two objects:
            System.String - The id for the new pending submission
            System.String - The URL that the package needs to be uploaded to.
#>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([Object[]])]
    [Alias('Update-IapSubmission')]
    param(
        [Parameter(Mandatory)]
        [string] $IapId,

        [Parameter(Mandatory)]
        [ValidateScript({if (Test-Path -Path $_ -PathType Leaf) { $true } else { throw "$_ cannot be found." }})]
        [string] $SubmissionDataPath,

        [ValidateScript({if (Test-Path -Path $_ -PathType Leaf) { $true } else { throw "$_ cannot be found." }})]
        [string] $PackagePath = $null,

        [ValidateSet('Default', 'Immediate', 'Manual', 'SpecificDate')]
        [string] $TargetPublishMode = $script:keywordDefault,

        [DateTime] $TargetPublishDate,

        [ValidateSet('Default', 'Public', 'Private', 'Hidden')]
        [string] $Visibility = $script:keywordDefault,

        [switch] $AutoCommit,

        [string] $SubmissionId = "",

        [ValidateScript({if ([System.String]::IsNullOrEmpty($SubmissionId) -or !$_) { $true } else { throw "Can't use -Force and supply a SubmissionId." }})]
        [switch] $Force,

        [switch] $UpdateListings,

        [switch] $UpdatePublishModeAndVisibility,

        [switch] $UpdatePricingAndAvailability,

        [switch] $UpdateProperties,

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

    # Extra layer of validation to protect users from trying to submit a payload to the wrong IAP
    if ([String]::IsNullOrWhiteSpace($submission.iapId))
    {
        $configPath = Join-Path -Path ([System.Environment]::GetFolderPath('Desktop')) -ChildPath 'newconfig.json'

        Write-Log -Level Warning -Message @(
            "The config file used to generate this submission did not have an IapId defined in it.",
            "The IapId entry in the config helps ensure that payloads are not submitted to the wrong In-App Product.",
            "Please update your app's StoreBroker config file by adding an `"iapId`" property with",
            "your IAP's IapId to the `"iapSubmission`" section.  If you're unclear on what change",
            "needs to be done, you can re-generate your config file using",
            "   New-StoreBrokerInAppProductConfigFile -IapId $IapId -Path `"$configPath`"",
            "and then diff the new config file against your current one to see the requested iapId change.")
    }
    else
    {
        if ($IapId -ne $submission.iapId)
        {
            $output = @()
            $output += "The IapId [$($submission.iapId)] in the submission content [$SubmissionDataPath] does not match the intended IapId [$IapId]."
            $output += "You either entered the wrong IapId at the commandline, or you're referencing the wrong submission content to upload."

            $newLineOutput = ($output -join [Environment]::NewLine)
            Write-Log -Message $newLineOutput -Level Error
            throw $newLineOutput
        }
    }

    Remove-UnofficialSubmissionProperties -Submission $submission

    # Identify potentially incorrect usage of this method by checking to see if no modification
    # switch was provided by the user
    if ((-not $UpdateListings) -and
        (-not $UpdatePublishModeAndVisibility) -and
        (-not $UpdatePricingAndAvailability) -and
        (-not $UpdateProperties))
    {
        Write-Log -Level Warning -Message @(
            "You have not specified any `"modification`" switch for updating the submission.",
            "This means that the new submission will be identical to the current one.",
            "If this was not your intention, please read-up on the documentation for this command:",
            "     Get-Help Update-InAppProductSubmission -ShowWindow")
    }

    if ([System.String]::IsNullOrEmpty($AccessToken))
    {
        $AccessToken = Get-AccessToken -NoStatus:$NoStatus
    }

    try
    {
        if ([System.String]::IsNullOrEmpty($SubmissionId))
        {
            $submissionToUpdate = New-InAppProductSubmission -IapId $IapId -Force:$Force -AccessToken $AccessToken -NoStatus:$NoStatus
        }
        else
        {
            $submissionToUpdate = Get-InAppProductSubmission -IapId $IapId -SubmissionId $SubmissionId -AccessToken $AccessToken -NoStatus:$NoStatus
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

        if ($PSCmdlet.ShouldProcess("Patch-InAppProductSubmission"))
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
            $params.Add("UpdateProperties", $UpdateProperties)

            $patchedSubmission = Patch-InAppProductSubmission @params
        }

        if ($PSCmdlet.ShouldProcess("Set-InAppProductSubmission"))
        {
            $params = @{}
            $params.Add("IapId", $IapId)
            $params.Add("UpdatedSubmission", $patchedSubmission)
            $params.Add("AccessToken", $AccessToken)
            $params.Add("NoStatus", $NoStatus)
            $replacedSubmission = Set-InAppProductSubmission @params
        }

        $submissionId = $replacedSubmission.id
        $uploadUrl = $replacedSubmission.fileUploadUrl

        Write-Log -Message @(
            "Successfully cloned the existing submission and modified its content.",
            "You can view it on the Dev Portal here:",
            "    https://dev.windows.com/en-us/dashboard/iaps/$IapId/submissions/$submissionId/",
            "or by running this command:",
            "    Get-InAppProductSubmission -IapId $IapId -SubmissionId $submissionId | Format-InAppProductSubmission",
            "",
            ($script:manualPublishWarning -f 'Update-InAppProductSubmission'))

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
                # into Complete-InAppProductSubmission ... so, we'll send in a $null value and
                # let it acquire a new one.
                $AccessToken = $null
            }

            Write-Log -Message "Commiting the submission since -AutoCommit was requested." -Level Verbose
            Complete-InAppProductSubmission -IapId $IapId -SubmissionId $submissionId -AccessToken $AccessToken -NoStatus:$NoStatus
        }
        else
        {
            Write-Log -Message @(
                "When you're ready to commit, run this command:",
                "  Commit-InAppProductSubmission -IapId $IapId -SubmissionId $submissionId")
        }

        # Record the telemetry for this event.
        $stopwatch.Stop()
        $telemetryMetrics = @{ [StoreBrokerTelemetryMetric]::Duration = $stopwatch.Elapsed.TotalSeconds }
        $telemetryProperties = @{
            [StoreBrokerTelemetryProperty]::IapId = $IapId
            [StoreBrokerTelemetryProperty]::SubmissionId = $SubmissionId
            [StoreBrokerTelemetryProperty]::PackagePath = (Get-PiiSafeString -PlainText $PackagePath)
            [StoreBrokerTelemetryProperty]::AutoCommit = $AutoCommit
            [StoreBrokerTelemetryProperty]::Force = $Force
            [StoreBrokerTelemetryProperty]::UpdateListings = $UpdateListings
            [StoreBrokerTelemetryProperty]::UpdatePublishModeAndVisibility = $UpdatePublishModeAndVisibility
            [StoreBrokerTelemetryProperty]::UpdatePricingAndAvailability = $UpdatePricingAndAvailability
            [StoreBrokerTelemetryProperty]::UpdateProperties = $UpdateProperties
        }

        Set-TelemetryEvent -EventName Update-InAppProductSubmission -Properties $telemetryProperties -Metrics $telemetryMetrics

        return $submissionId, $uploadUrl
    }
    catch
    {
        Write-Log -Exception $_ -Level Error
        throw
    }
}

function Patch-InAppProductSubmission
{
<#
    .SYNOPSIS
        Modifies a cloned In-App Product submission by copying the specified data from the
        provided "new" submission.  Returns the final, patched submission JSON.

    .DESCRIPTION
        Modifies a cloned In-App Product submission by copying the specified data from the
        provided "new" submission.  Returns the final, patched submission JSON.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER ClonedSubmisson
        The JSON that was returned by the Store API when the IAP submission was cloned.

    .PARAMETER NewSubmission
        The JSON for the new/updated application IAP submission.  The only parts from this
        submission that will be copied to the final, patched submission will be those specified
        by the switches.

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
        Indicates the store visibility of the IAP once the submission has been published.
        The value specified here takes precendence over the value from NewSubmission if
        -UpdatePublishModeAndVisibility is specified.  If -UpdatePublishModeAndVisibility
        is not specified and the value 'Default' is used, this submission will simply use the
        value from the previous submission.

    .PARAMETER UpdateListings
        Replaces the listings array in the final, patched submission with the listings array
        from NewSubmission.  Ensures that the images originally part of each listing in the
        cloned submission are marked as "PendingDelete" in the final, patched submission.

    .PARAMETER UpdatePublishModeAndVisibility
        Updates the following fields using values from NewSubmission:
           targetPublishMode, targetPublishDate and visibility.

    .PARAMETER UpdatePricingAndAvailability
        Updates the following fields using values from NewSubmission:
            base pricing, market-specific pricing and sales pricing information.

    .PARAMETER UpdateProperties
        Updates the following fields using values from NewSubmission:
            product lifetime, content type, keywords, tag

    .EXAMPLE
        $patchedSubmission = Patch-InAppProductSubmission $clonedSubmission $jsonContent

        Because no switches were specified, ($patchedSubmission -eq $clonedSubmission).

    .EXAMPLE
        $patchedSubmission = Patch-InAppProductSubmission $clonedSubmission $jsonContent -UpdateListings

        $patchedSubmission will be identical to $clonedSubmission, however all of the listings
        metadata will be replaced with that which is specified in $jsonContent.

    .EXAMPLE
        $patchedSubmission = Patch-InAppProductSubmission $clonedSubmission $jsonContent -UpdateProperties -UpdatePublishModeAndVisibility

        $patchedSubmission will be contain the updated properties and publish mode/date/visibility
        settings that were part of $jsonContent, but the rest of the submission content will be identical
        to what had been in $clonedSubmission.

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

        [ValidateSet('Default', 'Public', 'Private', 'Hidden')]
        [string] $Visibility = $script:keywordDefault,

        [switch] $UpdateListings,

        [switch] $UpdatePublishModeAndVisibility,

        [switch] $UpdatePricingAndAvailability,

        [switch] $UpdateProperties
    )

    Write-Log -Message "Patching the content of the submission." -Level Verbose

    # Our method should have zero side-effects -- we don't want to modify any parameter
    # that was passed-in to us.  To that end, we'll create a deep copy of the ClonedSubmisison,
    # and we'll modify that throughout this function and that will be the value that we return
    # at the end.
    $PatchedSubmission = DeepCopy-Object $ClonedSubmission

    # When updating the listings metadata, what we really want to do is just blindly replace
    # the existing listings array with the new one.  We can't do that unfortunately though,
    # as we need to mark the existing icons as "PendingDelete" so that they'll be deleted
    # during the upload, but only if the new listing doesn't have a new icon.
    # Otherwise, even though we don't include them in the updated JSON, they will still remain
    # there in the Dev Portal which is not the desired behavior.
    if ($UpdateListings)
    {
        # Save off the original listings so that we can make changes to them without affecting
        # other references
        $existingListings = DeepCopy-Object $PatchedSubmission.listings

        # Then we'll replace the patched submission's listings array (which had the old,
        # cloned metadata), with the metadata from the new submission.
        $PatchedSubmission.listings = DeepCopy-Object $NewSubmission.listings

        # Now, we'll go through and if a region previously had an icon but no longer does
        # in the new listing, we'll copy it over and mark it as PendingDelete so that it's
        # removed.  We only have to do this if we're not replacing it with a new icon.
        #
        # Unless the Store team indicates otherwise, we assume that the server will handle
        # deleting the images in regions that were part of the cloned submission, but aren't part
        # of the patched submission that we provide. Otherwise, we'd have to create empty listing
        # objects that would likely fail validation.
        $existingListings |
            Get-Member -type NoteProperty |
                ForEach-Object {
                    $lang = $_.Name
                    if (($null -ne $existingListings.$lang.icon) -and ($null -eq $PatchedSubmission.listings.$lang.icon))
                    {
                        $existingListings.$lang.icon.FileStatus = $script:keywordPendingDelete
                        $PatchedSubmission.listings.$lang |
                            Add-Member -Type NoteProperty -Name "Icon" -Value $($existingListings.$lang.icon)
                    }
                }
    }

    # For the remaining switches, simply copy the field if it is a scalar, or
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
    }

    if ($UpdateProperties)
    {
        $PatchedSubmission.contentType = $NewSubmission.contentType
        $PatchedSubmission.keywords = DeepCopy-Object $NewSubmission.keywords
        $PatchedSubmission.lifetime = $NewSubmission.lifetime
        $PatchedSubmission.tag = $NewSubmission.tag
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

function Set-InAppProductSubmission
{
<#
    .SYNOPSIS
        Replaces the content of an existing In-App Product submission with the supplied
        submission content.

    .DESCRIPTION
        Replaces the content of an existing In-App Product submission with the supplied
        submission content.

        This should be called after having cloned an In-App Product submission via
        New-InAppProductSubmission.

        The ID of the submission being updated/replaced will be inferred by the
        ID's defined in UpdatedSubmission.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER IapId
        The ID for the In-App Product that the submission is for.

    .PARAMETER UpdatedSubmission
        The updated IAP submission content that should be used to replace the
        existing submission content.  The Submission ID will be determined from this.

    .PARAMETER AccessToken
        If provided, this will be used as the AccessToken for authentication with the
        REST Api as opposed to requesting a new one.

    .PARAMETER NoStatus
        If this switch is specified, long-running commands will run on the main thread
        with no commandline status update.  When not specified, those commands run in
        the background, enabling the command prompt to provide status information.

    .EXAMPLE
        Set-InAppProductSubmission 0ABCDEF12345 $submissionBody

        Inspects $submissionBody to retrieve the id of the submission in question, and then replaces
        the entire content of that existing submission with the content specified in $submissionBody.

    .EXAMPLE
        Set-InAppProductSubmission 0ABCDEF12345 $submissionBody -NoStatus

        Inspects $submissionBody to retrieve the id of the submission in question, and then replaces
        the entire content of that existing submission with the content specified in $submissionBody.
        The request happens in the foreground and there is no additional status shown to the user
        until a response is returned from the REST request.

    .OUTPUTS
        A PSCustomObject containing the JSON of the updated application submission.
#>
    [CmdletBinding(SupportsShouldProcess)]
    [Alias('Replace-InAppProductSubmission')]
    [Alias('Replace-IapSubmission')]
    [Alias('Set-IapSubmission')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="Methods called within here make use of PSShouldProcess, and the switch is passed on to them inherently.")]
    param(
        [Parameter(Mandatory)]
        [string] $IapId,

        [Parameter(Mandatory)]
        [PSCustomObject] $UpdatedSubmission,

        [string] $AccessToken = "",

        [switch] $NoStatus
    )

    Write-Log -Message "[$($MyInvocation.MyCommand.Module.Version)] Executing: $($MyInvocation.Line.Trim())" -Level Verbose

    $submissionId = $UpdatedSubmission.id
    $body = [string]($UpdatedSubmission | ConvertTo-Json -Depth $script:jsonConversionDepth)

    $telemetryProperties = @{ [StoreBrokerTelemetryProperty]::IapId = $IapId }

    $params = @{
        "UriFragment" = "inappproducts/$IapId/submissions/$submissionId"
        "Method" = "Put"
        "Description" = "Replacing the content of Submission: $submissionId for IAP: $IapId"
        "Body" = $body
        "AccessToken" = $AccessToken
        "TelemetryEventName" = "Set-InAppProductSubmission"
        "TelemetryProperties" = $telemetryProperties
        "NoStatus" = $NoStatus
    }

    return (Invoke-SBRestMethod @params)
}

function Complete-InAppProductSubmission
{
<#
    .SYNOPSIS
        Commits the specified In-App Product submission so that it can start the approval process.

    .DESCRIPTION
        Commits the specified In-App Product submission so that it can start the approval process.
        Once committed, it is necessary to wait for the submission to either complete or fail
        the approval process before a new IAP submission can be created/submitted.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER IapId
        The ID for the In-App Product that has the pending submission to be submitted.

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
        Commit-InAppProductSubmission 0ABCDEF12345 1234567890123456789

        Marks the pending submission 1234567890123456789 to start the approval process
        for publication, with the console window showing progress while awaiting
        the response from the REST request.

    .EXAMPLE
        Commit-InAppProductSubmission 0ABCDEF12345 1234567890123456789 -NoStatus

        Marks the pending submission 1234567890123456789 to start the approval process
        for publication, but the request happens in the foreground and there is no
        additional status shown to the user until a response is returned from the REST
        request.

    .NOTES
        This uses the "Complete" verb to avoid Powershell import module warnings, but this
        actually only *commits* the submission.  The decision to publish or not is based
        entirely on the contents of the payload included when calling New-InAppProductSubmission.
#>
    [CmdletBinding(SupportsShouldProcess)]
    [Alias('Complete-IapSubmission')]
    [Alias('Commit-InAppProductSubmission')]
    [Alias('Commit-IapSubmission')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="Methods called within here make use of PSShouldProcess, and the switch is passed on to them inherently.")]
    param(
        [Parameter(Mandatory)]
        [string] $IapId,

        [Parameter(Mandatory)]
        [string] $SubmissionId,

        [string] $AccessToken = "",

        [switch] $NoStatus
    )

    Write-Log -Message "[$($MyInvocation.MyCommand.Module.Version)] Executing: $($MyInvocation.Line.Trim())" -Level Verbose

    try
    {
        $telemetryProperties = @{
            [StoreBrokerTelemetryProperty]::IapId = $IapId
            [StoreBrokerTelemetryProperty]::SubmissionId = $SubmissionId
        }

        $params = @{
            "UriFragment" = "inappproducts/$IapId/submissions/$SubmissionId/Commit"
            "Method" = "Post"
            "Description" = "Committing submission $SubmissionId for IAP: $IapId"
            "AccessToken" = $AccessToken
            "TelemetryEventName" = "Complete-InAppProductSubmission"
            "TelemetryProperties" = $telemetryProperties
            "NoStatus" = $NoStatus
        }

        $null = Invoke-SBRestMethod @params

        Write-Log -Message @(
            "The submission has been successfully committed.",
            "This is just the beginning though.",
            "It still has multiple phases of validation to get through, and there's no telling how long that might take.",
            "You can view the progress of the submission validation on the Dev Portal here:",
            "    https://dev.windows.com/en-us/dashboard/iaps/$IapId/submissions/$submissionId/",
            "or by running this command:",
            "    Get-InAppProductSubmission -IapId $IapId -SubmissionId $submissionId | Format-InAppProductSubmission",
            "You can automatically monitor this submission with this command:",
            "    Start-InAppProductSubmissionMonitor -IapId $IapId -SubmissionId $submissionId -EmailNotifyTo $env:username",
            "",
            ($script:manualPublishWarning -f 'Update-InAppProductSubmission'))
    }
    catch [System.InvalidOperationException]
    {
        throw
    }
}

function Start-InAppProductSubmissionMonitor
{
<#
    .SYNOPSIS
        Auto-checks an In-App Product submission for status changes every 60 seconds with optional
        email notification.

    .DESCRIPTION
        Auto-checks an In-App Product submission for status changes every 60 seconds with optional
        email notification.

        The monitoring will automatically end if the submission enters a failed state, or once
        its state enters the final state that its targetPublishMode allows for.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER IapId
        The ID for the In-App Product that has the committed submission.

    .PARAMETER SubmissionId
        The ID of the submission that should be monitored.

    .PARAMETER EmailNotifyTo
        A list of email addresses that should be emailed every time that status changes for
        this submission.

    .PARAMETER NoStatus
        If this switch is specified, long-running commands will run on the main thread
        with no commandline status update.  When not specified, those commands run in
        the background, enabling the command prompt to provide status information.

    .PARAMETER PassThru
        Returns the final submission object that was retrieved when checking submission
        status.  By default, this function does not generate any output.

    .OUTPUTS
       None or PSCustomObject
       By default, this does not generate any output. If you use the PassThru parameter,
       it generates a PSCustomObject object that represents the last retrieved submission
       which can be inspected for submission status.

    .EXAMPLE
        Start-InAppProductSubmissionMonitor 0ABCDEF12345 1234567890123456789

        Checks that submission every 60 seconds until the submission enters a Failed state
        or reaches the final state that it can reach given its current targetPublishMode.

    .EXAMPLE
        Start-InAppProductSubmissionMonitor 0ABCDEF12345 1234567890123456789 user@foo.com

        Checks that submission every 60 seconds until the submission enters a Failed state
        or reaches the final state that it can reach given its current targetPublishMode.
        Will email user@foo.com every time this status changes as well.

    .NOTES
        This is a pure proxy for Start-ApplicationSubmissionMonitor.  The only benefit that
        it provides is that it makes IapId a required parameter and puts it positionally in
        the appropriate place.  We can't accomplish that with normal parameter sets since all the
        parameters are strings and thus can't be differentiated.
#>
    [CmdletBinding(SupportsShouldProcess)]
    [Alias('Start-IapSubmissionMonitor')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="Methods called within here make use of PSShouldProcess, and the switch is passed on to them inherently.")]
    param(
        [Parameter(Mandatory)]
        [string] $IapId,

        [Parameter(Mandatory)]
        [string] $SubmissionId,

        [string[]] $EmailNotifyTo = @(),

        [switch] $NoStatus,

        [switch] $PassThru
    )

    Start-SubmissionMonitor @PSBoundParameters
}
