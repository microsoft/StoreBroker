# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

# Singleton telemetry client. Don't directly access this though....always get it
# by calling Get-TelemetryClient to ensure that the singleton is properly initialized.
$script:SBTelemetryClient = $null

Add-Type -TypeDefinition @"
   public enum StoreBrokerTelemetryProperty
   {
      AddPackages,
      AppId,
      AppName,
      AppxVersion,
      Auto,
      AutoSubmit,
      ClientRequestId,
      CorrelationId,
      DayOfWeek,
      ErrorBucket,
      ExistingPackageRolloutAction,
      FeatureAvailabilityId,
      FeatureGroupId,
      FilePath,
      FlightId,
      Force,
      GetDetail,
      GetReport,
      GetValidation,
      HasAudience,
      HResult,
      IapId,
      ImageId,
      IncludeMarketStates,
      IncludePricing,
      IncludeTrial,
      IsAutoPromote,
      IsEnabled,
      IsMandatoryUpdate,
      IsManualPublish,
      IsMinimalObject,
      IsSeekEnabled,
      JsonPath,
      LanguageCode,
      MediaRootPath,
      Message,
      Name,
      NumRetries,
      PackageId,
      PackageConfigurationId,
      PackagePath,
      PackageRolloutPercentage,
      PackageRootPath,
      Percentage,
      ProductAvailabilityId,
      ProductId,
      ProductType,
      PropertyId,
      ProvidedCertificationNotes,
      ProvidedSubmissionData,
      RedundantPackagesToKeep,
      RelativeRank,
      RemoveOnly,
      ReplacePackages,
      RequestId,
      ResourceType,
      RetryStatusCode,
      RevisionToken,
      SandboxId,
      Scope,
      SeekEnabled,
      ShouldOverridePackageLogos,
      ShowFlight,
      ShowSubmission,
      SingleQuery,
      SourceFilePath,
      SpecifiedType,
      State,
      SubmissionId,
      TargetPublishMode,
      Type,
      Orientation,
      UpdateAppProperties,
      UpdateCertificationNotes,
      UpdateGamingOptions,
      UpdateImagesAndCaptions,
      UpdateListingText,
      UpdatePackages,
      UpdatePricingAndAvailability,
      UpdateProperties,
      UpdatePublishMode,
      UpdatePublishModeAndVisibility,
      UpdateVideos,
      UsingObject,
      UriFragment,
      UserName,
      Version,
      VideoId,
      Visibility,
      WaitForCompletion,
      WaitUntilReady,
      Web,
      ZipPath
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

function Get-ApplicationInsightsDllPath
{
<#
    .SYNOPSIS
        Makes sure that the Microsoft.ApplicationInsights.dll assembly is available
        on the machine, and returns the path to it.

    .DESCRIPTION
        Makes sure that the Microsoft.ApplicationInsights.dll assembly is available
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
        Get-ApplicationInsightsDllPath

        Returns back the path to the assembly as found.  If the package has to
        be downloaded via nuget, the command prompt will show a time duration
        status counter while the package is being downloaded.

    .EXAMPLE
        Get-ApplicationInsightsDllPath -NoStatus

        Returns back the path to the assembly as found.  If the package has to
        be downloaded via nuget, the command prompt will appear to hang during
        this time.

    .OUTPUTS
        System.String - The path to the Microsoft.ApplicationInsights.dll assembly.
#>
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="Methods called within here make use of PSShouldProcess, and the switch is passed on to them inherently.")]
    param(
        [switch] $NoStatus
    )

    $nugetPackageName = "Microsoft.ApplicationInsights"
    $nugetPackageVersion = "2.0.1"
    $assemblyPackageTailDir = "Microsoft.ApplicationInsights.2.0.1\lib\net45"
    $assemblyName = "Microsoft.ApplicationInsights.dll"

    return Get-NugetPackageDllPath -NugetPackageName $nugetPackageName -NugetPackageVersion $nugetPackageVersion -AssemblyPackageTailDirectory $assemblyPackageTailDir -AssemblyName $assemblyName -NoStatus:$NoStatus
}

