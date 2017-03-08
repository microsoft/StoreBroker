# Copyright (C) Microsoft Corporation.  All rights reserved.

# Configured via Set-StoreBrokerAuthentication / Clear-StoreBrokerAuthentication
$script:proxyEndpoint = $null

# We are defining these as script variables here to enable the caching of the
# authentication credential for the current PowerShell session.
[string]$script:authTenantId = $null
[PSCredential]$script:authCredential = $null
[string]$script:authTenantName = $null

# By default, ConvertTo-Json won't expand nested objects further than a depth of 2
# We always want to expand as deep as possible, so set this to a much higher depth
# than the actual depth
$script:jsonConversionDepth = 20

# The number of seconds that we'll buffer from the expected AccessToken expiration
# to allow for time lost during network communication.
$script:accessTokenRefreshBufferSeconds = 90

# The number of seconds that we'll allow to pass before assuming that the AccessToken
# has expired and needs to be refreshed.  We'll update this value whenever we really
# do get an AccessToken so that it accurately reflects the time a token can last.
$script:accessTokenTimeoutSeconds = (59 * 60) - $script:accessTokenRefreshBufferSeconds

# Common keywords in the API Model used by StoreBroker
$script:keywordSpecificDate = 'SpecificDate'
$script:keywordManual = 'Manual'
$script:keywordDefault = 'Default'
$script:keywordNoAction = 'NoAction'
$script:keywordPendingDelete = 'PendingDelete'
$script:keywordPendingCommit = 'PendingCommit'
$script:keywordRelease = 'Release'
$script:keywordPublished = 'Published'

# Special header added to Submission API responses that provides a unique ID
# that the Submission API team can use to trace back problems with a specific request.
$script:headerMSCorrelationId = 'MS-CorrelationId'

# Warning that is referenced in multiple places throughout the module.
# {0} will be replaced in context with the relevant command.
$script:manualPublishWarning = @"
PLEASE NOTE: Due to the nature of how the Store API works, you won't see any of your changes in the
Dev Portal until your submission has entered into certification.  It doesn't have to *complete*
certification for you to see your changes, but it does have to enter certification first.
If it's important for you to verify your changes in the Dev Portal prior to publishing,
consider publishing with the `"$script:keywordManual`" targetPublishMode by setting that value in your
config file and then additionally specifying the -UpdatePublishModeAndVisibility switch
when calling {0}, or by specifying the
-TargetPublishMode $script:keywordManual parameter when calling {0}.
"@

function Initialize-StoreIngestionApiGlobalVariables
{
<#
    .SYNOPSIS
        Initializes the global variables that are "owned" by the StoreIngestionApi script file.

    .DESCRIPTION
        Initializes the global variables that are "owned" by the StoreIngestionApi script file.
        Global variables are used sparingly to enables users a way to control certain extensibility
        points with this module.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .NOTES
        Internal-only helper method.
    
        The only reason this exists is so that we can leverage CodeAnalysis.SuppressMessageAttribute,
        which can only be applied to functions.  Otherwise, we would have just had the relevant
        initialization code directly above the function that references the variable.

        We call this immediately after the declaration so that the variables are available for
        reference in any function below.

#>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidGlobalVars", "", Justification="We use global variables sparingly and intentionally for module configuration, and employ a consistent naming convention.")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "", Justification="This is where we would initialize any global variables for this script.")]
    param()

    # We only set their values if they don't already have values defined.
    # We use -ErrorAction SilentlyContinue during the Get-Variable check since it throws an exception
    # by default if the variable we're getting doesn't exist, and we just want the bool result.
    if (!(Get-Variable -Name SBDefaultProxyEndpoint -Scope Global -ValueOnly -ErrorAction SilentlyContinue))
    {
        $global:SBDefaultProxyEndpoint = $null
    }
}

# We need to be sure to call this explicitly so that the global variables get initialized.
Initialize-StoreIngestionApiGlobalVariables

