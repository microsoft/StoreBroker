# Copyright (C) Microsoft Corporation.  All rights reserved.

# This will ensure that if an internal command throws an exception, we don't continue execution
$script:ErrorActionPreference = 'Stop'

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

# We'll cache the last acquired acccess token so that we don't have to always get it
# with every command within the same console session, provided that it hasn't expired.
$script:lastAccessToken = $null

# Indicates when $script:lastAccessToken has expired and must be refreshed
$script:lastAccessTokenExpirationDate = Get-Date

# Common keywords in the API Model used by StoreBroker
$script:keywordSpecificDate = 'SpecificDate'
$script:keywordManual = 'Manual'
$script:keywordImmediate = 'Immediate'
$script:keywordDefault = 'Default'
$script:keywordNoAction = 'NoAction'
$script:keywordPendingDelete = 'PendingDelete'
$script:keywordPendingCommit = 'PendingCommit'
$script:keywordRelease = 'Release'
$script:keywordPublished = 'Published'

# Special header that is used with the Submission API to track the type of client
# that is using the API
$script:headerClientName = 'X-ClientName'

# Special header added to Submission API responses that provides a unique ID
# that the Submission API team can use to trace back problems with a specific request.
$script:headerMSRequestId = 'MS-RequestId'

# Special headers that clients can add to their requests to make it easier to track the
# responses
$script:headerMSClientRequestId = 'MS-Client-RequestId'
$script:headerMSCorrelationId = 'MS-CorrelationId'

# Other headers that we may need for processing a response
$script:headerRetryAfter = 'Retry-After'
$script:headerLocation = 'Location'

Add-Type -TypeDefinition @"
   public enum StoreBrokerResourceType
   {
       FeatureAvailability,
       FeatureGroup,
       Flight,
       Group,
       Listing,
       ListingImage,
       ListingVideo,
       Package,
       PackageConfiguration,
       Rollout,
       Submission,
       SubmissionDetail
   }
"@

Add-Type -TypeDefinition @"
   public enum StoreBrokerFileState
   {
       PendingUpload,
       Uploaded,
       InProcessing,
       Processed,
       ProcessFailed
   }
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

    # Note, this doesn't currently work due to https://github.com/PowerShell/PSScriptAnalyzer/issues/698
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignment", "", Justification = "These are global variables and so are used elsewhere.")]
    param()

    # We only set their values if they don't already have values defined.
    # We use -ErrorAction Ignore during the Get-Variable check since it throws an exception
    # by default if the variable we're getting doesn't exist, and we just want the bool result.
    # SilentlyContinue would cause it to go into the global $Error array, Ignore prevents that as well.
    if (!(Get-Variable -Name SBDefaultProxyEndpoint -Scope Global -ValueOnly -ErrorAction Ignore))
    {
        $global:SBDefaultProxyEndpoint = $null
    }

    if (!(Get-Variable -Name SBAutoRetryErrorCodes -Scope Global -ValueOnly -ErrorAction Ignore))
    {
        $global:SBAutoRetryErrorCodes = @(429, 503)
    }

    if (!(Get-Variable -Name SBMaxAutoRetries -Scope Global -ValueOnly -ErrorAction Ignore))
    {
        $global:SBMaxAutoRetries = 5
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

    Write-Log -Message "[$($MyInvocation.MyCommand.Module.Version)] Executing: $($MyInvocation.Line.Trim())" -Level Verbose

    if ($UseProxy)
    {
        if ((-not [String]::IsNullOrWhiteSpace($TenantId)) -and (-not [String]::IsNullOrWhiteSpace($TenantName)))
        {
            $message = "You cannot set both TenantId and TenantName.  Only provide one of them."
            Write-Log -Message $message -Level Error
            throw $message
        }

        if ($null -ne $script:authCredential)
        {
            Write-Log -Message "Your cached credentials will no longer be used since you have enabled Proxy usage." -Level Warning
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
            Write-Log -Message "No credential provided.  Not changing current cached credential." -Level Error
        }
    }
    else
    {
        if ($PSCmdlet.ShouldProcess($Credential, "Cache credential"))
        {
            $script:authCredential = $Credential
        }
    }

    if ($PSCmdlet.ShouldProcess("", "Clear cached access token"))
    {
        $script:lastAccessToken = $null
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

    Write-Log -Message "[$($MyInvocation.MyCommand.Module.Version)] Executing: $($MyInvocation.Line.Trim())" -Level Verbose

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

    if ($PSCmdlet.ShouldProcess("", "Clear cached access token"))
    {
        $script:lastAccessToken = $null
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

        $newLineOutput = ($output -join [Environment]::NewLine)
        Write-Log -Message $newLineOutput -Level Error
        throw $newLineOutput
    }

    # Get our client id and secret, either from the cached credential or by prompting for them.
    $credential = $script:authCredential
    if ($null -eq $credential)
    {
        Write-Log -Message @(
            "Prompting for credentials.",
            "To avoid doing this every time, consider using Set-StoreBrokerAuthentication to cache the values for this session.")

        $credential = Get-Credential -Message "Enter your client id as your username, and your client secret as your password. ***To avoid getting this prompt every time, consider using Set-StoreBrokerAuthentication.***"
    }

    if ($null -eq $credential)
    {
        $output = "You must supply valid credentials (client id and secret) to use this module."
        Write-Log -Message  $output -Level Error
        throw $output
    }

    # If the cached access token hasn't expired, we can just use it.
    $numSecondsBeforeTokenExpiration = ($script:lastAccessTokenExpirationDate - (Get-Date)).TotalSeconds
    if ((-not [String]::IsNullOrWhiteSpace($script:lastAccessToken)) -and
        ($numSecondsBeforeTokenExpiration -gt 0))
    {
        return $script:lastAccessToken
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
        Write-Log -Message "Accessing [POST] $url" -Level Verbose

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
                    Wait-JobWithAnimation -Name $jobName -Description "Getting access token"
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
            # the same token across multiple commands to know when a new one is necessary.
            $script:accessTokenTimeoutSeconds = $response.expires_in - $script:accessTokenRefreshBufferSeconds
            $script:lastAccessTokenExpirationDate = (Get-Date).AddSeconds($script:accessTokenTimeoutSeconds)
            $script:lastAccessToken = $response.access_token
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

        $newLineOutput = ($output -join [Environment]::NewLine)
        Write-Log -Message $newLineOutput -Level Error
        throw $newLineOutput
    }
    catch [System.Management.Automation.RuntimeException]
    {
        # This type of exception occurs when NOT using -NoStatus
        $output = @()
        $output += "Be sure to check that your client id/secret are valid."
        $output += $_.Exception.Message
        if ($_.ErrorDetails.Message)
        {
            $message = ($_.ErrorDetails.Message | ConvertFrom-Json)
            $output += "$($message.code) : $($message.message)"
            if ($message.details)
            {
                $output += "$($message.details | Format-Table | Out-String)"
            }
        }

        $newLineOutput = ($output -join [Environment]::NewLine)
        Write-Log -Message $newLineOutput -Level Error
        throw $newLineOutput
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
            Write-Log -Message "Using PROXY INT service endpoint. Return to PROD by setting `$global:SBUseInt = `$false"
        }
        else
        {
            Write-Log -Message "Using PROXY PROD service endpoint" -Level Verbose
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
        Write-Log -Message "Using INT service endpoint. Return to PROD by setting `$global:SBUseInt = `$false"
        return $serviceEndpointInt
    }
    else
    {
        Write-Log -Message "Using PROD service endpoint" -Level Verbose
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
    $nugetPackageVersion = "9.0.0.0"
    $assemblyPackageTailDir = "WindowsAzure.Storage.9.0.0\lib\net45\"
    $assemblyName = "Microsoft.WindowsAzure.Storage.dll"

    return Get-NugetPackageDllPath -NugetPackageName $nugetPackageName -NugetPackageVersion $nugetPackageVersion -AssemblyPackageTailDirectory $assemblyPackageTailDir -AssemblyName $assemblyName -NoStatus:$NoStatus
}

function Get-AzureStorageDataMovementDllPath {
    <#
    .SYNOPSIS
        Makes sure that the Microsoft.WindowsAzure.Storage.DataMovement assembly
        is available on the machine, and returns the path to it.

    .DESCRIPTION
        Makes sure that the Microsoft.WindowsAzure.Storage.DataMovement assembly
        is available on the machine, and returns the path to it.

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
        Get-AzureStorageDataMovementDllPath

        Returns back the path to the assembly as found.  If the package has to
        be downloaded via nuget, the command prompt will show a time duration
        status counter while the package is being downloaded.

    .EXAMPLE
        Get-AzureStorageDataMovementDllPath -NoStatus

        Returns back the path to the assembly as found.  If the package has to
        be downloaded via nuget, the command prompt will appear to hang during
        this time.

    .OUTPUTS
        System.String - The path to the Microsoft.WindowsAzure.Storage.DataMovement.dll assembly.
#>
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification = "Methods called within here make use of PSShouldProcess, and the switch is passed on to them inherently.")]
    param(
        [switch] $NoStatus
    )

    $nugetPackageName = "Microsoft.Azure.Storage.DataMovement"
    $nugetPackageVersion = "0.7.1"
    $assemblyPackageTailDir = "Microsoft.Azure.Storage.DataMovement.0.7.1\lib\net45\"
    $assemblyName = "Microsoft.WindowsAzure.Storage.DataMovement.dll"

    return Get-NugetPackageDllPath -NugetPackageName $nugetPackageName -NugetPackageVersion $nugetPackageVersion -AssemblyPackageTailDirectory $assemblyPackageTailDir -AssemblyName $assemblyName -NoStatus:$NoStatus
}