function Get-DiagnosticsTracingDllPath
{
<#
    .SYNOPSIS
        Makes sure that the Microsoft.Diagnostics.Tracing.EventSource.dll assembly is available
        on the machine, and returns the path to it.

    .DESCRIPTION
        Makes sure that the Microsoft.Diagnostics.Tracing.EventSource.dll assembly is available
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
        Get-DiagnosticsTracingDllPath

        Returns back the path to the assembly as found.  If the package has to
        be downloaded via nuget, the command prompt will show a time duration
        status counter while the package is being downloaded.

    .EXAMPLE
        Get-DiagnosticsTracingDllPath -NoStatus

        Returns back the path to the assembly as found.  If the package has to
        be downloaded via nuget, the command prompt will appear to hang during
        this time.

    .OUTPUTS
        System.String - The path to the Microsoft.ApplicationInsights.dll assembly.
#>
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="Methods called within here make use of PSShouldProcess, and the switch is passed on to them inherently.")]
    param(
        [switch] $NoStatus
    )

    $nugetPackageName = "Microsoft.Diagnostics.Tracing.EventSource.Redist"
    $nugetPackageVersion = "1.1.24"
    $assemblyPackageTailDir = "Microsoft.Diagnostics.Tracing.EventSource.Redist.1.1.24\lib\net35"
    $assemblyName = "Microsoft.Diagnostics.Tracing.EventSource.dll"

    return Get-NugetPackageDllPath -NugetPackageName $nugetPackageName -NugetPackageVersion $nugetPackageVersion -AssemblyPackageTailDirectory $assemblyPackageTailDir -AssemblyName $assemblyName -NoStatus:$NoStatus
}

function Get-ThreadingTasksDllPath
{
<#
    .SYNOPSIS
        Makes sure that the Microsoft.Threading.Tasks.dll assembly is available
        on the machine, and returns the path to it.

    .DESCRIPTION
        Makes sure that the Microsoft.Threading.Tasks.dll assembly is available
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
        Get-ThreadingTasksDllPath

        Returns back the path to the assembly as found.  If the package has to
        be downloaded via nuget, the command prompt will show a time duration
        status counter while the package is being downloaded.

    .EXAMPLE
        Get-ThreadingTasksDllPath -NoStatus

        Returns back the path to the assembly as found.  If the package has to
        be downloaded via nuget, the command prompt will appear to hang during
        this time.

    .OUTPUTS
        System.String - The path to the Microsoft.ApplicationInsights.dll assembly.
#>
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="Methods called within here make use of PSShouldProcess, and the switch is passed on to them inherently.")]
    param(
        [switch] $NoStatus
    )

    $nugetPackageName = "Microsoft.Bcl.Async"
    $nugetPackageVersion = "1.0.168.0"
    $assemblyPackageTailDir = "Microsoft.Bcl.Async.1.0.168\lib\net40"
    $assemblyName = "Microsoft.Threading.Tasks.dll"

    return Get-NugetPackageDllPath -NugetPackageName $nugetPackageName -NugetPackageVersion $nugetPackageVersion -AssemblyPackageTailDirectory $assemblyPackageTailDir -AssemblyName $assemblyName -NoStatus:$NoStatus
}