function Set-StoreBrokerAuthentication
{
<#
    .SYNOPSIS
        Prompts the user for their client id and secret so that they can be cached for
        this PowerShell session to avoid repeated prompts.

    .DESCRIPTION
        Prompts the user for their client id and secret so that they can be cached for
        this PowerShell session to avoid repeated prompts.
        The cached credential can always be cleared by calling Clear-StoreBrokerAuthentication.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER TenantId
        The Azure Active Directory Tenant ID that authentication must go through.

    .PARAMETER Credential
        Optional parameter that allows you to pass-in the credential object to be used, as
        opposed to having this command pop-up a UI for the user to manually enter in
        their credentials.

    .PARAMETER OnlyCacheTenantId
        Normally, calling this cmdlet will result in an authentication prompt to retrieve
        the clientId and clientSecret needed for authentication (unless Credential is provided).
        If this switch is specified that prompt will be suppressed so that all that will occur
        is the caching of the TenantId. This will not cause previously cached credentials to
        be cleared however (to do that, use Clear-StoreBrokerAuthentication)

    .PARAMETER UseProxy
        If specified, authentication will occur via a proxy server as opposed to authenticating
        with a standard TenantId/ClientId/ClientSecret combination.  Users have the option of
        additionally specifying a value for ProxyEndpoint if they wish to use a non-default
        proxy server.

    .PARAMETER ProxyEndpoint
        The REST endpoint that will be used to authenticate user requests and then proxy those
        requests to the real Store REST API endpoint.

    .PARAMETER TenantName
        The friendly name for the tenant that can be used with a Proxy that supports multiple
        tenants.

    .EXAMPLE
        Set-StoreBrokerAuthentication "abcdef01-2345-6789-0abc-def123456789"

        Caches the tenantId as "abcdef01-2345-6789-0abc-def123456789" for the duration of the
        PowerShell session.  Prompts the user for the client id and secret.
        These values will be cached for the duration of this PowerShell session.
        They can be cleared by calling Clear-StoreBrokerAuthentication.

    .EXAMPLE
        Set-StoreBrokerAuthentication "abcdef01-2345-6789-0abc-def123456789" $cred

        Caches the provided tenantId and credential without any prompting to the user.
        This is helpful when you want to run the script without any user interaction.
        These values will be cached for the duration of this PowerShell session.
        They can be cleared by calling Clear-StoreBrokerAuthentication.
        For assistance in learning how to manually create $cred, refer to:
        https://technet.microsoft.com/en-us/magazine/ff714574.aspx

    .EXAMPLE
        Set-StoreBrokerAuthentication "abcdef01-2345-6789-0abc-def123456789" -OnlyCacheTenantId

        Caches the tenantId as "abcdef01-2345-6789-0abc-def123456789" for the duration of the
        PowerShell session, but does not prompt the user to enter the clientId/clientSecret
        credential values.

    .EXAMPLE
        Set-StoreBrokerAuthentication -UseProxy

        Bypasses normal authentication and tells StoreBroker to use the dafault proxy server
        endpoint for authentication instead.
#>
    [CmdletBinding(
        SupportsShouldProcess,
        DefaultParametersetName="NoCred")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidGlobalVars", "", Justification="We use global variables sparingly and intentionally for module configuration, and employ a consistent naming convention.")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUsePSCredentialType", "", Justification="The System.Management.Automation.Credential() attribute does not appear to work in PowerShell v4 which we need to support.")]
    param(
        [Parameter(
            Mandatory,
            ParameterSetName="NoCred",
            Position=0)]
        [Parameter(
            Mandatory,
            ParameterSetName="WithCred",
            Position=0)]
        [Parameter(
            ParameterSetName="Proxy",
            Position=2)]
        [string] $TenantId,

        [Parameter(
            ParameterSetName="WithCred",
            Position=1)]
        [PSCredential] $Credential = $null,

        [Parameter(ParameterSetName="NoCred")]
        [switch] $OnlyCacheTenantId,

        [Parameter(
            Mandatory,
            ParameterSetName="Proxy",
            Position=0)]
        [switch] $UseProxy,

        [Parameter(
            ParameterSetName="Proxy",
            Position=1)]
        [string] $ProxyEndpoint = $global:SBDefaultProxyEndpoint,

        [Parameter(
            ParameterSetName="Proxy",
            Position=2)]
        [string] $TenantName = $null
    )

    Write-Log "Executing: $($MyInvocation.Line)" -Level Verbose

    if ($UseProxy)
    {
        if ((-not [String]::IsNullOrWhiteSpace($TenantId)) -and (-not [String]::IsNullOrWhiteSpace($TenantName)))
        {
            $message = "You cannot set both TenantId and TenantName.  Only provide one of them."
            Write-Log $message -Level Error
            throw $message
        }

        if ($null -ne $script:authCredential)
        {
            Write-Log "Your cached credentials will no longer be used since you have enabled Proxy usage." -Level Warning
        }

        if ($ProxyEndpoint.EndsWith('/') -or $ProxyEndpoint.EndsWith('\'))
        {
            $ProxyEndpoint = $ProxyEndpoint.Substring(0, $ProxyEndpoint.Length - 1)
        }

        $script:proxyEndpoint = $ProxyEndpoint

        if ((-not [String]::IsNullOrWhiteSpace($TenantId)) -and
            $PSCmdlet.ShouldProcess($TenantId, "Cache tenantId"))
        {
            $script:authTenantId = $TenantId
            $script:authTenantName = $null
        }

        if ((-not [String]::IsNullOrWhiteSpace($TenantName)) -and
            $PSCmdlet.ShouldProcess($TenantName, "Cache tenantName"))
        {
            $script:authTenantId = $null
            $script:authTenantName = $TenantName
        }

        return
    }

    if ($PSCmdlet.ShouldProcess($TenantId, "Cache tenantId"))
    {
        $script:authTenantId = $TenantId
        $script:authTenantName = $null
    }

    # By calling into here with any other parameter set, the user is indicating that the proxy
    # should no longer be used, so we must clear out any existing value.
    $script:proxyEndpoint = $null

    if (($null -eq $Credential) -and (-not $OnlyCacheTenantId))
    {
        if ($PSCmdlet.ShouldProcess("", "Get-Credential"))
        {
            $Credential = Get-Credential -Message "Enter your client id as your username, and your client secret as your password. ***These values are being cached.  Use Clear-StoreBrokerAuthentication or close this PowerShell window when you are done.***"
        }
    }

    if ($null -eq $Credential)
    {
        if (-not $OnlyCacheTenantId)
        {
            Write-Log "No credential provided.  Not changing current cached credential." -Level Error
        }
    }
    else
    {
        if ($PSCmdlet.ShouldProcess($Credential, "Cache credential"))
        {
            $script:authCredential = $Credential
        }
    }
}

function Clear-StoreBrokerAuthentication
{
<#
    .SYNOPSIS
        Clears out any cached tenantId, client id, and client secret credential from this PowerShell session.
        Also disables usage of the proxy server if that had been previously enabled.
        All future remote commands from this module will once again prompt for credentials.

    .DESCRIPTION
        Clears out any cached tenantId, client id, and client secret credential from this PowerShell session.
        Also disables usage of the proxy server if that had been previously enabled.
        All future remote commands from this module will once again prompt for credentials.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .EXAMPLE
        Clear-StoreBrokerAuthentication

        Clears out any cached tenantId, client id, and client secret credential from this PowerShell session.
        Also disables usage of the proxy server if that had been previously enabled.
        All future remote commands from this module will once again prompt for credentials.
#>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Set-TelemetryEvent -EventName Clear-StoreBrokerAuthentication

    Write-Log "Executing: $($MyInvocation.Line)" -Level Verbose

    if ($PSCmdlet.ShouldProcess("", "Clear tenantId"))
    {
        $script:authTenantId = $null
    }

    if ($PSCmdlet.ShouldProcess("", "Clear credential"))
    {
        $script:authCredential = $null
    }

    if ($PSCmdlet.ShouldProcess("", "Clear proxy"))
    {
        $script:proxyEndpoint = $null
    }

    if ($PSCmdlet.ShouldProcess("", "Clear tenantName"))
    {
        $script:tenantName = $null
    }
}

function Get-AccessToken
{
<#
    .SYNOPSIS
        Gets an access token that can be used with the Windows Store Submission API REST requests.

    .DESCRIPTION
        Gets an access token that can be used with the Windows Store Submission API REST requests.
        This token will only be valid for ONE HOUR.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER NoStatus
        If this switch is specified, long-running commands will run on the main thread
        with no commandline status update.  When not specified, those commands run in
        the background, enabling the command prompt to provide status information.

    .EXAMPLE
        $token = Get-AccessToken
        Retrieves the access token that can be used in a future REST request header.

    .OUTPUTS
        System.String
    
    .NOTES
        The access token will only be valid for ONE HOUR.
#>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([String])]
    param(
        [switch] $NoStatus
    )

    # If we have a value for the proxy endpoint, that means we're using the proxy.
    # In that scenario, we don't need to do any work here.
    if (-not [String]::IsNullOrEmpty($script:proxyEndpoint))
    {
        # We can technically use any string in this scenario (even a null/empty string)
        # since we don't require an accestoken to authenticate with the REST Proxy, but we'll
        # use this string for debugging purposes.
        return "PROXY"
    }

    if ([String]::IsNullOrEmpty($script:authTenantId))
    {
        $output = @()
        $output += "You must call Set-StoreBrokerAuthentication to provide the tenantId"
        $output += "before any of these cmdlets can be used.  It will also cache your"
        $output += "clientId and clientSecret as well.  If you prefer to always be"
        $output += "prompted for the client id and secret, use the -OnlyCacheTenantId switch"
        $output += "when you call Set-StoreBrokerAuthentication."
        $output += "To learn more on how to get these values, go to 'Installation and Setup' here:"
        $output += "   http://aka.ms/StoreBroker"
        Write-Log $($output -join [Environment]::NewLine) -Level Error
        
        throw "Halt Execution"
    }

    # Get our client id and secret, either from the cached credential or by prompting for them.
    $credential = $script:authCredential
    if ($null -eq $credential)
    {
        $output = @()
        $output += "Prompting for credentials."
        $output += "To avoid doing this every time, consider using Set-StoreBrokerAuthentication to cache the values for this session."
        Write-Log $($output -join [Environment]::NewLine)
        $credential = Get-Credential -Message "Enter your client id as your username, and your client secret as your password. ***To avoid getting this prompt every time, consider using Set-StoreBrokerAuthentication.***"
    }

    if ($null -eq $credential)
    {
        Write-Log "You must supply valid credentials (client id and secret) to use this module." -Level Error
        throw "Halt Execution"
    }

    $clientId = $credential.UserName
    $clientSecret = $credential.GetNetworkCredential().Password

    # Constants
    $tokenUrlFormat = "https://login.windows.net/{0}/oauth2/token"
    $authBodyFormat = "grant_type=client_credentials&client_id={0}&client_secret={1}&resource={2}"
    $serviceEndpoint = Get-ServiceEndpoint

    # Need to make sure that the type is loaded before we attempt to access the HttpUtility methods.
    # If we don't do this, we'll fail the first time we try to access the methods, but then it will
    # work fine for consecutive attempts within the same console session.
    Add-Type -AssemblyName System.Web

    $url = $tokenUrlFormat -f $script:authTenantId
    $body = $authBodyFormat -f
                $([System.Web.HttpUtility]::UrlEncode($clientId)),
                $([System.Web.HttpUtility]::UrlEncode($clientSecret)),
                $serviceEndpoint

    try
    {
        Write-Log -Message "Getting access token..." -Level Verbose
        Write-Log "Accessing [POST] $url" -Level Verbose

        if ($NoStatus)
        {
            if ($PSCmdlet.ShouldProcess($url, "Invoke-RestMethod"))
            {
                $response = Invoke-RestMethod $url -Method Post -Body $body
            }

            return $response.access_token
        }
        else
        {
            $jobName = "Get-AccessToken-" + (Get-Date).ToFileTime().ToString()
            if ($PSCmdlet.ShouldProcess($jobName, "Start-Job"))
            {
                [scriptblock]$scriptBlock = {
                    param($url, $body)

                    Invoke-RestMethod $url -Method Post -Body $body
                }

                $null = Start-Job -Name $jobName -ScriptBlock $scriptBlock -Arg @($url, $body)

                if ($PSCmdlet.ShouldProcess($jobName, "Wait-JobWithAnimation"))
                {
                    Wait-JobWithAnimation -JobName $jobName -Description "Getting access token"
                }

                if ($PSCmdlet.ShouldProcess($jobName, "Receive-Job"))
                {
                    $response = Receive-Job $jobName -AutoRemoveJob -Wait -ErrorAction SilentlyContinue -ErrorVariable remoteErrors
                }
            }

            if ($remoteErrors.Count -gt 0)
            {
               throw $remoteErrors[0].Exception
            }

            # Keep track of how long this token will be valid for, to enable logic that re-uses
            # the same token across multiple commands to known when a new one is necessary.
            $script:accessTokenTimeoutSeconds = $response.expires_in - $script:accessTokenRefreshBufferSeconds

            return $response.access_token
        }
    }
    catch [System.InvalidOperationException]
    {
        # This type of exception occurs when using -NoStatus

        # Dig into the exception to get the Response details.
        # Note that value__ is not a typo.
        $output = @()
        $output += "Be sure to check that your client id/secret are valid."
        $output += "StatusCode: $($_.Exception.Response.StatusCode.value__)"
        $output += "StatusDescription: $($_.Exception.Response.StatusDescription)"
        $output += "$($_.ErrorDetails | ConvertFrom-JSON | Out-String)"

        Write-Log $($output -join [Environment]::NewLine) -Level Error
        throw "Halt Execution"
    }
    catch [System.Management.Automation.RuntimeException]
    {
        # This type of exception occurs when NOT using -NoStatus
        $output = @()
        $output += "Be sure to check that your client id/secret are valid."
        $output += "$($_.Exception.Message)"
        if ($_.ErrorDetails.Message)
        {
            $message = ($_.ErrorDetails.Message | ConvertFrom-Json)
            $output += "$($message.code) : $($message.message)"
            if ($message.details)
            {
                $output += "$($message.details | Format-Table | Out-String)"
            }
        }

        Write-Log $($output -join [Environment]::NewLine) -Level Error
        throw "Halt Execution"
    }
}

function Get-ServiceEndpoint
{
<#
    .SYNOPSIS
        Returns the appropriate service endpoint to use for API communication. By default, this
        will always be PROD unless the user has specifically cofigured their environment to use
        INT by setting $global:SBUseInt = $true.

    .DESCRIPTION
        Returns the appropriate service endpoint to use for API communication. By default, this
        will always be PROD unless the user has specifically cofigured their environment to use
        INT by setting $global:SBUseInt = $true.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .EXAMPLE
        Get-ServiceEndpoint
        Returns back the string representing the appropriate service endpoint, depending
        on if the user has created and set a boolean value to $global:SBUseInt.

    .OUTPUTS
        String (the service endpoint URI)
#>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidGlobalVars", "", Justification="We use global variables sparingly and intentionally for module configuration, and employ a consistent naming convention.")]
    param()

    $serviceEndpointInt = "https://manage.devcenter.microsoft-int.com"
    $serviceEndpointProd = "https://manage.devcenter.microsoft.com"

    if (-not [String]::IsNullOrEmpty($script:proxyEndpoint))
    {
        if ($global:SBUseInt)
        {
            # Specifically logging this at the normal level because we want this to be SUPER clear
            # to users so that they don't get confused by the results of their commands.
            Write-Log "Using PROXY INT service endpoint. Return to PROD by setting `$global:SBUseInt = `$false"
        }
        else
        {
            Write-Log "Using PROXY PROD service endpoint" -Level Verbose
        }

        # The endpoint is the same for both in the Proxy case.  But we'll add an additional
        # header to the request when trying to use INT with the proxy.  That's handled in
        # Invoke-SBRestMethod.
        return $script:proxyEndpoint
    }
    elseif ($global:SBUseInt)
    {
        # Specifically logging this at the normal level because we want this to be SUPER clear
        # to users so that they don't get confused by the results of their commands.
        Write-Log "Using INT service endpoint. Return to PROD by setting `$global:SBUseInt = `$false"
        return $serviceEndpointInt
    }
    else
    {
        Write-Log "Using PROD service endpoint" -Level Verbose
        return $serviceEndpointProd
    }
}

function Get-AzureStorageDllPath
{
<#
    .SYNOPSIS
        Makes sure that the Microsoft.AzureStorage.dll assembly is available
        on the machine, and returns the path to it.

    .DESCRIPTION
        Makes sure that the Microsoft.AzureStorage.dll assembly is available
        on the machine, and returns the path to it.

        This will first look for the assembly in the module's script directory.
        
        Next it will look for the assembly in the location defined by
        $SBAlternateAssemblyDir.  This value would have to be defined by the user
        prior to execution of this cmdlet.
        
        If not found there, it will look in a temp folder established during this
        PowerShell session.
        
        If still not found, it will download the nuget package
        for it to a temp folder accessible during this PowerShell session.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER NoStatus
        If this switch is specified, long-running commands will run on the main thread
        with no commandline status update.  When not specified, those commands run in
        the background, enabling the command prompt to provide status information.

    .EXAMPLE
        Get-AzureStorageDllPath

        Returns back the path to the assembly as found.  If the package has to
        be downloaded via nuget, the command prompt will show a time duration
        status counter while the package is being downloaded.

    .EXAMPLE
        Get-AzureStorageDllPath -NoStatus

        Returns back the path to the assembly as found.  If the package has to
        be downloaded via nuget, the command prompt will appear to hang during
        this time.

    .OUTPUTS
        System.String - The path to the Microsoft.WindowsStorage.dll assembly.
#>
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="Methods called within here make use of PSShouldProcess, and the switch is passed on to them inherently.")]
    param(
        [switch] $NoStatus
    )

    $nugetPackageName = "WindowsAzure.Storage"
    $nugetPackageVersion = "6.0.0"
    $assemblyPackageTailDir = "WindowsAzure.Storage.6.0.0\lib\net40\"
    $assemblyName = "Microsoft.WindowsAzure.Storage.dll"

    return Get-NugetPackageDllPath -NugetPackageName $nugetPackageName -NugetPackageVersion $nugetPackageVersion -AssemblyPackageTailDirectory $assemblyPackageTailDir -AssemblyName $assemblyName -NoStatus:$NoStatus
}

