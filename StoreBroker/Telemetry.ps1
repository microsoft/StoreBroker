# Copyright (C) Microsoft Corporation.  All rights reserved.

# Singleton. Don't directly access this though....always get it
# by calling Get-BaseTelemetryEvent to ensure that it has been initialized and that you're always
# getting a fresh copy.
$script:SBBaseTelemetryEvent = $null

Add-Type -TypeDefinition @"
   public enum StoreBrokerTelemetryProperty
   {
      AddPackages,
      AppId,
      AppName,
      AppxVersion,
      AutoCommit,
      DayOfWeek,
      ErrorBucket,
      ExistingPackageRolloutAction,
      FlightId,
      Force,
      HResult,
      IapId,
      IsMandatoryUpdate,
      Message,
      NumRetries,
      PackagePath,
      PackageRolloutPercentage,
      ProductId,
      ProductType,
      ReplacePackages,
      RetryStatusCode,
      ShowFlight,
      ShowSubmission,
      SourceFilePath,
      SubmissionId,
      UpdateAppProperties,
      UpdateGamingOptions,
      UpdateListings,
      UpdateNotesForCertification,
      UpdatePricingAndAvailability,
      UpdateProperties,
      UpdatePublishMode,
      UpdatePublishModeAndVisibility,
      UpdateTrailers,
      UriFragment,
      UserName,
      Web,
   }
"@

Add-Type -TypeDefinition @"
   public enum StoreBrokerTelemetryMetric
   {
      Duration,
      NumEmailAddresses,
   }
"@

function Initialize-TelemetryGlobalVariables
{
<#
    .SYNOPSIS
        Initializes the global variables that are "owned" by the Telemetry script file.

    .DESCRIPTION
        Initializes the global variables that are "owned" by the Telemetry script file.
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
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "", Justification="We are initializing multiple variables.")]

    # Note, this doesn't currently work due to https://github.com/PowerShell/PSScriptAnalyzer/issues/698
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignment", "", Justification = "These are global variables and so are used elsewhere.")]
    param()

    # We only set their values if they don't already have values defined.
    # We use -ErrorAction Ignore during the Get-Variable check since it throws an exception
    # by default if the variable we're getting doesn't exist, and we just want the bool result.
    # SilentlyContinue would cause it to go into the global $Error array, Ignore prevents that as well.
    if (!(Get-Variable -Name SBDisableTelemetry -Scope Global -ValueOnly -ErrorAction Ignore))
    {
        $global:SBDisableTelemetry = $false
    }

    if (!(Get-Variable -Name SBDisablePiiProtection -Scope Global -ValueOnly -ErrorAction Ignore))
    {
        $global:SBDisablePiiProtection = $false
    }

    if (!(Get-Variable -Name SBApplicationInsightsKey -Scope Global -ValueOnly -ErrorAction Ignore))
    {
        $global:SBApplicationInsightsKey = '4cdaa89f-33c5-46b4-ba5a-3befb5d8fe01'
    }
}

# We need to be sure to call this explicitly so that the global variables get initialized.
Initialize-TelemetryGlobalVariables

function Get-PiiSafeString
{
<#
    .SYNOPSIS
        If PII protection is enabled, returns back an SHA512-hashed value for the specified string,
        otherwise returns back the original string, untouched.

    .SYNOPSIS
        If PII protection is enabled, returns back an SHA512-hashed value for the specified string,
        otherwise returns back the original string, untouched.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER PlainText
        The plain text that contains PII that may need to be protected.

    .EXAMPLE
        Get-PiiSafeString -PlainText "Hello World"

        Returns back the string "B10A8DB164E0754105B7A99BE72E3FE5" which respresents
        the SHA512 hash of "Hello World", but only if $global:SBDisablePiiProtection is $false.
        If it's $true, "Hello World" will be returned.

    .OUTPUTS
        System.String - A SHA512 hash of PlainText will be returned if $global:SBDisablePiiProtection
                        is $false, otherwise PlainText will be returned untouched.
#>
    [CmdletBinding()]
    [OutputType([String])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidGlobalVars", "", Justification="We use global variables sparingly and intentionally for module configuration, and employ a consistent naming convention.")]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [AllowEmptyString()]
        [string] $PlainText
    )

    if ($global:SBDisablePiiProtection)
    {
        return $PlainText
    }
    else
    {
        return (Get-SHA512Hash -PlainText $PlainText)
    }
}