function Get-TelemetryClient
{
<#
    .SYNOPSIS
        Returns back the singleton instance of the Application Insights TelemetryClient for
        this module.

    .DESCRIPTION
        Returns back the singleton instance of the Application Insights TelemetryClient for
        this module.

        If the singleton hasn't been initialized yet, this will ensure all dependenty assemblies
        are available on the machine, create the client and initialize its properties.

        This will first look for the dependent assemblies in the module's script directory.

        Next it will look for the assemblies in the location defined by
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
        Get-TelemetryClient

        Returns back the singleton instance to the TelemetryClient for the module.
        If any nuget packages have to be downloaded in order to load the TelemetryClient, the
        command prompt will show a time duration status counter during the download process.

    .EXAMPLE
        Get-TelemetryClient -NoStatus

        Returns back the singleton instance to the TelemetryClient for the module.
        If any nuget packages have to be downloaded in order to load the TelemetryClient, the
        command prompt will appear to hang during this time.

    .OUTPUTS
        Microsoft.ApplicationInsights.TelemetryClient
#>
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidGlobalVars", "", Justification="We use global variables sparingly and intentionally for module configuration, and employ a consistent naming convention.")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="Methods called within here make use of PSShouldProcess, and the switch is passed on to them inherently.")]
    param(
        [switch] $NoStatus
    )

    if ($null -eq $script:SBTelemetryClient)
    {
        Write-Log -Message "Telemetry is currently enabled.  It can be disabled by setting ""`$global:SBDisableTelemetry = `$true"". Refer to USAGE.md#telemetry for more information."
        Write-Log -Message "Initializing telemetry client." -Level Verbose

        $dlls = @(
                    (Get-ThreadingTasksDllPath -NoStatus:$NoStatus),
                    (Get-DiagnosticsTracingDllPath -NoStatus:$NoStatus),
                    (Get-ApplicationInsightsDllPath -NoStatus:$NoStatus)
        )

        foreach ($dll in $dlls)
        {
            $bytes = [System.IO.File]::ReadAllBytes($dll)
            [System.Reflection.Assembly]::Load($bytes) | Out-Null
        }

        $username = Get-PiiSafeString -PlainText $env:USERNAME

        $script:SBTelemetryClient = New-Object Microsoft.ApplicationInsights.TelemetryClient
        $script:SBTelemetryClient.InstrumentationKey = $global:SBApplicationInsightsKey
        $script:SBTelemetryClient.Context.User.Id = $username
        $script:SBTelemetryClient.Context.Session.Id = [System.GUID]::NewGuid().ToString()
        $script:SBTelemetryClient.Context.Properties[[StoreBrokerTelemetryProperty]::Username] = $username
        $script:SBTelemetryClient.Context.Properties[[StoreBrokerTelemetryProperty]::DayOfWeek] = (Get-Date).DayOfWeek
        $script:SBTelemetryClient.Context.Component.Version = $MyInvocation.MyCommand.Module.Version.ToString()
    }

    return $script:SBTelemetryClient
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

    .PARAMETER NoStatus
        If this switch is specified, long-running commands will run on the main thread
        with no commandline status update.  When not specified, those commands run in
        the background, enabling the command prompt to provide status information.

    .EXAMPLE
        Set-TelemetryEvent "zFooTest1"

        Posts a "zFooTest1" event with the default set of properties and metrics.  If the telemetry
        client needs to be created to accomplish this, and the required assemblies are not available
        on the local machine, the download status will be presented at the command prompt.

    .EXAMPLE
        Set-TelemetryEvent "zFooTest1" @{"Prop1" = "Value1"}

        Posts a "zFooTest1" event with the default set of properties and metrics along with an
        additional property named "Prop1" with a value of "Value1".  If the telemetry client
        needs to be created to accomplish this, and the required assemblies are not available
        on the local machine, the download status will be presented at the command prompt.

    .EXAMPLE
        Set-TelemetryEvent "zFooTest1" -NoStatus

        Posts a "zFooTest1" event with the default set of properties and metrics.  If the telemetry
        client needs to be created to accomplish this, and the required assemblies are not available
        on the local machine, the command prompt will appear to hang while they are downloaded.

    .NOTES
        Because of the short-running nature of this module, we always "flush" the events as soon
        as they have been posted to ensure that they make it to Application Insights.
#>
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidGlobalVars", "", Justification="We use global variables sparingly and intentionally for module configuration, and employ a consistent naming convention.")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="Methods called within here make use of PSShouldProcess, and the switch is passed on to them inherently.")]
    param(
        [Parameter(Mandatory)]
        [string] $EventName,

        [hashtable] $Properties = @{},

        [hashtable] $Metrics = @{},

        [switch] $NoStatus
    )

    if ($global:SBDisableTelemetry)
    {
        Write-Log -Message "Telemetry has been disabled via `$global:SBDisableTelemetry. Skipping reporting event [$EventName]." -Level Verbose
        return
    }

    Write-Log -Message "[$($MyInvocation.MyCommand.Module.Version)] Executing: $($MyInvocation.Line.Trim())" -Level Verbose

    try
    {
        $telemetryClient = Get-TelemetryClient -NoStatus:$NoStatus

        $propertiesDictionary = New-Object 'System.Collections.Generic.Dictionary[string, string]'
        $propertiesDictionary[[StoreBrokerTelemetryProperty]::DayOfWeek] = (Get-Date).DayOfWeek
        $Properties.Keys | ForEach-Object { $propertiesDictionary[$_] = $Properties[$_] }

        $metricsDictionary = New-Object 'System.Collections.Generic.Dictionary[string, double]'
        $Metrics.Keys | ForEach-Object { $metricsDictionary[$_] = $Metrics[$_] }

        $telemetryClient.TrackEvent($EventName, $propertiesDictionary, $metricsDictionary);

        # Flushing should increase the chance of success in uploading telemetry logs
        Flush-TelemetryClient -NoStatus:$NoStatus
    }
    catch
    {
        # Telemetry should be best-effort.  Failures while trying to handle telemetry should not
        # cause exceptions in the app itself.
        Write-Log -Message "Set-TelemetryEvent failed:" -Exception $_ -Level Error
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

    .PARAMETER NoFlush
        It's not recommended to use this unless the exception is coming from Flush-TelemetryClient.
        By default, every time a new exception is logged, the telemetry client will be flushed
        to ensure that the event is published to the Application Insights.  Use of this switch
        prevents that automatic flushing (helpful in the scenario where the exception occurred
        when trying to do the actual Flush).

    .PARAMETER NoStatus
        If this switch is specified, long-running commands will run on the main thread
        with no commandline status update.  When not specified, those commands run in
        the background, enabling the command prompt to provide status information.

    .EXAMPLE
        Set-TelemetryException $_

        Used within the context of a catch statement, this will post the exception that just
        occurred, along with a default set of properties.  If the telemetry client needs to be
        created to accomplish this, and the required assemblies are not available on the local
        machine, the download status will be presented at the command prompt.

    .EXAMPLE
        Set-TelemetryException $_ -NoStatus

        Used within the context of a catch statement, this will post the exception that just
        occurred, along with a default set of properties.  If the telemetry client needs to be
        created to accomplish this, and the required assemblies are not available on the local
        machine, the command prompt will appear to hang while they are downloaded.

    .NOTES
        Because of the short-running nature of this module, we always "flush" the events as soon
        as they have been posted to ensure that they make it to Application Insights.
#>
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidGlobalVars", "", Justification="We use global variables sparingly and intentionally for module configuration, and employ a consistent naming convention.")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="Methods called within here make use of PSShouldProcess, and the switch is passed on to them inherently.")]
    param(
        [Parameter(Mandatory)]
        [System.Exception] $Exception,

        [string] $ErrorBucket,

        [hashtable] $Properties = @{},

        [switch] $NoFlush,

        [switch] $NoStatus
    )

    if ($global:SBDisableTelemetry)
    {
        Write-Log -Message "Telemetry has been disabled via `$global:SBDisableTelemetry. Skipping reporting exception." -Level Verbose
        return
    }

    Write-Log -Message "[$($MyInvocation.MyCommand.Module.Version)] Executing: $($MyInvocation.Line.Trim())" -Level Verbose

    try
    {
        $telemetryClient = Get-TelemetryClient -NoStatus:$NoStatus

        $propertiesDictionary = New-Object 'System.Collections.Generic.Dictionary[string,string]'
        $propertiesDictionary[[StoreBrokerTelemetryProperty]::Message] = $Exception.Message
        $propertiesDictionary[[StoreBrokerTelemetryProperty]::HResult] = "0x{0}" -f [Convert]::ToString($Exception.HResult, 16)
        $Properties.Keys | ForEach-Object { $propertiesDictionary[$_] = $Properties[$_] }

        if (-not [String]::IsNullOrWhiteSpace($ErrorBucket))
        {
            $propertiesDictionary[[StoreBrokerTelemetryProperty]::ErrorBucket] = $ErrorBucket
        }

        $telemetryClient.TrackException($Exception, $propertiesDictionary);

        # Flushing should increase the chance of success in uploading telemetry logs
        if (-not $NoFlush)
        {
            Flush-TelemetryClient -NoStatus:$NoStatus
        }
    }
    catch
    {
        # Telemetry should be best-effort.  Failures while trying to handle telemetry should not
        # cause exceptions in the app itself.
        Write-Log -Message "Set-TelemetryException failed:" -Exception $_ -Level Error
    }
}

function Flush-TelemetryClient
{
<#
    .SYNOPSIS
        Flushes the buffer of stored telemetry events to the configured Applications Insights instance.

    .DESCRIPTION
        Flushes the buffer of stored telemetry events to the configured Applications Insights instance.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER NoStatus
        If this switch is specified, long-running commands will run on the main thread
        with no commandline status update.  When not specified, those commands run in
        the background, enabling the command prompt to provide status information.

    .EXAMPLE
        Flush-TelemetryClient

        Attempts to push all buffered telemetry events for this telemetry client immediately to
        Application Insights.  If the telemetry client needs to be created to accomplish this,
        and the required assemblies are not available on the local machine, the download status
        will be presented at the command prompt.

    .EXAMPLE
        Flush-TelemetryClient -NoStatus

        Attempts to push all buffered telemetry events for this telemetry client immediately to
        Application Insights.  If the telemetry client needs to be created to accomplish this,
        and the required assemblies are not available on the local machine, the command prompt
        will appear to hang while they are downloaded.
#>
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidGlobalVars", "", Justification="We use global variables sparingly and intentionally for module configuration, and employ a consistent naming convention.")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseApprovedVerbs", "", Justification="Internal-only helper method.  Matches the internal method that is called.")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="Methods called within here make use of PSShouldProcess, and the switch is passed on to them inherently.")]
    param(
        [switch] $NoStatus
    )

    if ($global:SBDisableTelemetry)
    {
        Write-Log -Message "Telemetry has been disabled via `$global:SBDisableTelemetry. Skipping flushing of the telemetry client." -Level Verbose
        return
    }

    Write-Log -Message "[$($MyInvocation.MyCommand.Module.Version)] Executing: $($MyInvocation.Line.Trim())" -Level Verbose

    $telemetryClient = Get-TelemetryClient -NoStatus:$NoStatus

    try
    {
        $telemetryClient.Flush()
    }
    catch [System.Net.WebException]
    {
        Write-Log -Message "Encountered exception while trying to flush telemetry events:" -Exception $_ -Level Warning

        Set-TelemetryException -Exception ($_.Exception) -ErrorBucket "TelemetryFlush" -NoFlush -NoStatus:$NoStatus
    }
    catch
    {
        # Any other scenario is one that we want to identify and fix so that we don't miss telemetry
        Write-Log -Level Warning -Exception $_ -Message @(
            "Encountered a problem while trying to record telemetry events.",
            "This is non-fatal, but it would be helpful if you could report this problem",
            "to the StoreBroker team for further investigation:")
    }
}