function Set-SubmissionPackage
{
<#
    .SYNOPSIS
        Uploads the package to the URL provided after calling New-ApplicationSubmission.

    .DESCRIPTION
        Uploads the package to the URL provided after calling New-ApplicationSubmission.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER PackagePath
        The package (zip) that contains all of the contents (appxupload/appxbundle/screenshots)
        referenced by the submission.

    .PARAMETER UploadUrl
        The unique URL that was provided in response to a successful call to
        New-ApplicationSubmission.
        Supports Pipeline input.

    .PARAMETER NoStatus
        If this switch is specified, long-running commands will run on the main thread
        with no commandline status update.  When not specified, those commands run in
        the background, enabling the command prompt to provide status information.

    .EXAMPLE
        Upload-SubmissionPackage "c:\foo.zip" "https://prodingestionbinaries1.blob.core.windows.net/ingestion/00000000-abcd-1234-0000-abcdefghijkl?sv=2014-02-14&sr=b&sig=WujGssA00/voXHaDgmaK1mpPn2JUkRPD/123gkAJdnI=&se=2015-12-17T12:58:14Z&sp=rwl"
        Uploads the package content for the application submission,
        with the console window showing progress while waiting for the upload to complete.

    .EXAMPLE
        Upload-SubmissionPackage "c:\foo.zip" "https://prodingestionbinaries1.blob.core.windows.net/ingestion/00000000-abcd-1234-0000-abcdefghijkl?sv=2014-02-14&sr=b&sig=WujGssA00/voXHaDgmaK1mpPn2JUkRPD/123gkAJdnI=&se=2015-12-17T12:58:14Z&sp=rwl" -NoStatus
        Uploads the package content for the application submission,
        but the request happens in the foreground and there is no additional status
        shown to the user until the upload has completed.

    .NOTES
        This does not provide percentage completed status on the upload.  It is only
        able to provide the duration of the existing command (provided that you don't use
        the -NoStatus switch).

        This uses the "Set" verb to avoid Powershell import module warnings, but is then
        aliased to Upload-ApplicationSubmissionPackage to better express what it is actually doing.
#>
    [CmdletBinding(SupportsShouldProcess)]
    [Alias('Set-ApplicationSubmissionPackage')]
    [Alias('Upload-ApplicationSubmissionPackage')]
    [Alias('Upload-SubmissionPackage')]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({if (Test-Path -Path $_ -PathType Leaf) { $true } else { throw "$_ cannot be found." }})]
        [string] $PackagePath,

        [Parameter(
            Mandatory,
            ValueFromPipeline=$True)]
        [string] $UploadUrl,
        
        [switch] $NoStatus
    )

    # Let's resolve this path to a full path so that it works with non-PowerShell commands (like the Azure module)
    $PackagePath = Resolve-UnverifiedPath -Path $PackagePath

    # Telemetry-related
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $telemetryProperties = @{ [StoreBrokerTelemetryProperty]::PackagePath = (Get-PiiSafeString -PlainText $PackagePath) }

    Write-Log "Executing: $($MyInvocation.Line)" -Level Verbose 

    Write-Log "Attempting to upload the package ($PackagePath) for the submission to $UploadUrl..." -Level Verbose 

    $azureStorageDll = Get-AzureStorageDllPath -NoStatus:$NoStatus 

    try
    {
        if ($NoStatus)
        {
            $bytes = [System.IO.File]::ReadAllBytes($azureStorageDll)
            [System.Reflection.Assembly]::Load($bytes) | Out-Null
            
            $uri = New-Object -TypeName System.Uri -ArgumentList $UploadUrl
            $cloudBlockBlob = New-Object -TypeName Microsoft.WindowsAzure.Storage.Blob.CloudBlockBlob -ArgumentList $uri

            if ($PSCmdlet.ShouldProcess($PackagePath, "CloudBlockBlob.UploadFromFile"))
            {
                $result = $cloudBlockBlob.UploadFromFile($PackagePath, [System.IO.FileMode]::Open)
            }
        }
        else
        {
            $jobName = "Set-SubmissionPackage-" + (Get-Date).ToFileTime().ToString()

            if ($PSCmdlet.ShouldProcess($jobName, "Start-Job"))
            {
                [scriptblock]$scriptBlock = {
                    param($UploadUrl, $PackagePath, $AzureStorageDll)
                    
                    $bytes = [System.IO.File]::ReadAllBytes($AzureStorageDll)
                    [System.Reflection.Assembly]::Load($bytes) | Out-Null

                    $uri = New-Object -TypeName System.Uri -ArgumentList $UploadUrl
                    $cloudBlockBlob = New-Object -TypeName Microsoft.WindowsAzure.Storage.Blob.CloudBlockBlob -ArgumentList $uri
                    $cloudBlockBlob.UploadFromFile($PackagePath, [System.IO.FileMode]::Open)
                }

                $null = Start-Job -Name $jobName -ScriptBlock $scriptBlock -Arg @($UploadUrl, $PackagePath, $azureStorageDll)

                if ($PSCmdlet.ShouldProcess($jobName, "Wait-JobWithAnimation"))
                {
                    Wait-JobWithAnimation -JobName $jobName -Description "Uploading $PackagePath"
                }

                if ($PSCmdlet.ShouldProcess($jobName, "Receive-Job"))
                {
                    $result = Receive-Job $jobName -AutoRemoveJob -Wait -ErrorAction SilentlyContinue -ErrorVariable remoteErrors
                }
            }

            if ($remoteErrors.Count -gt 0)
            {
               throw $remoteErrors[0].Exception
            }
        }

        # Record the telemetry for this event.
        $stopwatch.Stop()
        $telemetryMetrics = @{ [StoreBrokerTelemetryMetric]::Duration = $stopwatch.Elapsed.TotalSeconds }
        Set-TelemetryEvent -EventName Set-SubmissionPackage -Properties $telemetryProperties -Metrics $telemetryMetrics 
    }
    catch [System.Management.Automation.RuntimeException]
    {
        # This type of exception occurs when NOT using -NoStatus

        $output = @()
        $output += "$($_.Exception.Message)"
        if ($_.ErrorDetails.Message)
        {
            $message = ($_.ErrorDetails.Message | ConvertFrom-Json)
            $output += "$($message.code) : $($message.message)"
            if ($message.details)
            {
                $output += "$($message.details | Format-Table | Out-String)"
            }
        }

        Set-TelemetryException -Exception $_.Exception -ErrorBucket Set-SubmissionPackage -Properties $telemetryProperties 
        Write-Log $($output -join [Environment]::NewLine) -Level Error 
        throw "Halt Execution"
    }
    catch
    {
        # This type of exception occurs when using -NoStatus

        # Dig into the exception to get the Response details.
        # Note that value__ is not a typo.
        $output = @()
        $output += "StatusCode: $($_.Exception.Response.StatusCode.value__)"
        $output += "StatusDescription: $($_.Exception.Response.StatusDescription)"
        $output += "$($_.ErrorDetails)"
        
        Set-TelemetryException -Exception $_.Exception -ErrorBucket Set-SubmissionPackage -Properties $telemetryProperties 
        Write-Log $($output -join [Environment]::NewLine) -Level Error 
        throw "Halt Execution"
    }

    Write-Log "Successfully uploaded the application package." -Level Verbose 
    return $result
}