function Set-StoreFile
{
<#
    .SYNOPSIS
        Uploads the package to the URL provided after calling New-ListingImage, New-ListingVideo,
        or New-ProductPackage.

    .DESCRIPTION
        Uploads the package to the URL provided after calling New-ListingImage, New-ListingVideo,
        or New-ProductPackage.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER FilePath
        The file that is to be uploaded.

    .PARAMETER UploadUrl
        The unique URL that was provided in a resource object that supports binary content.
        Supports Pipeline input.

    .PARAMETER NoStatus
        If this switch is specified, long-running commands will run on the main thread
        with no commandline status update.  When not specified, those commands run in
        the background, enabling the command prompt to provide status information.

    .EXAMPLE
        Upload-StoreFile "c:\foo.zip" "https://prodingestionbinaries1.blob.core.windows.net/ingestion/00000000-abcd-1234-0000-abcdefghijkl?sv=2014-02-14&sr=b&sig=WujGssA00/voXHaDgmaK1mpPn2JUkRPD/123gkAJdnI=&se=2015-12-17T12:58:14Z&sp=rwl"
        Uploads the package content for the application submission,
        with the console window showing progress while waiting for the upload to complete.

    .EXAMPLE
        Upload-StoreFile "c:\foo.zip" "https://prodingestionbinaries1.blob.core.windows.net/ingestion/00000000-abcd-1234-0000-abcdefghijkl?sv=2014-02-14&sr=b&sig=WujGssA00/voXHaDgmaK1mpPn2JUkRPD/123gkAJdnI=&se=2015-12-17T12:58:14Z&sp=rwl" -NoStatus
        Uploads the package content for the application submission,
        but the request happens in the foreground and there is no additional status
        shown to the user until the upload has completed.

    .NOTES
        This does not provide percentage completed status on the upload.  It is only
        able to provide the duration of the existing command (provided that you don't use
        the -NoStatus switch).

        This uses the "Set" verb to avoid Powershell import module warnings, but is then
        aliased to Upload-StoreFile to better express what it is actually doing.
#>
    [CmdletBinding(SupportsShouldProcess)]
    [Alias('Set-ApplicationSubmissionPackage')]
    [Alias('Set-SubmissionPackage')]
    [Alias('Upload-ApplicationSubmissionPackage')]
    [Alias('Upload-StoreFile')]
    [Alias('Upload-SubmissionPackage')]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({if (Test-Path -Path $_ -PathType Leaf) { $true } else { throw "$_ cannot be found." }})]
        [string] $FilePath,

        [Parameter(
            Mandatory,
            ValueFromPipeline=$True)]
        [string] $SasUri,

        [switch] $NoStatus
    )

    # Let's resolve this path to a full path so that it works with non-PowerShell commands (like the Azure module)
    $FilePath = Resolve-UnverifiedPath -Path $FilePath

    # Telemetry-related
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $telemetryProperties = @{ [StoreBrokerTelemetryProperty]::FilePath = (Get-PiiSafeString -PlainText $FilePath) }

    Write-Log -Message "[$($MyInvocation.MyCommand.Module.Version)] Executing: $($MyInvocation.Line.Trim())" -Level Verbose

    Write-Log -Message "Attempting to upload the file ($FilePath) to $SasUri..." -Level Verbose

    $azureStorageDll = Get-AzureStorageDllPath -NoStatus:$NoStatus
    $azureStorageDataMovementDll = Get-AzureStorageDataMovementDllPath -NoStatus:$NoStatus

    # We're going to be changing these, so we want to capture the current values so that we
    # we can restore them when we're done.
    $origDefaultConnectionLimit = [System.Net.ServicePointManager]::DefaultConnectionLimit
    $origExpect100Continue = [System.Net.ServicePointManager]::Expect100Continue

    try
    {
        if ($NoStatus)
        {
            # Recommendations per https://github.com/Azure/azure-storage-net-data-movement#best-practice
            [System.Net.ServicePointManager]::DefaultConnectionLimit = [Environment]::ProcessorCount * 8
            [System.Net.ServicePointManager]::Expect100Continue = $false

            $bytes = [System.IO.File]::ReadAllBytes($azureStorageDll)
            [System.Reflection.Assembly]::Load($bytes) | Out-Null

            $bytes = [System.IO.File]::ReadAllBytes($azureStorageDataMovementDll)
            [System.Reflection.Assembly]::Load($bytes) | Out-Null

            $uri = New-Object -TypeName System.Uri -ArgumentList $SasUri
            $cloudBlockBlob = New-Object -TypeName Microsoft.WindowsAzure.Storage.Blob.CloudBlockBlob -ArgumentList $uri

            if ($PSCmdlet.ShouldProcess($FilePath, "CloudBlockBlob.UploadFromFile"))
            {
                # We will run this async command synchronously within the console.
                $task = [Microsoft.WindowsAzure.Storage.DataMovement.TransferManager]::UploadAsync($FilePath, $cloudBlockBlob, $null, $null)
                $task.GetAwaiter().GetResult() | Out-Null
            }
        }
        else
        {
            $jobName = "Set-StoreFile-" + (Get-Date).ToFileTime().ToString()

            if ($PSCmdlet.ShouldProcess($jobName, "Start-Job"))
            {
                [scriptblock]$scriptBlock = {
                    param($SasUri, $FilePath, $AzureStorageDll, $AzureStorageDataMovementDll)

                    # Recommendations per https://github.com/Azure/azure-storage-net-data-movement#best-practice
                    [System.Net.ServicePointManager]::DefaultConnectionLimit = [Environment]::ProcessorCount * 8
                    [System.Net.ServicePointManager]::Expect100Continue = $false

                    $bytes = [System.IO.File]::ReadAllBytes($AzureStorageDll)
                    [System.Reflection.Assembly]::Load($bytes) | Out-Null

                    $bytes = [System.IO.File]::ReadAllBytes($AzureStorageDataMovementDll)
                    [System.Reflection.Assembly]::Load($bytes) | Out-Null

                    $uri = New-Object -TypeName System.Uri -ArgumentList $SasUri
                    $cloudBlockBlob = New-Object -TypeName Microsoft.WindowsAzure.Storage.Blob.CloudBlockBlob -ArgumentList $uri

                    # We will run this async command synchronously within the console.
                    $task = [Microsoft.WindowsAzure.Storage.DataMovement.TransferManager]::UploadAsync($FilePath, $cloudBlockBlob, $null, $null)
                    $task.GetAwaiter().GetResult() | Out-Null
                }

                $null = Start-Job -Name $jobName -ScriptBlock $scriptBlock -Arg @($SasUri, $FilePath, $azureStorageDll, $azureStorageDataMovementDll)

                if ($PSCmdlet.ShouldProcess($jobName, "Wait-JobWithAnimation"))
                {
                    Wait-JobWithAnimation -Name $jobName -Description "Uploading $FilePath"
                }

                if ($PSCmdlet.ShouldProcess($jobName, "Receive-Job"))
                {
                    $null = Receive-Job $jobName -AutoRemoveJob -Wait -ErrorAction SilentlyContinue -ErrorVariable remoteErrors
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
        Set-TelemetryEvent -EventName Set-StoreFile -Properties $telemetryProperties -Metrics $telemetryMetrics
    }
    catch [System.Management.Automation.RuntimeException]
    {
        # This type of exception occurs when NOT using -NoStatus

        $output = @()
        $output += $_.Exception.Message
        if ($_.ErrorDetails.Message)
        {
            $message = ($_.ErrorDetails.Message | ConvertFrom-Json)
            $output += "$($message.code) : $($message.message)"
            if ($message.details)
            {
                $output += "$($message.details | Format-Table | Out-String)"
            }
        }

        Set-TelemetryException -Exception $_.Exception -ErrorBucket Set-StoreFile -Properties $telemetryProperties
        $newLineOutput = ($output -join [Environment]::NewLine)
        Write-Log -Message $newLineOutput -Level Error
        throw $newLineOutput
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

        Set-TelemetryException -Exception $_.Exception -ErrorBucket Set-StoreFile -Properties $telemetryProperties
        $newLineOutput = ($output -join [Environment]::NewLine)
        Write-Log -Message $newLineOutput -Level Error
        throw $newLineOutput
    }
    finally
    {
        [System.Net.ServicePointManager]::DefaultConnectionLimit = $origDefaultConnectionLimit
        [System.Net.ServicePointManager]::Expect100Continue = $origExpect100Continue
    }

    Write-Log -Message "Successfully uploaded the file." -Level Verbose
}

function Get-StoreFile
{
<#
    .SYNOPSIS
        Downloads the file from the Azure SAS Uri provided.

    .DESCRIPTION
        Downloads the file from the Azure SAS Uri provided.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER SasUri
        The unique URL that was provided in a resource object that supports binary content.
        Supports Pipeline input.

    .PARAMETER FilePath
        The local path that you want to store the downloaded file.

    .PARAMETER NoStatus
        If this switch is specified, long-running commands will run on the main thread
        with no commandline status update.  When not specified, those commands run in
        the background, enabling the command prompt to provide status information.

    .EXAMPLE
        Get-StoreFile "https://prodingestionbinaries1.blob.core.windows.net/ingestion/00000000-abcd-1234-0000-abcdefghijkl?sv=2014-02-14&sr=b&sig=WujGssA00/voXHaDgmaK1mpPn2JUkRPD/123gkAJdnI=&se=2015-12-17T12:58:14Z&sp=rwl" "c:\foo.appx"
        Downloads the package to c:\foo.appx,
        with the console window showing progress while awaiting for the download to complete.

    .EXAMPLE
        Get-StoreFile "https://prodingestionbinaries1.blob.core.windows.net/ingestion/00000000-abcd-1234-0000-abcdefghijkl?sv=2014-02-14&sr=b&sig=WujGssA00/voXHaDgmaK1mpPn2JUkRPD/123gkAJdnI=&se=2015-12-17T12:58:14Z&sp=rwl" "c:\foo.appx" -NoStatus
        Downloads the package to c:\foo.appx,
        but the download happens in the foreground and there is no additional status
        shown to the user until the download completes.

    .NOTES
        This does not provide percentage completed status on the download.  It is only
        able to provide the duration of the existing command (provided that you don't use
        the -NoStatus switch).
#>
    [CmdletBinding(SupportsShouldProcess)]
    [Alias('Get-ApplicationSubmissionPackage')]
    [Alias('Get-SubmissionPackage')]
    param(
        [Parameter(
            Mandatory,
            ValueFromPipeline=$True)]
        [string] $SasUri,

        [Parameter(Mandatory)]
        [ValidateScript({if (Test-Path -Path $_ -PathType Leaf) { throw "$_ already exists. Choose a different destination name." } else { $true }})]
        [string] $FilePath,

        [switch] $NoStatus
    )

    # Let's resolve this path to a full path so that it works with non-PowerShell commands (like the Azure module)
    $FilePath = Resolve-UnverifiedPath -Path $FilePath

    # Telemetry-related
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $telemetryProperties = @{ [StoreBrokerTelemetryProperty]::FilePath = (Get-PiiSafeString -PlainText $FilePath) }

    Write-Log -Message "[$($MyInvocation.MyCommand.Module.Version)] Executing: $($MyInvocation.Line.Trim())" -Level Verbose

    Write-Log -Message "Attempting to download the contents of $SasUri to $FilePath..." -Level Verbose

    $azureStorageDll = Get-AzureStorageDllPath -NoStatus:$NoStatus
    $azureStorageDataMovementDll = Get-AzureStorageDataMovementDllPath -NoStatus:$NoStatus

    # We're going to be changing these, so we want to capture the current values so that we
    # we can restore them when we're done.
    $origDefaultConnectionLimit = [System.Net.ServicePointManager]::DefaultConnectionLimit
    $origExpect100Continue = [System.Net.ServicePointManager]::Expect100Continue

    try
    {
        if ($NoStatus)
        {
            # Recommendations per https://github.com/Azure/azure-storage-net-data-movement#best-practice
            [System.Net.ServicePointManager]::DefaultConnectionLimit = [Environment]::ProcessorCount * 8
            [System.Net.ServicePointManager]::Expect100Continue = $false

            $bytes = [System.IO.File]::ReadAllBytes($azureStorageDll)
            [System.Reflection.Assembly]::Load($bytes) | Out-Null

            $bytes = [System.IO.File]::ReadAllBytes($azureStorageDataMovementDll)
            [System.Reflection.Assembly]::Load($bytes) | Out-Null

            $uri = New-Object -TypeName System.Uri -ArgumentList $SasUri
            $cloudBlockBlob = New-Object -TypeName Microsoft.WindowsAzure.Storage.Blob.CloudBlockBlob -ArgumentList $uri

            # Unfortunately, due to the fact that the files are processed/modified by the API after Azure
            # has stored the MD5 hash, when we later download them, the files simply won't match the MD5 that was stored.
            $downloadOptions = New-Object -TypeName Microsoft.WindowsAzure.Storage.DataMovement.DownloadOptions
            $downloadOptions.DisableContentMD5Validation = $true

            if ($PSCmdlet.ShouldProcess($FilePath, "CloudBlockBlob.DownloadToFile"))
            {
                # We will run this async command synchronously within the console.
                $task = [Microsoft.WindowsAzure.Storage.DataMovement.TransferManager]::DownloadAsync($cloudBlockBlob, $FilePath, $downloadOptions, $null)
                $task.GetAwaiter().GetResult() | Out-Null
            }
        }
        else
        {
            $jobName = "Get-SubmissionPackage-" + (Get-Date).ToFileTime().ToString()

            if ($PSCmdlet.ShouldProcess($jobName, "Start-Job"))
            {
                [scriptblock]$scriptBlock = {
                    param($SasUri, $FilePath, $AzureStorageDll, $AzureStorageDataMovementDll)

                    # Recommendations per https://github.com/Azure/azure-storage-net-data-movement#best-practice
                    [System.Net.ServicePointManager]::DefaultConnectionLimit = [Environment]::ProcessorCount * 8
                    [System.Net.ServicePointManager]::Expect100Continue = $false

                    $bytes = [System.IO.File]::ReadAllBytes($AzureStorageDll)
                    [System.Reflection.Assembly]::Load($bytes) | Out-Null

                    $bytes = [System.IO.File]::ReadAllBytes($AzureStorageDataMovementDll)
                    [System.Reflection.Assembly]::Load($bytes) | Out-Null

                    $uri = New-Object -TypeName System.Uri -ArgumentList $SasUri
                    $cloudBlockBlob = New-Object -TypeName Microsoft.WindowsAzure.Storage.Blob.CloudBlockBlob -ArgumentList $uri

                    # Unfortunately, due to the fact that the files are processed/modified by the API after Azure
                    # has stored the MD5 hash, when we later download them, the files simply won't match the MD5 that was stored.
                    $downloadOptions = New-Object -TypeName Microsoft.WindowsAzure.Storage.DataMovement.DownloadOptions
                    $downloadOptions.DisableContentMD5Validation = $true

                    # We will run this async command synchronously within the console.
                    $task = [Microsoft.WindowsAzure.Storage.DataMovement.TransferManager]::DownloadAsync($cloudBlockBlob, $FilePath, $downloadOptions, $null)
                    $task.GetAwaiter().GetResult() | Out-Null
                }

                $null = Start-Job -Name $jobName -ScriptBlock $scriptBlock -Arg @($SasUri, $FilePath, $azureStorageDll, $azureStorageDataMovementDll)

                if ($PSCmdlet.ShouldProcess($jobName, "Wait-JobWithAnimation"))
                {
                    Wait-JobWithAnimation -Name $jobName -Description "Downloading content to $FilePath"
                }

                if ($PSCmdlet.ShouldProcess($jobName, "Receive-Job"))
                {
                    $null = Receive-Job $jobName -AutoRemoveJob -Wait -ErrorAction SilentlyContinue -ErrorVariable remoteErrors
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
        Set-TelemetryEvent -EventName Get-StoreFile -Properties $telemetryProperties -Metrics $telemetryMetrics
    }
    catch [System.Management.Automation.RuntimeException]
    {
        # This type of exception occurs when NOT using -NoStatus

        $output = @()
        $output += $_.Exception.Message
        if ($_.ErrorDetails.Message)
        {
            $message = ($_.ErrorDetails.Message | ConvertFrom-Json)
            $output += "$($message.code) : $($message.message)"
            if ($message.details)
            {
                $output += "$($message.details | Format-Table | Out-String)"
            }
        }

        Set-TelemetryException -Exception $_.Exception -ErrorBucket Get-StoreFile -Properties $telemetryProperties
        $newLineOutput = ($output -join [Environment]::NewLine)
        Write-Log -Message $newLineOutput -Level Error
        throw $newLineOutput
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
        $newLineOutput = ($output -join [Environment]::NewLine)
        Write-Log -Message $newLineOutput -Level Error
        throw $newLineOutput
    }
    finally
    {
        [System.Net.ServicePointManager]::DefaultConnectionLimit = $origDefaultConnectionLimit
        [System.Net.ServicePointManager]::Expect100Continue = $origExpect100Continue
    }

    Write-Log -Message "Successfully downloaded the file." -Level Verbose
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

    .PARAMETER PollingInterval
        The number of minutes that SubmissionMonitor should sleep before re-polling for
        status again.

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
        DefaultParametersetName="Flight")]
    [Alias('Start-ApplicationSubmissionMonitor')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="Methods called within here make use of PSShouldProcess, and the switch is passed on to them inherently.")]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({if ($_.Length -le 12) { throw "It looks like you supplied an AppId instead of a ProductId.  Use Get-Product with -AppId to find the ProductId for this AppId." } else { $true }})]
        [string] $ProductId,

        [Parameter(Mandatory)]
        [string] $SubmissionId,

        [Parameter(ParameterSetName='Flight')]
        [string] $FlightId,

        [Parameter(ParameterSetName='Sandbox')]
        [string] $SandboxId,

        [string[]] $EmailNotifyTo = @(),

        [int] $PollingInterval = 5,

        [string] $ClientRequestId,

        [string] $CorrelationId,

        [string] $AccessToken,

        [switch] $NoStatus,

        [switch] $PassThru
    )

    Write-Log -Message "[$($MyInvocation.MyCommand.Module.Version)] Executing: $($MyInvocation.Line.Trim())" -Level Verbose

    # Telemetry-related
    $telemetryProperties = @{
        [StoreBrokerTelemetryProperty]::ProductId = $ProductId
        [StoreBrokerTelemetryProperty]::SubmissionId = $SubmissionId
    }

    if (-not [String]::IsNullOrEmpty($FlightId)) { $telemetryProperties[[StoreBrokerTelemetryProperty]::FlightId] = $FlightId }
    if (-not [String]::IsNullOrEmpty($SandboxId)) { $telemetryProperties[[StoreBrokerTelemetryProperty]::SandboxId] = $SandboxId }
    $telemetryMetrics = @{ [StoreBrokerTelemetryMetric]::NumEmailAddresses = $EmailNotifyTo.Count }
    Set-TelemetryEvent -EventName Start-ApplicationSubmissionMonitor -Properties $telemetryProperties -Metrics $telemetryMetrics

    $shouldMonitor = $true
    $indentLength = 5

    $CorrelationId = Get-CorrelationId -CorrelationId $CorrelationId -Identifier $ProductId

    $commonParams = @{
        'ClientRequestId' = $ClientRequestId
        'CorrelationId' = $CorrelationId
        'NoStatus' = $NoStatus
    }

    if ($null -ne $PSBoundParameters['AccessToken'])
    {
        $commonParams.Add('AccessToken', $AccessToken)
    }

    # Get the info so we have it's name when we give the user updates.
    $product = Get-Product @commonParams -ProductId $ProductId
    $appId = ($product.externalIds | Where-Object { $_.type -eq 'StoreId' }).value
    $productName = $product.name
    $fullName = $productName

    $isSandboxSubmission = (-not [String]::IsNullOrEmpty($SandboxId))
    if ($isSandboxSubmission)
    {
        $fullName = "$productName | Sandbox $SandboxId"
    }

    # If this is monitoring a flight submission, let's also get the flight's friendly name for
    # those updates as well.
    $isFlightingSubmission = (-not [String]::IsNullOrEmpty($FlightId))
    if ($isFlightingSubmission)
    {
        $flight = Get-Flight @commonParams -ProductId $ProductId -FlightId $FlightId
        $flightName = $flight.name
        $fullName = "$productName | $flightName"
    }

    # Get the submission details so that we know how/when this submission will get published
    # once it has passed certification.
    $detail = Get-SubmissionDetail @commonParams -ProductId $ProductId -SubmissionId $SubmissionId

    $submission = $null

    $lastSubState = [StoreBrokerSubmissionSubState]::InDraft.ToString()

    while ($shouldMonitor)
    {
        try
        {
            $submission = Get-Submission @commonParams -ProductId $ProductId -SubmissionId $SubmissionId
            $report = Get-SubmissionReport @commonParams -ProductId $ProductId -SubmissionId $SubmissionId
            $validation = Get-SubmissionValidation @commonParams -ProductId $ProductId -SubmissionId $SubmissionId

            if (($submission.substate -ne $lastSubState) -or ($validation.Count -gt 0))
            {
                $lastSubState = $submission.substate

                $body = @()
                $body += ""
                $body += "ProductId             : $ProductId ($productName)"
                if ($isFlightingSubmission)
                {
                    $body += "FlightId              : $FlightId ($flightName)"
                }

                $body += "SubmissionId          : $SubmissionId"
                $body += "Friendly Name         : $($submission.friendlyName)"
                $body += "Submission State      : $($submission.state)"
                $body += "Submission State      : $lastSubState"
                $body += ""
                $body += "Validation Details    : {0}" -f $(if ($validation.count -eq 0) { "<None>" } else { "" })
                $body += $validation | Format-SimpleTableString -IndentationLevel $indentLength
                $body += ""
                $body += "Status Details        : {0}" -f $(if ($report.count -eq 0) { "<None>" } else { "" })
                $body += $report | Format-SimpleTableString -IndentationLevel $indentLength
                foreach ($entry in $report)
                {
                    $body += $(" " * $indentLength) + $(Get-Date -Date $entry.reportTimeInUtc -Format R) + ": $($entry.status) | $($entry.fileUri)"
                }

                $body += ""
                $body += "To view the full submission"
                $body += "---------------------------"
                $body += "Dev Portal URL"
                $body += "    https://dev.windows.com/en-us/dashboard/apps/$appId/submissions/$SubmissionId/"
                $body += "StoreBroker command"
                $body += "    Get-Submission -ProductId $productId -SubmissionId $SubmissionId"

                if ($validation.Count -gt 0)
                {
                    $body += ""
                    $body += "*** Your submission has validation errors that must be fixed.  Monitoring will now end."

                    $shouldMonitor = $false
                }

                $failedStates = @([StoreBrokerSubmissionSubState]::Failed, [StoreBrokerSubmissionSubState]::FailedInCertification)
                if ($lastSubState -in $failedStates)
                {
                    $body += ""
                    $body += "*** Your submission has entered a Failed state.  Monitoring will now end."

                    $shouldMonitor = $false
                }

                if ($lastSubState -eq [StoreBrokerSubmissionSubState]::ReadyToPublish)
                {
                    $body += ""
                    $body += "*** Your submission is ready for publishing.  Monitoring will now end."

                    $shouldMonitor = $false
                }

                if ($lastSubState -eq [StoreBrokerSubmissionSubState]::Published)
                {
                    $body += ""
                    $body += "*** Your submission has been published.  Monitoring will now end."

                    $shouldMonitor = $false
                }

                Write-Log -Message $body

                if ($EmailNotifyTo.Count -gt 0)
                {
                    $subject = "Status change for [$fullName] submission [$SubmissionId] : $lastSubState"
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
                Write-Log -Message "Got exception while trying to check on submission and will try again. The exception was:" -Exception $_ -Level Warning
            }
            else
            {
                throw
            }
        }

        if ($shouldMonitor)
        {
            $secondsBetweenChecks = $PollingInterval * 60
            Write-Log -Message "SubState is [$lastSubState]. Waiting $secondsBetweenChecks seconds before checking again..."
            Start-Sleep -Seconds $secondsBetweenChecks
        }
    }

    if ($PassThru)
    {
        return $submission
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
        The ID of the app that should be opened in the Store (in the "BigId" format).

    .PARAMETER ProductId
        The ID of the app that should be opened in the Store (in the ProductId format).

    .PARAMETER SubmissionId
        The ID of the submission to be viewed.

    .PARAMETER ShowFlight
        If provided, will show the flight UI as opposed to the flight submission UI.

    .EXAMPLE
        Open-DevPortal -AppId 0ABCDEF12345

        Opens a new tab in the default web browser to the page in the Dev Portal that displays
        the general status of the application.

    .EXAMPLE
        Open-DevPortal -AppId 0ABCDEF12345 -SubmissionId 1234567890123456789

        Opens a new tab in the default web browser to the page in the Dev Portal that displays
        the indicated submission.  Will work for both app and flight submissions.

    .EXAMPLE
        Open-DevPortal -AppId 0ABCDEF12345 -SubmissionId 1234567890123456789 -ShowFlight

        Opens a new tab in the default web browser to the page in the Dev Portal that displays
        the flight edit page (enabling you to change the name, flight groups and ranking).

    .EXAMPLE
        Open-DevPortal -ProductId 00012345678901234567

        Opens a new tab in the default web browser to the page in the Dev Portal that displays
        the general status of the application.

    .EXAMPLE
        Open-DevPortal -ProductId 00012345678901234567 -SubmissionId 1234567890123456789

        Opens a new tab in the default web browser to the page in the Dev Portal that displays
        the indicated submission.  Will work for both app and flight submissions.

    .EXAMPLE
        Open-DevPortal -ProductId 00012345678901234567 -SubmissionId 1234567890123456789 -ShowFlight

        Opens a new tab in the default web browser to the page in the Dev Portal that displays
        the flight edit page (enabling you to change the name, flight groups and ranking).
#>
    [CmdletBinding(DefaultParametersetName="Product")]
    param(
        [Parameter(
            Mandatory,
            ParameterSetName="App",
            Position=0)]
        [Parameter(
            Mandatory,
            ParameterSetName="AppSubmission",
            Position=0)]
        [ValidateScript({if ($_.Length -eq 12) { $true } else { throw "It looks like you supplied an ProductId instead of an AppId.  Use the -ProductId parameter with this value instead." }})]
        [string] $AppId,

        [Parameter(
            Mandatory,
            ParameterSetName="Product",
            Position=0)]
        [Parameter(
            Mandatory,
            ParameterSetName="ProductSubmission",
            Position=0)]
        [ValidateScript({if ($_.Length -le 12) { throw "It looks like you supplied an AppId instead of a ProductId.  Use the -AppId parameter with this value instead." } else { $true }})]
        [string] $ProductId,

        [Parameter(
            Mandatory,
            ParameterSetName="AppSubmission",
            Position=1)]
        [Parameter(
            Mandatory,
            ParameterSetName="ProductSubmission",
            Position=1)]
        [string] $SubmissionId,

        [Parameter(ParameterSetName="AppSubmission")]
        [Parameter(ParameterSetName="ProductSubmission")]
        [switch] $ShowFlight
    )

    # Telemetry-related
    $telemetryProperties = @{
        [StoreBrokerTelemetryProperty]::AppId = $AppId
        [StoreBrokerTelemetryProperty]::ProductId = $ProductId
        [StoreBrokerTelemetryProperty]::ShowSubmission = (-not [String]::IsNullOrEmpty($SubmissionId))
        [StoreBrokerTelemetryProperty]::ShowFlight = $ShowFlight
    }

    Set-TelemetryEvent -EventName Open-DevPortal -Properties $telemetryProperties

    if ([String]::IsNullOrEmpty($AppId))
    {
        $product = Get-Product -ProductId $ProductId
        $AppId = ($product.externalIds | Where-Object { $_.type -eq 'StoreId' }).value
    }

    Write-Log -Message "Opening Dev Portal in default web browser."

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

function Open-Store()
{
<#
.SYNOPSIS
    Opens the specified app in the Windows Store.

.DESCRIPTION
    Opens the specified app in the Windows Store.

    The Git repo for this module can be found here: https://aka.ms/StoreBroker

.PARAMETER AppId
    The ID of the app that should be opened in the Store (in the "BigId" format).

.PARAMETER ProductId
    The ID of the app that should be opened in the Store (in the ProductId format).

.PARAMETER Web
    If specified, opens the Web Store instead of the native Windows Store App.

.EXAMPLE
    Open-Store -AppId 0ABCDEF12345

    Opens the Windows Store app and navigates to the specified application.

.EXAMPLE
    Open-Store -ProductId 00012345678901234567

    Opens the Windows Store app and navigates to the specified application.

.EXAMPLE
    Open-Store -AppId 0ABCDEF12345 -Web

    Opens the user's browser to the specified app's Windows Store page.
#>
[CmdletBinding(DefaultParametersetName="ProductId")]
param(
        [Parameter(
            Mandatory,
            ParameterSetName="AppId")]
        [ValidateScript({if ($_.Length -eq 12) { $true } else { throw "It looks like you supplied an ProductId instead of an AppId.  Use the -ProductId parameter with this value instead." }})]
        [string] $AppId,

        [Parameter(
            Mandatory,
            ParameterSetName="ProductId")]
        [ValidateScript({if ($_.Length -le 12) { throw "It looks like you supplied an AppId instead of a ProductId.  Use the -AppId parameter with this value instead." } else { $true }})]
        [string] $ProductId,

        [switch] $Web
    )

    # Telemetry-related
    $telemetryProperties = @{
        [StoreBrokerTelemetryProperty]::AppId = $AppId
        [StoreBrokerTelemetryProperty]::ProductId = $ProductId
        [StoreBrokerTelemetryProperty]::Web = $Web
    }

    Set-TelemetryEvent -EventName Open-Store -Properties $telemetryProperties

    if ($null -eq $ProductId)
    {
        $product = Get-Product -AppId $AppId
        $ProductId = $product.id
    }

    $storeLinks = Get-ProductStoreLink -ProductId $ProductId

    $uri = $storeLinks.storeProtocolLink
    if ($Web)
    {
        $uri = $storeLinks.storeUri
    }

    Write-Log -Message "Launching $uri" -Level Verbose
    Start-Process -FilePath $uri
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

    .PARAMETER ExtendedResult
        If specified, the result will be a PSObject that contains the normal result, along with
        the response code and other relevant header detail content.

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
        that are returned in the response (specifically 'MS-ClientRequestId') for logging purposes, and
        Invoke-RestMethod drops those headers.
#>
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidGlobalVars", "", Justification="We use global variables sparingly and intentionally for module configuration, and employ a consistent naming convention.")]
    param(
        [Parameter(Mandatory)]
        [string] $UriFragment,

        [Parameter(Mandatory)]
        [ValidateSet('delete', 'get', 'post', 'put')]
        [string] $Method,

        [Parameter(Mandatory)]
        [string] $Description,

        [string] $Body = $null,

        [switch] $ExtendedResult,

        [string] $ClientRequestId,

        [string] $CorrelationId,

        [string] $AccessToken = "",

        [string] $TelemetryEventName = $null,

        [hashtable] $TelemetryProperties = @{},

        [string] $TelemetryExceptionBucket = $null,

        [switch] $NoStatus
    )

    $serviceEndpointVersion = "2.0"

    # Normalize our Uri fragment.  It might be coming from a method implemented here, or it might
    # be coming from the Location header in a previous response.  Either way, we don't want there
    # to be a leading "/"
    if ($UriFragment.StartsWith("/"))
    {
        $UriFragment = $UriFragment.Substring(1)
    }

    # The initial number of minutes we'll wait before retrying this command when we've hit an
    # error with a status code that is configured to auto-retry.  To reduce repeated contention, we
    # stagger the initial wait time (and thus, the resulting spread when it exponentially backs off).
    $retryDelayMin = [Math]::Round((Get-Random -Minimum 0.25 -Maximum 2.0), 2)
    $numRetries = 0

    # Telemetry-related
    $stopwatch = New-Object -TypeName System.Diagnostics.Stopwatch
    $localTelemetryProperties = @{ [StoreBrokerTelemetryProperty]::UriFragment = $UriFragment }
    $TelemetryProperties.Keys | ForEach-Object { $localTelemetryProperties[$_] = $TelemetryProperties[$_] }
    $errorBucket = $TelemetryExceptionBucket
    if ([String]::IsNullOrEmpty($errorBucket))
    {
        $errorBucket = $TelemetryEventName
    }

    do
    {
        if ([System.String]::IsNullOrEmpty($AccessToken))
        {
            # We get an AccessToken during each instance of the loop if one wasn't provided,
            # because an AccessToken has a limited lifetime, and we if we loop enough times,
            # one that was retrieved at the first iteration may no longer be valid during a
            # later iteration.  This might be a problem for callers that pass-in their own
            # AccessToken (since the looping is opaque to them), but in those situations,
            # they will eventually get a failure due to unauthorized access and a retry
            # would then help them recover.
            $AccessToken = Get-AccessToken -NoStatus:$NoStatus
        }

        # Since we have retry logic, we won't create a new stopwatch every time,
        # we'll just always continue the existing one...
        $stopwatch.Start()

        $serviceEndpoint = Get-ServiceEndpoint
        $uriPreface = "v$serviceEndpointVersion/my"
        $url = "$serviceEndpoint/$uriPreface/$UriFragment"

        # This scenario might happen if a client calls into here setting the UriFragment
        # to the value returned in the Location header from a previous request.
        if ($UriFragment.StartsWith($uriPreface))
        {
            $url = "$serviceEndpoint/$UriFragment"
        }

        $headers = @{"Authorization" = "Bearer $AccessToken"}
        $headers.Add($script:headerClientName, "StoreBroker v$($MyInvocation.MyCommand.Module.Version)")
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

        # Add any headers that clients can add to track specific requests
        if (-not [String]::IsNullOrWhiteSpace($ClientRequestId))
        {
            $headers.Add($script:headerMSClientRequestId, $ClientRequestId)
        }

        if (-not [String]::IsNullOrWhiteSpace($correlationId))
        {
            $headers.Add($script:headerMSCorrelationId, $CorrelationId)
        }

        try
        {
            Write-Log -Message $Description -Level Verbose
            Write-Log -Message "Accessing [$Method] $url [Timeout = $global:SBWebRequestTimeoutSec]" -Level Verbose

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
                        Write-Log -Message "Request includes a body." -Level Verbose
                    }

                    $result = Invoke-WebRequest @params
                    if ($Method -eq 'delete')
                    {
                        Write-Log -Message "Successfully removed." -Level Verbose
                    }
                }
            }
            else
            {
                $jobName = "Invoke-SBRestMethod-" + (Get-Date).ToFileTime().ToString()

                if ($PSCmdlet.ShouldProcess($jobName, "Start-Job"))
                {
                    [scriptblock]$scriptBlock = {
                        param($Url, $method, $Headers, $Body, $RequestIdHeaderName, $ClientRequestIdHeaderName, $CorrelationIdHeaderName, $TimeoutSec, $ScriptRootPath)

                        # We need to "dot invoke" Helpers.ps1 within the context of this script block since
                        # we're running in a different PowerShell process and need access to
                        # Get-HttpWebResponseContent
                        . (Join-Path -Path $ScriptRootPath -ChildPath 'Helpers.ps1')

                        # Because this is running in a different PowerShell process, we need to
                        # redefine this script variable (for use within the exception)
                        $script:headerMSRequestId = $RequestIdHeaderName
                        $script:headerMSClientRequestId = $ClientRequestIdHeaderName
                        $script:headerMSCorrelationId = $CorrelationIdHeaderName

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
                            Write-Log -Message "Request includes a body." -Level Verbose
                        }

                        try
                        {
                            Invoke-WebRequest @params
                        }
                        catch [System.Net.WebException]
                        {
                            # We need to access the RequestId header in the exception handling,
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
                            try
                            {
                                $ex.RawContent = Get-HttpWebResponseContent -WebResponse $_.Exception.Response
                            }
                            catch
                            {
                                Write-Log -Message "Unable to retrieve the raw HTTP Web Response:" -Exception $_ -Level Warning
                            }

                            if ($_.Exception.Response.Headers.Count -gt 0)
                            {
                                $ex.RequestId = $_.Exception.Response.Headers[$script:headerMSRequestId]
                                $ex.ClientRequestId = $_.Exception.Response.Headers[$script:headerMSClientRequestId]
                                $ex.CorrelationId = $_.Exception.Response.Headers[$script:headerMSCorrelationId]
                            }

                            throw ($ex | ConvertTo-Json -Depth 20)
                        }
                    }

                    $null = Start-Job -Name $jobName -ScriptBlock $scriptBlock -Arg @($url, $Method, $headers, $Body, $script:headerMSRequestId, $script:headerMSClientRequestId, $script:headerMSCorrelationId, $global:SBWebRequestTimeoutSec, $PSScriptRoot)

                    if ($PSCmdlet.ShouldProcess($jobName, "Wait-JobWithAnimation"))
                    {
                        Wait-JobWithAnimation -Name $jobName -Description $Description
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
                    Write-Log -Message "Successfully removed." -Level Verbose
                }
            }

            $requestId = $result.Headers[$script:headerMSRequestId]
            if (-not [String]::IsNullOrEmpty($requestId))
            {
                $localTelemetryProperties[$script:headerMSRequestId] = $requestId
                Write-Log -Message "$($script:headerMSRequestId) : $requestId" -Level Verbose
            }

            $returnedClientRequestId = $result.Headers[$script:headerMSClientRequestId]
            if (-not [String]::IsNullOrEmpty($returnedClientRequestId))
            {
                $localTelemetryProperties[$script:headerMSClientRequestId] = $returnedClientRequestId
                Write-Log -Message "$($script:headerMSClientRequestId) : $returnedClientRequestId" -Level Verbose
            }

            $returnedCorrelationId = $result.Headers[$script:headerMSCorrelationId]
            if (-not [String]::IsNullOrEmpty($returnedCorrelationId))
            {
                $localTelemetryProperties[$script:headerMSCorrelationId] = $returnedCorrelationId
                Write-Log -Message "$($script:headerMSCorrelationId) : $returnedCorrelationId" -Level Verbose
            }

            $statusCode = $result.StatusCode

            $retryAfterHeaderValue = 0
            if ($result.Headers.ContainsKey($script:headerRetryAfter))
            {
                $retryAfterHeaderValue = $result.Headers[$script:headerRetryAfter]
            }

            $locationHeaderValue = $null
            if ($result.Headers.ContainsKey($script:headerLocation))
            {
                $locationHeaderValue = $result.Headers[$script:headerLocation]
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
                # The content must not be JSON (which is a legitimate situation).  We'll return the raw content result instead.
                # We do this unnecessary assignment to avoid PSScriptAnalyzer's PSAvoidUsingEmptyCatchBlock.
                $finalResult = $finalResult
            }

            if ($ExtendedResult)
            {
                $finalResultEx = @{
                    'Result' = $finalResult
                    'StatusCode' = $statusCode
                    'RetryAfter' = $retryAfterHeaderValue
                    'Location' = $locationHeaderValue
                }

                return ([PSCustomObject] $finalResultEx)
            }
            else
            {
                return $finalResult
            }
        }
        catch
        {
            # We only know how to handle WebExceptions, which will either come in "pure" when running with -NoStatus,
            # or will come in as a RemoteException when running normally (since it's coming from the asynchronous Job).
            $ex = $null
            $message = $null
            $statusCode = $null
            $statusDescription = $null
            $requestId = $null
            $returnedClientRequestId = $null
            $returnedCorrelationId = $null
            $innerMessage = $null
            $rawContent = $null

            if ($_.Exception -is [System.Net.WebException])
            {
                $ex = $_.Exception
                $message = $_.Exception.Message
                $statusCode = $ex.Response.StatusCode.value__ # Note that value__ is not a typo.
                $statusDescription = $ex.Response.StatusDescription
                $innerMessage = $_.ErrorDetails.Message
                try
                {
                    $rawContent = Get-HttpWebResponseContent -WebResponse $ex.Response
                }
                catch
                {
                    Write-Log -Message "Unable to retrieve the raw HTTP Web Response:" -Exception $_ -Level Warning
                }

                if ($ex.Response.Headers.Count -gt 0)
                {
                    $requestId = $ex.Response.Headers[$script:headerMSRequestId]
                    $returnedClientRequestId = $ex.Response.Headers[$script:headerMSClientRequestId]
                    $returnedCorrelationId = $ex.Response.Headers[$script:headerMSCorrelationId]
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
                    $requestId = $deserialized.RequestId
                    $returnedClientRequestId = $deserialized.ClientRequestId
                    $returnedCorrelationId = $deserialized.CorrelationId
                    $rawContent = $deserialized.RawContent
                }
                catch [System.ArgumentException]
                {
                    # Will be thrown if $ex.Message isn't JSON content
                    Write-Log -Exception $_ -Level Error
                    Set-TelemetryException -Exception $ex -ErrorBucket $errorBucket -Properties $localTelemetryProperties
                    throw
                }
            }
            else
            {
                Write-Log -Exception $_ -Level Error
                Set-TelemetryException -Exception $_.Exception -ErrorBucket $errorBucket -Properties $localTelemetryProperties
                throw
            }

            $output = @()
            if (-not [string]::IsNullOrEmpty($statusCode))
            {
                $output += "$statusCode | $($statusDescription.Trim())"
            }

            $output += $message

            if (-not [string]::IsNullOrEmpty($innerMessage))
            {
                try
                {
                    $innerMessageJson = ($innerMessage | ConvertFrom-Json)
                    if ($innerMessageJson -is [String])
                    {
                        $output += $innerMessageJson.Trim()
                    }
                    elseif (-not [String]::IsNullOrWhiteSpace($innerMessageJson.message))
                    {
                        $output += "$($innerMessageJson.code) : $($innerMessageJson.message.Trim())"
                        if ($innerMessageJson.details)
                        {
                            $output += "$($innerMessageJson.details | Format-Table | Out-String)"
                        }
                    }
                    else
                    {
                        # In this case, it's probably not a normal message from the API
                        # (possibly it's an invalid client secret error)
                        $output += ($innerMessageJson | Out-String)
                    }
                }
                catch [System.ArgumentException]
                {
                    # Will be thrown if $innerMessage isn't JSON content
                    $output += $innerMessage.Trim()
                }
            }

            # It's possible that the API returned JSON content in its error response.
            # If it did, we want to extract the "activityId" property from it for
            # logging purposes in order to assist the Submission API team with
            # post-mortem debugging.
            if (-not [String]::IsNullOrWhiteSpace($rawContent))
            {
                try
                {
                    $rawContentJson = $rawContent | ConvertFrom-Json
                    $activityId = $rawContentJson.activityId
                    if (-not [String]::IsNullOrWhiteSpace($activityId))
                    {
                        $output += "ActivityId: $activityId"
                    }
                    else
                    {
                        # The property we wanted wasn't there, but we'll capture the full
                        # content for logging purposes anyway since it's rare for an API
                        # error to return additional content -- seeing it might be helpful.
                        $output += $rawContent
                    }
                }
                catch [ArgumentException]
                {
                    # The content must not be JSON.
                    # We'll capture it for logging purposes anyway since it's rare for an API
                    # error to return additional content -- seeing it might be helpful.
                    $output += $rawContent
                }
            }

            if (-not [String]::IsNullOrEmpty($requestId))
            {
                $localTelemetryProperties[$script:headerMSRequestId] = $requestId
                $message = $script:headerMSRequestId + ': ' + $requestId
                $output += $message
                Write-Log -Message $message -Level Verbose
            }

            if (-not [String]::IsNullOrEmpty($returnedClientRequestId))
            {
                $localTelemetryProperties[$script:headerMSClientRequestId] = $returnedClientRequestId
                $message = $script:headerMSClientRequestId + ': ' + $returnedClientRequestId
                $output += $message
                Write-Log -Message $message -Level Verbose
            }

            if (-not [String]::IsNullOrEmpty($returnedCorrelationId))
            {
                $localTelemetryProperties[$script:headerMSCorrelationId] = $returnedCorrelationId
                $message = $script:headerMSCorrelationId + ': ' + $returnedCorrelationId
                $output += $message
                Write-Log -Message $message -Level Verbose
            }

            $newLineOutput = ($output -join [Environment]::NewLine)
            if ($statusCode -in $global:SBAutoRetryErrorCodes)
            {
                if ($numRetries -ge $global:SBMaxAutoRetries)
                {
                    Write-Log -Message $newLineOutput -Level Error
                    Write-Log -Message "Maximum retries for request has been reached ($global:SBMaxAutoRetries).  Will now fail." -Level Error
                    Set-TelemetryException -Exception $ex -ErrorBucket $errorBucket -Properties $localTelemetryProperties
                    throw $newLineOutput
                }
                else
                {
                    $numRetries++
                    $localTelemetryProperties[[StoreBrokerTelemetryProperty]::NumRetries] = $numRetries
                    $localTelemetryProperties[[StoreBrokerTelemetryProperty]::RetryStatusCode] = $statusCode
                    Write-Log -Message $newLineOutput -Level Warning
                    Write-Log -Message "This status code ($statusCode) is configured to auto-retry (via `$global:SBAutoRetryErrorCodes).  StoreBroker will auto-retry (attempt #$numRetries) in $retryDelayMin minute(s). Sleeping..." -Level Warning
                    Start-Sleep -Seconds ($retryDelayMin * 60)
                    $retryDelayMin = $retryDelayMin * 2 # Exponential sleep increase for next retry
                    continue # let's get back to the start of the loop again, no need to process anything further in this catch
                }
            }
            else
            {
                Write-Log -Message $newLineOutput -Level Error
                Set-TelemetryException -Exception $ex -ErrorBucket $errorBucket -Properties $localTelemetryProperties
                throw $newLineOutput
            }

            throw # ensure that any inner exception that was thrown continues to propagate
        }
    }
    while ($true) # infinite loop for retrying is ok, since we early return in the postive case, and throw an exception in the failure case.
}