function Get-BaseTelemetryEvent
{
    <#
    .SYNOPSIS
        Returns back the base object for an Application Insights telemetry event.

    .DESCRIPTION
        Returns back the base object for an Application Insights telemetry event.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .EXAMPLE
        Get-BaseTelemetryEvent

        Returns back a base telemetry event, populated with the minimum properties necessary
        to correctly report up to this project's telemetry.  Callers can then add on to the
        event as nececessary.

    .OUTPUTS
        [PSCustomObject]
#>
    [CmdletBinding()]
    param()

    if ($null -eq $script:SBBaseTelemetryEvent)
    {
        Write-Log -Message "Telemetry is currently enabled.  It can be disabled by setting ""`$global:SBDisableTelemetry = `$true"". Refer to USAGE.md#telemetry for more information."

        $username = Get-PiiSafeString -PlainText $env:USERNAME

        $script:SBBaseTelemetryEvent = [PSCustomObject] @{
            'name' = 'Microsoft.ApplicationInsights.66d83c523070489b886b09860e05e78a.Event'
            'time' = (Get-Date).ToUniversalTime().ToString("O")
            'iKey' = $global:SBApplicationInsightsKey
            'tags' = [PSCustomObject] @{
                'ai.user.id' = $username
                'ai.session.id' = [System.GUID]::NewGuid().ToString()
                'ai.application.ver' = $MyInvocation.MyCommand.Module.Version.ToString()
                'ai.internal.sdkVersion' = '2.0.1.33027' # The version this schema was based off of.
            }

            'data' = [PSCustomObject] @{
                'baseType' = 'EventData'
                'baseData' = [PSCustomObject] @{
                    'ver' = 2
                    'properties' = [PSCustomObject] @{
                        'DayOfWeek' = (Get-Date).DayOfWeek.ToString()
                        'Username' = $username
                    }
                }
            }
        }
    }

    return $script:SBBaseTelemetryEvent.PSObject.Copy() # Get a new instance, not a reference
}