function Get-SubmissionPackage
{
<#
    .SYNOPSIS
        Downloads the existing package from the URL provided after calling New-ApplicationSubmission.

    .DESCRIPTION
        Downloads the existing package from the URL provided after calling New-ApplicationSubmission.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER UploadUrl
        The unique URL that was provided in response to a successful call to
        New-ApplicationSubmission.
        Supports Pipeline input.

    .PARAMETER PackagePath
        The local path that you want to store the package (zip) that contains all of the contents
        (appxupload/appxbundle/screenshots) referenced by the submission.

    .PARAMETER NoStatus
        If this switch is specified, long-running commands will run on the main thread
        with no commandline status update.  When not specified, those commands run in
        the background, enabling the command prompt to provide status information.

    .EXAMPLE
        Get-SubmissionPackage "https://prodingestionbinaries1.blob.core.windows.net/ingestion/00000000-abcd-1234-0000-abcdefghijkl?sv=2014-02-14&sr=b&sig=WujGssA00/voXHaDgmaK1mpPn2JUkRPD/123gkAJdnI=&se=2015-12-17T12:58:14Z&sp=rwl" "c:\foo.zip"
        Downloads the package content for the application submission to c:\foo.zip,
        with the console window showing progress while awaiting for the download to complete.

    .EXAMPLE
        Get-SubmissionPackage "https://prodingestionbinaries1.blob.core.windows.net/ingestion/00000000-abcd-1234-0000-abcdefghijkl?sv=2014-02-14&sr=b&sig=WujGssA00/voXHaDgmaK1mpPn2JUkRPD/123gkAJdnI=&se=2015-12-17T12:58:14Z&sp=rwl" "c:\foo.zip" -NoStatus
        Downloads the package content for the application submission to c:\foo.zip,
        but the download happens in the foreground and there is no additional status
        shown to the user until the download completes.

    .NOTES
        This does not provide percentage completed status on the download.  It is only
        able to provide the duration of the existing command (provided that you don't use
        the -NoStatus switch).
#>
    [CmdletBinding(SupportsShouldProcess)]
    [Alias('Get-ApplicationSubmissionPackage')]
    param(
        [Parameter(
            Mandatory,
            ValueFromPipeline=$True)]
        [string] $UploadUrl,
        
        [Parameter(Mandatory)]
        [ValidateScript({if (Test-Path -Path $_ -PathType Leaf) { throw "$_ already exists. Choose a different destination name." } else { $true }})]
        [string] $PackagePath,

        [switch] $NoStatus
    )

    # Let's resolve this path to a full path so that it works with non-PowerShell commands (like the Azure module)
    $PackagePath = Resolve-UnverifiedPath -Path $PackagePath

    # Telemetry-related
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $telemetryProperties = @{ [StoreBrokerTelemetryProperty]::PackagePath = (Get-PiiSafeString -PlainText $PackagePath) }

    Write-Log "Executing: $($MyInvocation.Line)" -Level Verbose 

    Write-Log "Attempting to download the contents of $UploadUrl to $PackagePath..." -Level Verbose 

    $azureStorageDll = Get-AzureStorageDllPath -NoStatus:$NoStatus 

    try
    {
        if ($NoStatus)
        {
            $bytes = [System.IO.File]::ReadAllBytes($azureStorageDll)
            [System.Reflection.Assembly]::Load($bytes) | Out-Null

            $uri = New-Object -TypeName System.Uri -ArgumentList $UploadUrl
            $cloudBlockBlob = New-Object -TypeName Microsoft.WindowsAzure.Storage.Blob.CloudBlockBlob -ArgumentList $uri

            if ($PSCmdlet.ShouldProcess($PackagePath, "CloudBlockBlob.DownloadToFile"))
            {
                $result = $cloudBlockBlob.DownloadToFile($PackagePath, [System.IO.FileMode]::OpenOrCreate)
            }
        }
        else
        {
            $jobName = "Get-SubmissionPackage-" + (Get-Date).ToFileTime().ToString()

            if ($PSCmdlet.ShouldProcess($jobName, "Start-Job"))
            {
                [scriptblock]$scriptBlock = {
                    param($UploadUrl, $PackagePath, $AzureStorageDll)
                    
                    $bytes = [System.IO.File]::ReadAllBytes($AzureStorageDll)
                    [System.Reflection.Assembly]::Load($bytes) | Out-Null

                    $uri = New-Object -TypeName System.Uri -ArgumentList $UploadUrl
                    $cloudBlockBlob = New-Object -TypeName Microsoft.WindowsAzure.Storage.Blob.CloudBlockBlob -ArgumentList $uri
                    $cloudBlockBlob.DownloadToFile($PackagePath, [System.IO.FileMode]::OpenOrCreate)
                }

                $null = Start-Job -Name $jobName -ScriptBlock $scriptBlock -Arg @($UploadUrl, $PackagePath, $azureStorageDll)

                if ($PSCmdlet.ShouldProcess($jobName, "Wait-JobWithAnimation"))
                {
                    Wait-JobWithAnimation -JobName $jobName -Description "Downloading contents to $PackagePath"
                }

                if ($PSCmdlet.ShouldProcess($jobName, "Receive-Job"))
                {
                    $result = Receive-Job $jobName -AutoRemoveJob -Wait -ErrorAction SilentlyContinue -ErrorVariable remoteErrors
                }
            }

            if ($remoteErrors.Count -gt 0)
            {
               throw $remoteErrors[0].Exception
            }
        }

        # Record the telemetry for this event.
        $stopwatch.Stop()
        $telemetryMetrics = @{ [StoreBrokerTelemetryMetric]::Duration = $stopwatch.Elapsed.TotalSeconds }
        Set-TelemetryEvent -EventName Get-SubmissionPackage -Properties $telemetryProperties -Metrics $telemetryMetrics 
    }
    catch [System.Management.Automation.RuntimeException]
    {
        # This type of exception occurs when NOT using -NoStatus

        $output = @()
        $output += "$($_.Exception.Message)"
        if ($_.ErrorDetails.Message)
        {
            $message = ($_.ErrorDetails.Message | ConvertFrom-Json)
            $output += "$($message.code) : $($message.message)"
            if ($message.details)
            {
                $output += "$($message.details | Format-Table | Out-String)"
            }
        }

        Set-TelemetryException -Exception $_.Exception -ErrorBucket Get-SubmissionPackage -Properties $telemetryProperties 
        Write-Log $($output -join [Environment]::NewLine) -Level Error 
        throw "Halt Execution"
    }
    catch
    {
        # This type of exception occurs when using -NoStatus

        # Dig into the exception to get the Response details.
        # Note that value__ is not a typo.
        $output = @()
        $output += "StatusCode: $($_.Exception.Response.StatusCode.value__)"
        $output += "StatusDescription: $($_.Exception.Response.StatusDescription)"
        $output += "$($_.ErrorDetails)"
        
        Set-TelemetryException -Exception $_.Exception -ErrorBucket Get-SubmissionPackage -Properties $telemetryProperties 
        Write-Log $($output -join [Environment]::NewLine) -Level Error 
        throw "Halt Execution"
    }

    Write-Log "Successfully downloaded the blob contents." -Level Verbose 
    return $result
}