function Invoke-SBRestMethodMultipleResultOld
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

function Invoke-SBRestMethodMultipleResult
{
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="Methods called within here make use of PSShouldProcess, and the switch is passed on to them inherently.")]
    param(
        [Parameter(Mandatory)]
        [string] $UriFragment,

        [Parameter(Mandatory)]
        [string] $Description,

        [string] $ClientRequestId,

        [string] $CorrelationId,

        [string] $AccessToken = "",

        [string] $TelemetryEventName = $null,

        [hashtable] $TelemetryProperties = @{},

        [string] $TelemetryExceptionBucket = $null,

        [switch] $SinglePage,

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

    $currentDescription = $Description
    $nextLink = $UriFragment

    try
    {
        do {
            $params = @{
                "UriFragment" = $nextLink
                "Method" = 'Get'
                "Description" = $currentDescription
                "ClientRequestId" = $ClientRequestId
                "CorrelationId" = $CorrelationId
                "AccessToken" = $AccessToken
                "TelemetryProperties" = $telemetryProperties
                "TelemetryExceptionBucket" = $errorBucket
                "NoStatus" = $NoStatus
            }

            $result = Invoke-SBRestMethod @params
            $finalResult += $result.value
            $nextLink = $result.nextLink
            $currentDescription = "$Description (getting additional results)"
        }
        until ($SinglePage -or ([String]::IsNullOrWhiteSpace($nextLink)))

        # Record the telemetry for this event.
        $stopwatch.Stop()
        if (-not [String]::IsNullOrEmpty($TelemetryEventName))
        {
            $telemetryMetrics = @{ [StoreBrokerTelemetryMetric]::Duration = $stopwatch.Elapsed.TotalSeconds }
            Set-TelemetryEvent -EventName $TelemetryEventName -Properties $TelemetryProperties -Metrics $telemetryMetrics
        }

        # Ensure we're always returning our results as an array, even if there is a single result.
        return @($finalResult)
    }
    catch
    {
        throw
    }
}

function Test-ResourceType
{
    [CmdletBinding()]
    param(
        [PSCustomObject] $Object,

        [StoreBrokerResourceType] $ResourceType
    )

    $resourceTypeString = $ResourceType.ToString()
    if (($null -ne $Object) -and ($Object.resourceType -ne $resourceTypeString))
    {
        $message = "Expected an object with a resourceType of [$resourceTypeString], got [$($Object.resourceType)]."
        Write-Log -Message $message -Level Error
        throw $message
    }
}

function Get-CorrelationId
{
    [CmdletBinding()]
    param(
        [string] $CorrelationId,

        [string] $Identifier
    )

    # We'll provide a unique value if one wasn't provided to us already.
    if ([String]::IsNullOrWhiteSpace($CorrelationId))
    {
        return "$((Get-Date).ToString("yyyyMMddssmm.ffff"))-$Identifier"
    }

    return $CorrelationId
}