function Invoke-SendTelemetryEvent
{
<#
    .SYNOPSIS
        Sends an event to Application Insights directly using its REST API.

    .DESCRIPTION
        Sends an event to Application Insights directly using its REST API.

        A very heavy wrapper around Invoke-WebRequest that understands Application Insights and
        how to perform its requests with and without console status updates.  It also
        understands how to parse and handle errors from the REST calls.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER TelemetryEvent
        The raw object representing the event data to send to Application Insights.

    .OUTPUTS
        [PSCustomObject] - The result of the REST operation, in whatever form it comes in.

    .NOTES
        This mirrors Invoke-SBRestMethod extensively, however the error handling is slightly
        different.  There wasn't a clear way to refactor the code to make both of these
        Invoke-* methods share a common base code.  Leaving this as-is to make this file
        easier to share out with other PowerShell projects.
#>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidGlobalVars", "", Justification="We use global variables sparingly and intentionally for module configuration, and employ a consistent naming convention.")]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject] $TelemetryEvent
    )

    $jsonConversionDepth = 20 # Seems like it should be more than sufficient
    $uri = 'https://dc.services.visualstudio.com/v2/track'
    $method = 'POST'
    $headers = @{'Content-Type' = 'application/json; charset=UTF-8'}

    $body = ConvertTo-Json -InputObject $TelemetryEvent -Depth $jsonConversionDepth -Compress
    $bodyAsBytes = [System.Text.Encoding]::UTF8.GetBytes($body)

    try
    {
        Write-Log -Message "Sending telemetry event data to $uri [Timeout = $global:SBWebRequestTimeoutSec]" -Level Verbose

        $params = @{}
        $params.Add("Uri", $uri)
        $params.Add("Method", $method)
        $params.Add("Headers", $headers)
        $params.Add("UseDefaultCredentials", $true)
        $params.Add("UseBasicParsing", $true)
        $params.Add("TimeoutSec", $global:SBWebRequestTimeoutSec)
        $params.Add("Body", $bodyAsBytes)

        # Disable Progress Bar in function scope during Invoke-WebRequest
        $ProgressPreference = 'SilentlyContinue'

        return Invoke-WebRequest @params
    }
    catch
    {
        $ex = $null
        $message = $null
        $statusCode = $null
        $statusDescription = $null
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
        }
        else
        {
            Write-Log -Exception $_ -Level Error
            throw
        }

        $output = @()
        $output += $message

        if (-not [string]::IsNullOrEmpty($statusCode))
        {
            $output += "$statusCode | $($statusDescription.Trim())"
        }

        if (-not [string]::IsNullOrEmpty($innerMessage))
        {
            try
            {
                $innerMessageJson = ($innerMessage | ConvertFrom-Json)
                if ($innerMessageJson -is [String])
                {
                    $output += $innerMessageJson.Trim()
                }
                elseif (-not [String]::IsNullOrWhiteSpace($innerMessageJson.itemsReceived))
                {
                    $output += "Items Received: $($innerMessageJson.itemsReceived)"
                    $output += "Items Accepted: $($innerMessageJson.itemsAccepted)"
                    if ($innerMessageJson.errors.Count -gt 0)
                    {
                        $output += "Errors:"
                        $output += ($innerMessageJson.errors | Format-Table | Out-String)
                    }
                }
                else
                {
                    # In this case, it's probably not a normal message from the API
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
        if (-not [String]::IsNullOrWhiteSpace($rawContent))
        {
            $output += $rawContent
        }

        $output += "Original body: $body"
        $newLineOutput = ($output -join [Environment]::NewLine)
        Write-Log -Message $newLineOutput -Level Error
        throw $newLineOutput
    }
}

function Set-TelemetryEvent
{
<#
    .SYNOPSIS
        Posts a new telemetry event for this module to the configured Applications Insights instance.

    .DESCRIPTION
        Posts a new telemetry event for this module to the configured Applications Insights instance.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER EventName
        The name of the event that has occurred.

    .PARAMETER Properties
        A collection of name/value pairs (string/string) that should be associated with this event.

    .PARAMETER Metrics
        A collection of name/value pair metrics (string/double) that should be associated with
        this event.

    .EXAMPLE
        Set-TelemetryEvent "zFooTest1"

        Posts a "zFooTest1" event with the default set of properties and metrics.

    .EXAMPLE
        Set-TelemetryEvent "zFooTest1" @{"Prop1" = "Value1"}

        Posts a "zFooTest1" event with the default set of properties and metrics along with an
        additional property named "Prop1" with a value of "Value1".

    .NOTES
        Because of the short-running nature of this module, we always "flush" the events as soon
        as they have been posted to ensure that they make it to Application Insights.
#>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification='Function is not state changing')]
    param(
        [Parameter(Mandatory)]
        [string] $EventName,

        [hashtable] $Properties = @{},

        [hashtable] $Metrics = @{}
    )

    if ($global:SBDisableTelemetry)
    {
        Write-Log -Message "Telemetry has been disabled via `$global:SBDisableTelemetry. Skipping reporting event." -Level Verbose
        return
    }

    Write-InvocationLog -ExcludeParameter @('Properties', 'Metrics')

    try
    {
        $telemetryEvent = Get-BaseTelemetryEvent
        Add-Member -InputObject $telemetryEvent.data.baseData -Name 'name' -Value $EventName -MemberType NoteProperty -Force

        # Properties
        foreach ($property in $Properties.GetEnumerator())
        {
            Add-Member -InputObject $telemetryEvent.data.baseData.properties -Name $property.Key -Value $property.Value -MemberType NoteProperty -Force
        }

        # Measurements
        if ($Metrics.Count -gt 0)
        {
            $measurements = @{}
            foreach ($metric in $Metrics.GetEnumerator())
            {
                $measurements[$metric.Key] = $metric.Value
            }

            Add-Member -InputObject $telemetryEvent.data.baseData -Name 'measurements' -Value ([PSCustomObject] $measurements) -MemberType NoteProperty -Force
        }

        $null = Invoke-SendTelemetryEvent -TelemetryEvent $telemetryEvent
    }
    catch
    {
        Write-Log -Level Warning -Message @(
            "Encountered a problem while trying to record telemetry events.",
            "This is non-fatal, but it would be helpful if you could report this problem",
            "to the StoreBroker team for further investigation:"
            "",
            $_.Exception)
    }
}

function Set-TelemetryException
{
<#
    .SYNOPSIS
        Posts a new telemetry event to the configured Application Insights instance indicating
        that an exception occurred in this this module.

    .DESCRIPTION
        Posts a new telemetry event to the configured Application Insights instance indicating
        that an exception occurred in this this module.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER Exception
        The exception that just occurred.

    .PARAMETER ErrorBucket
        A property to be added to the Exception being logged to make it easier to filter to
        exceptions resulting from similar scenarios.

    .PARAMETER Properties
        Additional properties that the caller may wish to be associated with this exception.

    .EXAMPLE
        Set-TelemetryException $_

        Used within the context of a catch statement, this will post the exception that just
        occurred, along with a default set of properties.

    .NOTES
        Because of the short-running nature of this module, we always "flush" the events as soon
        as they have been posted to ensure that they make it to Application Insights.
#>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification='Function is not state changing.')]
    param(
        [Parameter(Mandatory)]
        [System.Exception] $Exception,

        [string] $ErrorBucket,

        [hashtable] $Properties = @{}
    )

    if ($global:SBDisableTelemetry)
    {
        Write-Log -Message "Telemetry has been disabled via `$global:SBDisableTelemetry. Skipping reporting event." -Level Verbose
        return
    }

    Write-InvocationLog -ExcludeParameter @('Exception', 'Properties')

    try
    {
        $telemetryEvent = Get-BaseTelemetryEvent

        $telemetryEvent.data.baseType = 'ExceptionData'
        Add-Member -InputObject $telemetryEvent.data.baseData -Name 'handledAt' -Value 'UserCode' -MemberType NoteProperty -Force

        # Properties
        if (-not [String]::IsNullOrWhiteSpace($ErrorBucket))
        {
            Add-Member -InputObject $telemetryEvent.data.baseData.properties -Name 'ErrorBucket' -Value $ErrorBucket -MemberType NoteProperty -Force
        }

        Add-Member -InputObject $telemetryEvent.data.baseData.properties -Name 'Message' -Value $Exception.Message -MemberType NoteProperty -Force
        Add-Member -InputObject $telemetryEvent.data.baseData.properties -Name 'HResult' -Value ("0x{0}" -f [Convert]::ToString($Exception.HResult, 16)) -MemberType NoteProperty -Force
        foreach ($property in $Properties.GetEnumerator())
        {
            Add-Member -InputObject $telemetryEvent.data.baseData.properties -Name $property.Key -Value $property.Value -MemberType NoteProperty -Force
        }

        # Re-create the stack.  We'll start with what's in Invocation Info since it's already
        # been broken down for us (although it doesn't supply the method name).
        $parsedStack = @(
            [PSCustomObject] @{
                'assembly' = $MyInvocation.MyCommand.Module.Name
                'method' = '<unknown>'
                'fileName' = $Exception.ErrorRecord.InvocationInfo.ScriptName
                'level' = 0
                'line' = $Exception.ErrorRecord.InvocationInfo.ScriptLineNumber
            }
        )

        # And then we'll try to parse ErrorRecord's ScriptStackTrace and make this as useful
        # as possible.
        $stackFrames = $Exception.ErrorRecord.ScriptStackTrace -split [Environment]::NewLine
        for ($i = 0; $i -lt $stackFrames.Count; $i++)
        {
            $frame = $stackFrames[$i]
            if ($frame -match '^at (.+), (.+): line (\d+)$')
            {
                $parsedStack +=  [PSCustomObject] @{
                    'assembly' = $MyInvocation.MyCommand.Module.Name
                    'method' = $Matches[1]
                    'fileName' = $Matches[2]
                    'level' = $i + 1
                    'line' = $Matches[3]
                }
            }
        }

        # Finally, we'll build up the Exception data object.
        $exceptionData = [PSCustomObject] @{
            'id' = (Get-Date).ToFileTime()
            'typeName' = $Exception.GetType().FullName
            'message' = $Exception.Message
            'hasFullStack' = $true
            'parsedStack' = $parsedStack
        }

        Add-Member -InputObject $telemetryEvent.data.baseData -Name 'exceptions' -Value @($exceptionData) -MemberType NoteProperty -Force
        $null = Invoke-SendTelemetryEvent -TelemetryEvent $telemetryEvent
    }
    catch
    {
        Write-Log -Level Warning -Message @(
            "Encountered a problem while trying to record telemetry events.",
            "This is non-fatal, but it would be helpful if you could report this problem",
            "to the StoreBroker team for further investigation:",
            "",
            $_.Exception)
    }
}