function Start-SubmissionMonitor
{
<#
    .SYNOPSIS
        Auto-checks an application submission for status changes every 60 seconds with optional
        email notification.

    .DESCRIPTION
        Auto-checks an application submission for status changes every 60 seconds with optional
        email notification.

        The monitoring will automatically end if the submission enters a failed state, or once
        its state enters the final state that its targetPublishMode allows for.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER AppId
        The Application ID for the application that has the committed submission.

    .PARAMETER SubmissionId
        The ID of the submission that should be monitored.

    .PARAMETER EmailNotifyTo
        A list of email addresses that should be emailed every time that status changes for
        this submission.

    .PARAMETER FlightId
        This optional parameter, if provided, will treat the submission being monitored as a
        flight submission as opposed to an application submission.

    .PARAMETER IapId
        If provided, this will treat the submission being monitored as an In-App Product
        submission as opposed to an application submission.

    .PARAMETER NoStatus
        If this switch is specified, long-running commands will run on the main thread
        with no commandline status update.  When not specified, those commands run in
        the background, enabling the command prompt to provide status information.

    .EXAMPLE
        Start-SubmissionMonitor 0ABCDEF12345 1234567890123456789
        Checks that submission every 60 seconds until the submission enters a Failed state
        or reaches the final state that it can reach given its current targetPublishMode.

    .EXAMPLE
        Start-SubmissionMonitor 0ABCDEF12345 1234567890123456789 user@foo.com
        Checks that submission every 60 seconds until the submission enters a Failed state
        or reaches the final state that it can reach given its current targetPublishMode.
        Will email user@foo.com every time this status changes as well.
#>
    [CmdletBinding(
        SupportsShouldProcess,
        DefaultParametersetName="AppOrFlight")]
    [Alias('Start-ApplicationSubmissionMonitor')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="Methods called within here make use of PSShouldProcess, and the switch is passed on to them inherently.")]
    param(
        [Parameter(
            Mandatory,
            ParameterSetName="AppOrFlight",
            Position=0)]
        [string] $AppId,
        
        [Parameter(
            Mandatory,
            ParameterSetName="AppOrFlight",
            Position=1)]
        [Parameter(
            Mandatory,
            ParameterSetName="Iap",
            Position=1)]
        [string] $SubmissionId,

        [Parameter(
            ParameterSetName="AppOrFlight",
            Position=2)]
        [Parameter(
            ParameterSetName="Iap",
            Position=2)]
        [string[]] $EmailNotifyTo = @(),

        [Parameter(ParameterSetName="AppOrFlight")]
        [string] $FlightId = $null,

        [Parameter(
            Mandatory,
            ParameterSetName="Iap",
            Position=0)]
        [string] $IapId,

        [switch] $NoStatus
    )

    Write-Log "Executing: $($MyInvocation.Line)" -Level Verbose 

    # Telemetry-related
    $telemetryProperties = @{
        [StoreBrokerTelemetryProperty]::AppId = $AppId
        [StoreBrokerTelemetryProperty]::SubmissionId = $SubmissionId
    }

    if (-not [String]::IsNullOrEmpty($FlightId)) { $telemetryProperties[[StoreBrokerTelemetryProperty]::FlightId] = $FlightId }
    if (-not [String]::IsNullOrEmpty($IapId)) { $telemetryProperties[[StoreBrokerTelemetryProperty]::IapId] = $IapId }
    $telemetryMetrics = @{ [StoreBrokerTelemetryMetric]::NumEmailAddresses = $EmailNotifyTo.Count }
    Set-TelemetryEvent -EventName Start-ApplicationSubmissionMonitor -Properties $telemetryProperties -Metrics $telemetryMetrics 

    $shouldMonitor = $true
    $indentLength = 5
    $lastTokenRefreshTime = Get-Date
    $accessToken = Get-AccessToken -NoStatus:$NoStatus 

    # Get the info so we have it's name when we give the user updates.
    $isIapSubmission = -not [String]::IsNullOrEmpty($IapId)
    if ($isIapSubmission)
    {
        $iap = Get-InAppProduct -IapId $IapId -AccessToken $AccessToken -NoStatus:$NoStatus 
        $appName = $iap.productId
        $fullName = $appName
    }
    else
    {
        $app = Get-Application -AppId $AppId -AccessToken $AccessToken -NoStatus:$NoStatus 
        $appName = $app.primaryName
        $fullName = $appName

        # If this is monitoring a flight submission, let's also get the flight's friendly name for
        # those updates as well.
        $isFlightingSubmission = (-not [String]::IsNullOrEmpty($FlightId))
        if ($isFlightingSubmission)
        {
            $flight = Get-ApplicationFlight -AppId $AppId -FlightId $FlightId -AccessToken $AccessToken -NoStatus:$NoStatus 
            $flightName = $flight.friendlyName
            $fullName = "$appName | $flightName"
        }
    }

    # We can safely assume this is being used on a recently committed submission.
    # If it isn't we'll report that to the user and update this value during the first
    # run through our loop.
    $lastStatus = "CommitStarted"

    while ($shouldMonitor)
    {
        # We need to refresh our access token every hour...we'll go a little more often to give
        # ourselves some wiggle room to avoid unnecessary failures.
        $accessTokenTimeoutMinutes = 58
        if ((New-TimeSpan $lastTokenRefreshTime $(Get-Date)).Minutes -gt $accessTokenTimeoutMinutes)
        {
            $lastTokenRefreshTime = Get-Date
            $accessToken = Get-AccessToken -NoStatus:$NoStatus 
        }

        try
        {
            if ($isIapSubmission)
            {
                $submission = Get-InAppProductSubmission -IapId $IapId -SubmissionId $SubmissionId -AccessToken $AccessToken -NoStatus:$NoStatus 
            }
            elseif ($isFlightingSubmission)
            {
                $submission = Get-ApplicationFlightSubmission -AppId $AppId -FlightId $FlightId -SubmissionId $SubmissionId -AccessToken $AccessToken -NoStatus:$NoStatus 
            }
            else
            {
                $submission = Get-ApplicationSubmission -AppId $AppId -SubmissionId $SubmissionId -AccessToken $AccessToken -NoStatus:$NoStatus 
            }

            if ($submission.status -ne $lastStatus)
            {
                $lastStatus = $submission.status

                $body = @()
                $body += ""
                if ($isIapSubmission)
                {
                    $body += "IapId             : $IapId ($appName)"
                }
                else
                {
                    $body += "AppId             : $AppId ($appName)"
                    if ($isFlightingSubmission)
                    {
                        $body += "FlightId          : $FlightId ($flightName)"
                    }
                }

                $body += "SubmissionId      : $SubmissionId"
                $body += "Submission Status : $lastStatus"
                $body += ""
                $body += "Status Details [Errors]                : {0}" -f $(if ($submission.statusDetails.errors.count -eq 0) { "<None>" } else { "" })
                $body += $submission.statusDetails.errors | Format-SimpleTableString -IndentationLevel $indentLength
                $body += ""
                $body += "Status Details [Warnings]              : {0}" -f $(if ($submission.statusDetails.warnings.count -eq 0) { "<None>" } else { "" })
                $body += $submission.statusDetails.warnings | Format-SimpleTableString -IndentationLevel $indentLength
                $body += ""
                $body += "Status Details [Certification Reports] : {0}" -f $(if ($submission.statusDetails.certificationReports.count -eq 0) { "<None>" } else { "" })
                foreach ($report in $submission.statusDetails.certificationReports)
                {
                    $body += $(" " * $indentLength) + $(Get-Date -Date $report.date -Format R) + ": $($report.reportUrl)"
                }

                $body += ""
                $body += "To view the full submission"
                $body += "---------------------------"
                if ($isIapSubmission)
                {
                    $body += "Dev Portal URL"
                    $body += "    https://dev.windows.com/en-us/dashboard/iaps/$IapId/submissions/$SubmissionId/"
                    $body += "StoreBroker command"
                    $body += "    Get-InAppProductSubmission -IapId $IapId -SubmissionId $SubmissionId"
                }
                else
                {
                    $body += "Dev Portal URL"
                    $body += "    https://dev.windows.com/en-us/dashboard/apps/$AppId/submissions/$SubmissionId/"
                    $body += "StoreBroker command"
                    if ($isFlightingSubmission)
                    {
                        $body += "    Get-ApplicationFlightSubmission -AppId $AppId -FlightId $FlightId -SubmissionId $SubmissionId"
                    }
                    else
                    {
                        $body += "    Get-ApplicationSubmission -AppId $AppId -SubmissionId $SubmissionId"
                    }
                }

                # Any status that ends in Failed is absolutely a failed state that the user won't leave.
                # If it changes from CommitStarted -> PendingCommit, that's indicative of a server-side
                # failure that we also can't recover from.
                if (($lastStatus -like "*Failed") -or ($lastStatus -eq $script:keywordPendingCommit))
                {
                    $body += ""
                    $body += "*** Your submission has entered a Failed state.  Monitoring will now end."

                    $shouldMonitor = $false
                }

                if (($lastStatus -eq $script:keywordRelease) -and ($submission.targetPublishMode -in ($script:keywordManual, $script:keywordSpecificDate)))
                {
                    $body += ""
                    $body += "*** Your submission is ready for publishing.  Monitoring will now end."

                    $shouldMonitor = $false
                }

                if ($lastStatus -eq $script:keywordPublished)
                {
                    $body += ""
                    $body += "*** Your submission has been published.  Monitoring will now end."

                    $shouldMonitor = $false
                }

                Write-Log $($body -join [Environment]::NewLine) 

                if ($EmailNotifyTo.Count -gt 0)
                {
                    $subject = "Status change for [$fullName] submission [$SubmissionId] : $lastStatus"
                    Send-SBMailMessage -Subject $subject -Body $($body -join [Environment]::NewLine) -To $EmailNotifyTo
                }
            }
        }
        catch
        {
            # Trying to catch out the timed out exception.  It currently reports back as:
            # "The operation has timed out.", but this wording could clearly change over time.
            if ($_.Exception.Message -ilike "*timed*")
            {
                Write-Log "Got exception while trying to check on submission: $($_.Exception.Message). Will try again." -Level Warning 
            }
            else
            {
                throw
            }
        }

        if ($shouldMonitor)
        {
            $secondsBetweenChecks = 60
            Write-Log "Status is [$lastStatus]. Waiting $secondsBetweenChecks seconds before checking again..." 
            Start-Sleep -Seconds $secondsBetweenChecks
        }
    }
}

function Open-DevPortal
{
<#
    .SYNOPSIS
        Launches the Dev Portal in the default web browser to display the requested information.

    .DESCRIPTION
        Launches the Dev Portal in the default web browser to display the requested information.

        Sometimes users simply want to be able to see what's going on within the web portal as
        opposed to the commandline.  This is designed to make that work as quickly as possible.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER AppId
        The ID of the application to be viewed.

    .PARAMETER SubmissionId
        The ID of the submission to be viewed.

    .PARAMETER ShowFlight
        If provided, will show the flight UI as opposed to the flight submission UI.

    .EXAMPLE
        Open-DevPortal 0ABCDEF12345

        Opens a new tab in the default web browser to the page in the Dev Portal that displays
        the general status of the application.

    .EXAMPLE
        Open-DevPortal 0ABCDEF12345 1234567890123456789

        Opens a new tab in the default web browser to the page in the Dev Portal that displays
        the indicated submission.  Will work for both app and flight submissions.

    .EXAMPLE
        Open-DevPortal 0ABCDEF12345 1234567890123456789 -ShowFlight

        Opens a new tab in the default web browser to the page in the Dev Portal that displays
        the flight edit page (enabling you to change the name, flight groups and ranking).
#>
    [CmdletBinding(DefaultParametersetName="App")]
    param(
        [Parameter(
            Mandatory,
            ParameterSetName="App",
            Position=0)]
        [Parameter(
            Mandatory,
            ParameterSetName="Submission",
            Position=0)]
        [string] $AppId,

        [Parameter(
            Mandatory,
            ParameterSetName="Submission",
            Position=1)]
        [string] $SubmissionId,

        [Parameter(ParameterSetName="Submission")]
        [switch] $ShowFlight
    )

    # Telemetry-related
    $telemetryProperties = @{
        [StoreBrokerTelemetryProperty]::AppId = $AppId
        [StoreBrokerTelemetryProperty]::ShowSubmission = (-not [String]::IsNullOrEmpty($SubmissionId))
        [StoreBrokerTelemetryProperty]::ShowFlight = $ShowFlight
    }

    Set-TelemetryEvent -EventName Open-DevPortal -Properties $telemetryProperties 

    Write-Log "Opening Dev Portal in default web browser." 
    
    $appUrl        = "https://developer.microsoft.com/en-us/dashboard/apps/$AppId"
    $submissionUrl = "https://developer.microsoft.com/en-us/dashboard/apps/$AppId/submissions/$SubmissionId/"
    $flightUrl     = "https://developer.microsoft.com/en-us/dashboard/Application/GetFlight?appId=$AppId&submissionId=$SubmissionId"

    if ($ShowFlight)
    {
        Start-Process -FilePath $flightUrl
    }
    elseif ([String]::IsNullOrEmpty($SubmissionId))
    {
        Start-Process -FilePath $appUrl
    }
    else
    {
        Start-Process -FilePath $submissionUrl
    }
}

function Get-ProperEnumCasing
{
<#
    .SYNOPSIS
        Gets the proper casing for the provided enum value per the requirements of the
        Windows Store Submission API.

    .DESCRIPTION
        Gets the proper casing for the provided enum value per the requirements of the
        Windows Store Submission API.

        The API is case-sensitive on these enum values, but PowerShell isn't, so we need to do
        a little extra work to ensure proper casing is used when modifying the JSON.  We won't
        be trying to ensure every possible enum value is the right casing -- just the ones that
        users are most likely to alter during submissions.  More can be added as needed over time.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER EnumValue
        The enum value the user needs the proper casing for.

    .EXAMPLE
        Get-ProperEnumCasing -EnumValue immediate

        Returns "Immediate"

    .EXAMPLE
        Get-ProperEnumCasing -EnumValue 'Un1kn0wn'

        Returns the provided value "Un1kn0wn" since it's not a known Enum value.

    .OUTPUTS
        System.String
    
    .NOTES
        Internal-only helper method.

        For now, we assume that if the same value is used in multiple enums within the API,
        the casing will be identical in all scenarios.  If that proves to not be the case in the
        future, then this function (and its callers) will need to be updated to provide context
        for where the enum value is being used.
#>
    param(
        [Parameter(Mandatory)]
        [string] $EnumValue
    )

    switch ($EnumValue)
    {
        'Hidden'                    { return 'Hidden' }
        'Immediate'                 { return 'Immediate' }
        $script:keywordManual       { return $script:keywordManual }
        'Public'                    { return 'Public' }
        'Private'                   { return 'Private' }
        $script:keywordSpecificDate { return $script:keywordSpecificDate }
    }

    # If we don't know the Enum value, we'll simply return the intiial value sent in.
    return $EnumValue
}

function Invoke-SBRestMethod
{
<#
    .SYNOPSIS
        A wrapper around Invoke-WebRequest that understands the Store API.

    .DESCRIPTION
        A very heavy wrapper around Invoke-WebRequest that understands the Store API and
        how to perform its operation with and without console status updates.  It also
        understands how to parse and handle errors from the REST calls.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER UriFragment
        The unique, tail-end, of the REST URI that indicates what Store REST action will
        be peformed.  This should not start with a leading "/".

    .PARAMETER Method
        The type of REST method being peformed.  This only supports a reduced set of the
        possible REST methods (delete, get, post, put).

    .PARAMETER Description
        A friendly description of the operation being performed for logging and console
        display purposes.

    .PARAMETER Body
        This optional parameter forms the body of a PUT or POST request. It will be automatically
        encoded to UTF8 and sent as Content Type: "application/json; charset=UTF-8"

    .PARAMETER AccessToken
        If provided, this will be used as the AccessToken for authentication with the
        REST Api as opposed to requesting a new one.

    .PARAMETER TelemetryEventName
        If provided, the successful execution of this REST command will be logged to telemetry
        using this event name.

    .PARAMETER TelemetryProperties
        If provided, the successful execution of this REST command will be logged to telemetry
        with these additional properties.  This will be silently ignored if TelemetryEventName
        is not provided as well.

    .PARAMETER TelemetryExceptionBucket
        If provided, any exception that occurs will be logged to telemetry using this bucket.
        It's possible that users will wish to log exceptions but not success (by providing
        TelemetryEventName) if this is being executed as part of a larger scenario.  If this
        isn't provided, but TelemetryEventName *is* provided, then TelemetryEventName will be
        used as the exception bucket value in the event of an exception.  If neither is specified,
        no bucket value will be used.

    .PARAMETER NoStatus
        If this switch is specified, long-running commands will run on the main thread
        with no commandline status update.  When not specified, those commands run in
        the background, enabling the command prompt to provide status information.

    .OUTPUTS
        The result of the REST operation, in whatever form it comes in.

    .EXAMPLE
        Invoke-SBRestMethod -UriFragment "applications/" -Method Get -Description "Get first 10 applications"

        Gets the first 10 applications for the connected dev account.

    .EXAMPLE
        Invoke-SBRestMethod -UriFragment "applications/0ABCDEF12345/submissions/1234567890123456789/" -Method Delete -Description "Delete Submission" -NoStatus

        Deletes the specified submission, but the request happens in the foreground and there is
        no additional status shown to the user until a response is returned from the REST request.

    .NOTES
        This wraps Invoke-WebRequest as opposed to Invoke-RestMethod because we want access to the headers
        that are returned in the response (specifically 'MS-CorrelationId') for logging purposes, and
        Invoke-RestMethod drops those headers.
#>
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidGlobalVars", "", Justification="We use global variables sparingly and intentionally for module configuration, and employ a consistent naming convention.")]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({if ($_.StartsWith("/")) { throw "Fragments should not start with a leading `"/`"" } else { return $true }})]
        [string] $UriFragment,

        [Parameter(Mandatory)]
        [ValidateSet('delete', 'get', 'post', 'put')]
        [string] $Method,

        [Parameter(Mandatory)]
        [string] $Description,

        [string] $Body = $null,

        [string] $AccessToken = "",

        [string] $TelemetryEventName = $null,

        [hashtable] $TelemetryProperties = @{},

        [string] $TelemetryExceptionBucket = $null,

        [switch] $NoStatus
    )

    $serviceEndpointVersion = "1.0"

    if ([System.String]::IsNullOrEmpty($AccessToken))
    {
        $AccessToken = Get-AccessToken -NoStatus:$NoStatus
    }

    # Telemetry-related
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $localTelemetryProperties = @{ [StoreBrokerTelemetryProperty]::UriFragment = $UriFragment }
    $TelemetryProperties.Keys | ForEach-Object { $localTelemetryProperties[$_] = $TelemetryProperties[$_] }
    $errorBucket = $TelemetryExceptionBucket
    if ([String]::IsNullOrEmpty($errorBucket))
    {
        $errorBucket = $TelemetryEventName
    }

    $serviceEndpoint = Get-ServiceEndpoint
    $url = "$serviceEndpoint/v$serviceEndpointVersion/my/$UriFragment"

    $headers = @{"Authorization" = "Bearer $AccessToken"}
    if ($Method -in ('post', 'put'))
    {
        $headers.Add("Content-Type", "application/json; charset=UTF-8")
    }

    # Add any special headers when using the proxy.
    if ($serviceEndpoint -eq $script:proxyEndpoint)
    {
        if ($global:SBUseInt)
        {
            $headers.Add("UseINT", "true")
        }
        
        if (-not [String]::IsNullOrWhiteSpace($script:authTenantId))
        {
            $headers.Add("TenantId", $script:authTenantId)
        }

        if (-not [String]::IsNullOrWhiteSpace($script:authTenantName))
        {
            $headers.Add("TenantName", $script:authTenantName)
        }
    }

    try
    {
        Write-Log $Description -Level Verbose
        Write-Log "Accessing [$Method] $url [Timeout = $global:SBWebRequestTimeoutSec]" -Level Verbose

        if ($NoStatus)
        {
            if ($PSCmdlet.ShouldProcess($url, "Invoke-WebRequest"))
            {
                $params = @{}
                $params.Add("Uri", $url)
                $params.Add("Method", $Method)
                $params.Add("Headers", $headers)
                $params.Add("UseDefaultCredentials", $true)
                $params.Add("UseBasicParsing", $true)
                $params.Add("TimeoutSec", $global:SBWebRequestTimeoutSec)
                
                if ($Method -in ('post', 'put') -and (-not [String]::IsNullOrEmpty($Body)))
                {
                    $bodyAsBytes = [System.Text.Encoding]::UTF8.GetBytes($Body)
                    $params.Add("Body", $bodyAsBytes)
                }

                $result = Invoke-WebRequest @params
                if ($Method -eq 'delete')
                {
                    Write-Log "Successfully removed." -Level Verbose
                }
            }
        }
        else
        {
            $jobName = "Invoke-SBRestMethod-" + (Get-Date).ToFileTime().ToString()

            if ($PSCmdlet.ShouldProcess($jobName, "Start-Job"))
            {
                [scriptblock]$scriptBlock = {
                    param($Url, $method, $Headers, $Body, $HeaderName, $TimeoutSec)

                    # Because this is running in a different PowerShell process, we need to
                    # redefine this script variable (for use within the exception)
                    $script:headerMSCorrelationId = $HeaderName

                    $params = @{}
                    $params.Add("Uri", $Url)
                    $params.Add("Method", $Method)
                    $params.Add("Headers", $Headers)
                    $params.Add("UseDefaultCredentials", $true)
                    $params.Add("UseBasicParsing", $true)
                    $params.Add("TimeoutSec", $TimeoutSec)
                
                    if ($Method -in ('post', 'put') -and (-not [String]::IsNullOrEmpty($Body)))
                    {
                        $bodyAsBytes = [System.Text.Encoding]::UTF8.GetBytes($Body)
                        $params.Add("Body", $bodyAsBytes)
                    }

                    try
                    {
                        Invoke-WebRequest @params
                    }
                    catch [System.Net.WebException]
                    {
                        # We need to access the CorrelationId header in the exception handling,
                        # but the actual *values* of the headers of a WebException don't get serialized
                        # when the RemoteException wraps it.  To work around that, we'll extract the
                        # information that we actually care about *now*, and then we'll throw our own exception
                        # that is just a JSON object with the data that we'll later extract for processing in
                        # the main catch.
                        $ex = @{}
                        $ex.Message = $_.Exception.Message
                        $ex.StatusCode = $_.Exception.Response.StatusCode
                        $ex.StatusDescription = $_.Exception.Response.StatusDescription
                        $ex.InnerMessage = $_.ErrorDetails.Message
                        if ($_.Exception.Response.Headers.Count -gt 0)
                        {
                            $ex.CorrelationId = $_.Exception.Response.Headers[$script:headerMSCorrelationId]
                        }

                        throw ($ex | ConvertTo-Json -Depth 20)
                    }
                }

                $null = Start-Job -Name $jobName -ScriptBlock $scriptBlock -Arg @($url, $Method, $headers, $Body, $script:headerMSCorrelationId, $global:SBWebRequestTimeoutSec)

                if ($PSCmdlet.ShouldProcess($jobName, "Wait-JobWithAnimation"))
                {
                    Wait-JobWithAnimation -JobName $jobName -Description $Description
                }

                if ($PSCmdlet.ShouldProcess($jobName, "Receive-Job"))
                {
                    $result = Receive-Job $jobName -AutoRemoveJob -Wait -ErrorAction SilentlyContinue -ErrorVariable remoteErrors
                }
            }

            if ($remoteErrors.Count -gt 0)
            {
                throw $remoteErrors[0].Exception
            }

            if ($Method -eq 'delete')
            {
                Write-Log "Successfully removed." -Level Verbose
            }
        }

        $correlationId = $result.Headers[$script:headerMSCorrelationId]
        if (-not [String]::IsNullOrEmpty($correlationId))
        {
            Write-Log "$($script:headerMSCorrelationId): $correlationId" -Level Verbose
        }

        # Record the telemetry for this event.
        $stopwatch.Stop()
        if (-not [String]::IsNullOrEmpty($TelemetryEventName))
        {
            $telemetryMetrics = @{ [StoreBrokerTelemetryMetric]::Duration = $stopwatch.Elapsed.TotalSeconds }
            Set-TelemetryEvent -EventName $TelemetryEventName -Properties $localTelemetryProperties -Metrics $telemetryMetrics
        }

        $finalResult = $result.Content
        try
        {
            $finalResult = $finalResult | ConvertFrom-Json
        }
        catch [ArgumentException]
        {
            # The content must not be JSON.  We'll return the raw content result instead.
        }

        return $finalResult
    }
    catch
    {
        # We only know how to handle WebExceptions, which will either come in "pure" when running with -NoStatus,
        # or will come in as a RemoteException when running normally (since it's coming from the asynchronous Job).
        $ex = $null
        $message = $null
        $statusCode = $null
        $statusDescription = $null
        $correlationId = $null
        $innerMessage = $null

        if ($_.Exception -is [System.Net.WebException])
        {
            $ex = $_.Exception
            $message = $ex.Message
            $statusCode = $ex.Response.StatusCode.value__ # Note that value__ is not a typo.
            $statusDescription = $ex.Response.StatusDescription
            $innerMessage = $_.ErrorDetails.Message
            if ($ex.Response.Headers.Count -gt 0)
            {
                $correlationId = $ex.Response.Headers[$script:headerMSCorrelationId]
            }

        }
        elseif (($_.Exception -is [System.Management.Automation.RemoteException]) -and
                ($_.Exception.SerializedRemoteException.PSObject.TypeNames[0] -eq 'Deserialized.System.Management.Automation.RuntimeException'))
        {
            $ex = $_.Exception
            try
            {
                $deserialized = $ex.Message | ConvertFrom-Json
                $message = $deserialized.Message
                $statusCode = $deserialized.StatusCode
                $statusDescription = $deserialized.StatusDescription
                $innerMessage = $deserialized.InnerMessage
                $correlationId = $deserialized.CorrelationId
            }
            catch [System.ArgumentException]
            {
                # Will be thrown if $ex.Message isn't JSON content
                Write-Log $ex.Message -Level Error
                Set-TelemetryException -Exception $ex -ErrorBucket $errorBucket -Properties $localTelemetryProperties
                throw;
            }
        }
        else
        {
            Write-Log $_.Exception.Message -Level Error
            Set-TelemetryException -Exception $_.Exception -ErrorBucket $errorBucket -Properties $localTelemetryProperties
            throw;
        }

        $output = @()
        if (-not [string]::IsNullOrEmpty($statusCode))
        {
            $output += "$statusCode | $statusDescription"
        }

        $output += $message

        if (-not [string]::IsNullOrEmpty($innerMessage))
        {
            try
            {
                $innerMessageJson = ($innerMessage | ConvertFrom-Json)
                if ($innerMessageJson -is [String])
                {
                    $output += $innerMessageJson
                }
                else
                {
                    $output += "$($innerMessageJson.code) : $($innerMessageJson.message)"
                    if ($innerMessageJson.details)
                    {
                        $output += "$($innerMessageJson.details | Format-Table | Out-String)"
                    }
                }
            }
            catch [System.ArgumentException]
            {
                # Will be thrown if $innerMessage isn't JSON content
                $output += $innerMessage
            }
        }

        if (-not [String]::IsNullOrEmpty($correlationId))
        {
            Write-Log "$($script:headerMSCorrelationId): $correlationId" -Level Verbose
        }
       
        Set-TelemetryException -Exception $ex -ErrorBucket $errorBucket -Properties $localTelemetryProperties
        Write-Log $($output -join [Environment]::NewLine) -Level Error
        throw "Halt Execution"
    }
}

function Invoke-SBRestMethodMultipleResult
{
<#
    .SYNOPSIS
        A special-case wrapper around Invoke-SBRestMethod that understands GET URI's
        which support the 'top' and 'max' parameters.

    .DESCRIPTION
        A special-case wrapper around Invoke-SBRestMethod that understands GET URI's
        which support the 'top' and 'max' parameters.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER UriFragment
        The unique, tail-end, of the REST URI that indicates what Store REST action will
        be peformed.  This should *not* include the 'top' and 'max' parameters.  These
        will be automatically added as needed.

    .PARAMETER Description
        A friendly description of the operation being performed for logging and console
        display purposes.

    .PARAMETER MaxResults
        The number of results that should be returned in the query.
        Defaults to 100.

    .PARAMETER StartAt
        The 0-based index (of all apps within your account) that the returned
        results should start returning from.
        Defaults to 0.

    .PARAMETER AccessToken
        If provided, this will be used as the AccessToken for authentication with the
        REST Api as opposed to requesting a new one.

    .PARAMETER TelemetryEventName
        If provided, the successful execution of this REST command will be logged to telemetry
        using this event name.

    .PARAMETER TelemetryProperties
        If provided, the successful execution of this REST command will be logged to telemetry
        with these additional properties.  This will be silently ignored if TelemetryEventName
        is not provided as well.

    .PARAMETER TelemetryExceptionBucket
        If provided, any exception that occurs will be logged to telemetry using this bucket.
        It's possible that users will wish to log exceptions but not success (by providing
        TelemetryEventName) if this is being executed as part of a larger scenario.  If this
        isn't provided, but TelemetryEventName *is* provided, then TelemetryEventName will be
        used as the exception bucket value in the event of an exception.  If neither is specified,
        no bucket value will be used.

    .PARAMETER GetAll
        If this switch is specified, the cmdlet will automatically loop in batches
        to get all of the results for this operation.  Using this will ignore
        the provided value for -StartAt, but will use the value provided for
        -MaxResults as its per-query limit.
        WARNING: This might take a while depending on how many results there are.

    .PARAMETER NoStatus
        If this switch is specified, long-running commands will run on the main thread
        with no commandline status update.  When not specified, those commands run in
        the background, enabling the command prompt to provide status information.

    .EXAMPLE
        Invoke-SBRestMethodMultipleResult "applications" "Get apps"
        Gets the first 100 applications associated with this developer account,
        with the console window showing progress while awaiting the response
        from the REST request.

    .EXAMPLE
        Invoke-SBRestMethodMultipleResult "applications" "Get apps"" -NoStatus
        Gets the first 100 applications associated with this developer account,
        but the request happens in the foreground and there is no additional status
        shown to the user until a response is returned from the REST request.

    .EXAMPLE
        Invoke-SBRestMethodMultipleResult "applications" "Get apps" 500
        Gets the first 500 applications associated with this developer account,
        with the console window showing progress while awaiting the response
        from the REST request.

    .EXAMPLE
        Invoke-SBRestMethodMultipleResult "applications" "Get apps" 10 -StartAt 50
        Gets the next 10 apps in the developer account starting with the 51st app
        (since it's a 0-based index) with the console window showing progress while
        awaiting the response from the REST request.
#>
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="Methods called within here make use of PSShouldProcess, and the switch is passed on to them inherently.")]
    param(
        [Parameter(Mandatory)]
        [string] $UriFragment,

        [Parameter(Mandatory)]
        [string] $Description,

        [ValidateScript({if ($_ -gt 0) { $true } else { throw "Must be greater than 0." }})]
        [int] $MaxResults = 100,

        [ValidateScript({if ($_ -ge 0) { $true } else { throw "Must be greater than or equal to 0." }})]
        [int] $StartAt = 0,

        [string] $AccessToken = "",

        [string] $TelemetryEventName = $null,

        [hashtable] $TelemetryProperties = @{},

        [string] $TelemetryExceptionBucket = $null,

        [switch] $GetAll,

        [switch] $NoStatus
    )

    if ([System.String]::IsNullOrEmpty($AccessToken))
    {
        $AccessToken = Get-AccessToken -NoStatus:$NoStatus
    }

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $errorBucket = $TelemetryExceptionBucket
    if ([String]::IsNullOrEmpty($errorBucket))
    {
        $errorBucket = $TelemetryEventName
    }

    $finalResult = @()
    $currentStartAt = $StartAt

    try
    {
        do {
            $modifiedUriFragment = "${UriFragment}?top=$MaxResults&skip=$currentStartAt"
            $result = Invoke-SBRestMethod -UriFragment $modifiedUriFragment -Method Get -Description $description -AccessToken $AccessToken -TelemetryProperties $TelemetryProperties -TelemetryExceptionBucket $errorBucket -NoStatus:$NoStatus
            $finalResult += $result.value
            $currentStartAt += $MaxResults
        }
        until ((-not $GetAll) -or ($result.value.count -eq 0))

        # Record the telemetry for this event.
        $stopwatch.Stop()
        if (-not [String]::IsNullOrEmpty($TelemetryEventName))
        {
            $telemetryMetrics = @{ [StoreBrokerTelemetryMetric]::Duration = $stopwatch.Elapsed.TotalSeconds }
            Set-TelemetryEvent -EventName $TelemetryEventName -Properties $TelemetryProperties -Metrics $telemetryMetrics
        }

        return $finalResult
    }
    catch
    {
        throw
    }
}