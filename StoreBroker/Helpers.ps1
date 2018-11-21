# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

function Initialize-HelpersGlobalVariables
{
<#
    .SYNOPSIS
        Initializes the global variables that are "owned" by the Helpers script file.

    .DESCRIPTION
        Initializes the global variables that are "owned" by the Helpers script file.
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
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignment", "", Justification="These are global variables and so are used elsewhere.")]
    param()

    # We only set their values if they don't already have values defined.
    # We use -ErrorAction Ignore during the Get-Variable check since it throws an exception
    # by default if the variable we're getting doesn't exist, and we just want the bool result.
    # SilentlyContinue would cause it to go into the global $Error array, Ignore prevents that as well.
    if (!(Get-Variable -Name SBLoggingEnabled -Scope Global -ValueOnly -ErrorAction Ignore))
    {
        $global:SBLoggingEnabled = $true
    }

    if (!(Get-Variable -Name SBLogPath -Scope Global -ValueOnly -ErrorAction Ignore))
    {
        $documentsFolder = [System.Environment]::GetFolderPath('MyDocuments')
        if (-not [System.String]::IsNullOrEmpty($documentsFolder))
        {
            $global:SBLogPath = Join-Path -Path $documentsFolder -ChildPath 'StoreBroker.log'
        }
        else
        {
            $global:SBLoggingEnabled = $false
        }
    }

    if (!(Get-Variable -Name SBShouldLogPid -Scope Global -ValueOnly -ErrorAction Ignore))
    {
        $global:SBShouldLogPid = $false
    }

    if (!(Get-Variable -Name SBNotifyDefaultDomain -Scope Global -ValueOnly -ErrorAction Ignore))
    {
        $global:SBNotifyDefaultDomain = $null
    }

    if (!(Get-Variable -Name SBNotifySmtpServer -Scope Global -ValueOnly -ErrorAction Ignore))
    {
        $global:SBNotifySmtpServer = $null
    }

    if (!(Get-Variable -Name SBNotifyDefaultFrom -Scope Global -ValueOnly -ErrorAction Ignore))
    {
        $global:SBNotifyDefaultFrom = $env:username
    }

    if (!(Get-Variable -Name SBNotifyCredential -Scope Global -ValueOnly -ErrorAction Ignore))
    {
        $global:SBNotifyCredential = [PSCredential]$null
    }

    if (!(Get-Variable -Name SBUseUTC -Scope Global -ValueOnly -ErrorAction Ignore))
    {
        $global:SBUseUTC = $false
    }

    if (!(Get-Variable -Name SBWebRequestTimeoutSec -Scope Global -ValueOnly -ErrorAction Ignore))
    {
        $global:SBWebRequestTimeoutSec = 0
    }
}

# We need to be sure to call this explicitly so that the global variables get initialized.
Initialize-HelpersGlobalVariables

function Wait-JobWithAnimation
{
<#
    .SYNOPSIS
        Waits for a background job to complete by showing a cursor and elapsed time.

    .DESCRIPTION
        Waits for a background job to complete by showing a cursor and elapsed time.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER Name
        The name of the job(s) that we are waiting to complete.

    .PARAMETER Description
        The text displayed next to the spinning cursor, explaining what the job is doing.

    .PARAMETER StopAllOnAnyFailure
        Will call Stop-Job on any jobs still Running if any of the specified jobs entered
        the Failed state.

    .EXAMPLE
        Wait-JobWithAnimation Job1
        Waits for a job named "Job1" to exit the "Running" state.  While waiting, shows
        a waiting cursor and the elapsed time.

    .NOTES
        This is not a stand-in replacement for Wait-Job.  It does not provide the full
        set of configuration options that Wait-Job does.
#>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [string[]] $Name,

        [string] $Description = "",

        [switch] $StopAllOnAnyFailure
    )

    [System.Collections.ArrayList]$runningJobs = $Name
    $allJobsCompleted = $true
    $hasFailedJob = $false

    $animationFrames = '|','/','-','\'
    $framesPerSecond = 9

    # We'll wrap the description (if provided) in brackets for display purposes.
    if ($Description -ne "")
    {
        $Description = "[$Description]"
    }

    $iteration = 0
    while ($runningJobs.Count -gt 0)
    {
        # We'll run into issues if we try to modify the same collection we're iterating over
        $jobsToCheck = $runningJobs.ToArray()
        foreach ($jobName in $jobsToCheck)
        {
            $state = (Get-Job -Name $jobName).state
            if ($state -ne 'Running')
            {
                $runningJobs.Remove($jobName)

                if ($state -ne 'Completed')
                {
                    $allJobsCompleted = $false
                }

                if ($state -eq 'Failed')
                {
                    $hasFailedJob = $true
                    if ($StopAllOnAnyFailure)
                    {
                        break
                    }
                }
            }
        }

        if ($hasFailedJob -and $StopAllOnAnyFailure)
        {
            foreach ($jobName in $runningJobs)
            {
                Stop-Job -Name $jobName
            }

            $runingJobs.Clear()
        }

        Write-InteractiveHost "`r$($animationFrames[$($iteration % $($animationFrames.Length))])  Elapsed: $([int]($iteration / $framesPerSecond)) second(s) $Description" -NoNewline -f Yellow
        Start-Sleep -Milliseconds ([int](1000/$framesPerSecond))
        $iteration++
    }

    if ($allJobsCompleted)
    {
        Write-InteractiveHost "`rDONE - Operation took $([int]($iteration / $framesPerSecond)) second(s) $Description" -NoNewline -f Green

        # We forcibly set Verbose to false here since we don't need it printed to the screen, since we just did above -- we just need to log it.
        Write-Log -Message "DONE - Operation took $([int]($iteration / $framesPerSecond)) second(s) $Description" -Level Verbose -Verbose:$false
    }
    else
    {
        Write-InteractiveHost "`rDONE (FAILED) - Operation took $([int]($iteration / $framesPerSecond)) second(s) $Description" -NoNewline -f Red

        # We forcibly set Verbose to false here since we don't need it printed to the screen, since we just did above -- we just need to log it.
        Write-Log -Message "DONE (FAILED) - Operation took $([int]($iteration / $framesPerSecond)) second(s) $Description" -Level Verbose -Verbose:$false
    }

    Write-InteractiveHost ""
}

function Format-SimpleTableString
{
<#
    .SYNOPSIS
        Gets a string representation of the provided object as a table, with some
        additional formatting applied to make it easier to append to existing
        string output.

    .DESCRIPTION
        Gets a string representation of the provided object as a table, with some
        additional formatting applied to make it easier to append to existing
        string output.

        Will remove any leading or trailing empty lines, and adds the ability to
        ident all of the content the indicated number of spaces.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER Object
        The object to be formatted as a table.

    .PARAMETER IndentationLevel
        The number of spaces that this should be indented.
        Defaults to 0.

    .EXAMPLE
        Format-SimpleTableString @{"Name" = "Foo"; "Value" = "Bar"}
        Formats to a table with no indentation, and no leading or trailing empty lines.

    .EXAMPLE
        Format-SimpleTableString @{"Name" = "Foo"; "Value" = "Bar"} -IndentationLevel 5
        Formats to a table with no leading or trailing empty lines, and every line is indented
        with 5 spaces.

    .EXAMPLE
        @{"Name" = "Foo"; "Value" = "Bar"} | Format-SimpleTableString
        Formats to a table with no indentation, and no leading or trailing empty lines.
        This works due to pipeline input.

    .INPUTS
        Hashtables (generally), but can also be arrays as well.

    .OUTPUTS
        System.String

    .NOTES
        Because this uses pipeline input, if you pass an array via $Object, PowerShell
        will unwrap it so that each element is processed individually.  That doesn't
        work well when we're trying to then pass the array once again to Format-Table.
        So, we'll simply re-create an array from the individual elements, and then send
        that on to Format-Table.
#>
    [CmdletBinding()]
    Param(
        [Parameter(
            ValueFromPipeline,
            Mandatory)]
        $Object,

        [ValidateRange(1,30)]
        [Int16] $IndentationLevel = 0
    )

    Begin
    {
        $objects = @()
    }

    Process
    {
        $objects += $Object
    }

    End
    {
        if ($objects.count -gt 0)
        {
            Write-Output "$(" " * $IndentationLevel)$(($objects | Format-Table | Out-String).TrimStart($([Environment]::NewLine)).TrimEnd([Environment]::NewLine).Replace([Environment]::NewLine, "$([Environment]::NewLine)$(" " * $IndentationLevel)"))"
        }
    }
}

function DeepCopy-Object
<#
    .SYNOPSIS
        Creates a deep copy of a serializable object.

    .DESCRIPTION
        Creates a deep copy of a serializable object.
        By default, PowerShell performs shallow copies (simple references)
        when assigning objects from one variable to another.  This will
        create full exact copies of the provided object so that they
        can be manipulated independently of each other, provided that the
        object being copied is serializable.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER Object
        The object that is to be copied.  This must be serializable or this will fail.

    .EXAMPLE
        $bar = DeepCopy-Object $foo
        Assuming that $foo is serializable, $bar will now be an exact copy of $foo, but
        any changes that you make to one will not affect the other.

    .RETURNS
        An exact copy of the PSObject that was just deep copied.
#>
{
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseApprovedVerbs", "", Justification="Intentional.  This isn't exported, and needed to be explicit relative to Copy-Object.")]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject] $Object
    )

    $memoryStream = New-Object System.IO.MemoryStream
    $binaryFormatter = New-Object System.Runtime.Serialization.Formatters.Binary.BinaryFormatter
    $binaryFormatter.Serialize($memoryStream, $Object)
    $memoryStream.Position = 0
    $DeepCopiedObject = $binaryFormatter.Deserialize($memoryStream)
    $memoryStream.Close()

    return $DeepCopiedObject
}

function Get-SHA512Hash
{
<#
    .SYNOPSIS
        Gets the SHA512 hash of the requested string.

    .DESCRIPTION
        Gets the SHA512 hash of the requested string.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER PlainText
        The plain text that you want the SHA512 hash for.

    .EXAMPLE
        Get-SHA512Hash -PlainText "Hello World"

        Returns back the string "2C74FD17EDAFD80E8447B0D46741EE243B7EB74DD2149A0AB1B9246FB30382F27E853D8585719E0E67CBDA0DAA8F51671064615D645AE27ACB15BFB1447F459B"
        which represents the SHA512 hash of "Hello World"

    .OUTPUTS
        System.String - A SHA512 hash of the provided string
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [AllowEmptyString()]
        [string] $PlainText
    )

    $sha512= New-Object -TypeName System.Security.Cryptography.SHA512CryptoServiceProvider
    $utf8 = New-Object -TypeName System.Text.UTF8Encoding
    return [System.BitConverter]::ToString($sha512.ComputeHash($utf8.GetBytes($PlainText))) -replace '-', ''
}

function Get-EscapedJsonValue
{
<#
    .SYNOPSIS
        Escapes special characters within a string for use within a JSON value.

    .DESCRIPTION
        Escapes special characters within a string for use within a JSON value.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER Value
        The string that needs to be escaped

    .EXAMPLE
        Get-EscapedJsonValue -Value 'This is my "quote". Look here: c:\windows\'

        Returns back the string 'This is my \"quote\". Look here: c:\\windows\\'

    .OUTPUTS
        System.String - A string with special characters escaped for use within JSON.

    .NOTES
        Normalizes newlines and carriage returns to always be \r\n.
#>
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory,
            ValueFromPipeline)]
        [AllowNull()]
        [AllowEmptyString()]
        [string] $Value
    )

    # The syntax of -replace is a bit confusing, so it's worth a note here.
    # The first parameter is a regular expression match pattern.  The second parameter is a replacement string.
    # So, when we try to do "-replace '\\', '\\", that's matching a single backslash (which has to be
    # escaped within the match regular expression as a double-backslash), and replacing it with a
    # string containing literally two backslashes.
    # (And as a reminder, PowerShell's escape character is actually the backtick (`) and not backslash (\).)

    # \, ", <tab>
    $escaped = $Value -replace '\\', '\\' -replace '"', '\"' -replace '\t', '\t'

    # Now normalize actual CR's and LF's with their control codes.  We'll ensure all variations are uniformly formatted as \r\n
    $escaped = $escaped -replace '\r\n', '\r\n' -replace '\r', '\r\n' -replace '\n', '\r\n'

    return $escaped
}

function ConvertTo-Array
{
<#
    .SYNOPSIS
        Converts a value (or pipeline input) into an array.

    .DESCRIPTION
        Converts a value (or pipeline input) into an array.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER Value
        The value to convert into an array

    .EXAMPLE
        $foo = @{ "a" = 1; "b" = 2}; $foo.Keys | ConvertTo-Array

        Returns back an array of the keys (as opposed to a KeyCollection)

    .OUTPUTS
        [Object[]]
#>
    param(
        [Parameter(
            Mandatory,
            ValueFromPipeline)]
        [Object] $Value
    )

    Begin
    {
        $output = @();
    }

    Process
    {
        $output += $_;
    }

    End
    {
        return ,$output;
    }
}

function Write-Log
{
<#
    .SYNOPSIS
        Writes logging information to screen and log file simultaneously.

    .DESCRIPTION
        Writes logging information to screen and log file simultaneously.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER Message
        The message(s) to be logged. Each element of the array will be written to a separate line.

        This parameter supports pipelining but there are no
        performance benefits to doing so. For more information, see the .NOTES for this
        cmdlet.

    .PARAMETER Level
        The type of message to be logged.

    .PARAMETER Indent
        The number of spaces to indent the line in the log file.

    .PARAMETER Path
        The log file path.
        Defaults to $env:USERPROFILE\Documents\StoreBroker.log

    .PARAMETER Exception
        If present, the exception information will be logged after the messages provided.
        The actual string that is logged is obtained by passing this object to Out-String.

    .EXAMPLE
        Write-Log -Message "Everything worked." -Path C:\Debug.log

        Writes the message "Everything worked." to the screen as well as to a log file at "c:\Debug.log",
        with the caller's username and a date/time stamp prepended to the message.

    .EXAMPLE
        Write-Log -Message ("Everything worked.", "No cause for alarm.") -Path C:\Debug.log

        Writes the following message to the screen as well as to a log file at "c:\Debug.log",
        with the caller's username and a date/time stamp prepended to the message:

        Everything worked.
        No cause for alarm.

    .EXAMPLE
        Write-Log -Message "There may be a problem..." -Level Warning -Indent 2

        Writes the message "There may be a problem..." to the warning pipeline indented two spaces,
        as well as to the default log file with the caller's username and a date/time stamp
        prepended to the message.

    .EXAMPLE
        try { $null.Do() }
        catch { Write-Log -Message ("There was a problem.", "Here is the exception information:") -Exception $_ -Level Error }

        Logs the message:

        Write-Log : 2018-01-23 12:57:37 : dabelc : There was a problem.
        Here is the exception information:
        You cannot call a method on a null-valued expression.
        At line:1 char:7
        + try { $null.Do() } catch { Write-Log -Message ("There was a problem." ...
        +       ~~~~~~~~~~
            + CategoryInfo          : InvalidOperation: (:) [], RuntimeException
            + FullyQualifiedErrorId : InvokeMethodOnNull

    .INPUTS
        System.String

    .NOTES
        $global:SBLogPath indicates where the log file will be created.
        $global:SBLoggingEnabled determines if log entries will be made to the log file.
           If $false, log entries will ONLY go to the relevant output pipeline.

        Note that, although this function supports pipeline input to the -Message parameter,
        there is NO performance benefit to using the pipeline. This is because the pipeline
        input is simply accumulated and not acted upon until all input has been received.
        This behavior is intentional, in order for a statement like:
            "Multiple", "messages" | Write-Log -Exception $ex -Level Error
        to make sense.  In this case, the cmdlet should accumulate the messages and, at the end,
        include the exception information.
#>
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="Methods called within here make use of PSShouldProcess, and the switch is passed on to them inherently.")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidGlobalVars", "", Justification="We use global variables sparingly and intentionally for module configuration, and employ a consistent naming convention.")]
    param(
        [Parameter(ValueFromPipeline)]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [AllowNull()]
        [string[]] $Message = @(),

        [ValidateSet('Error', 'Warning', 'Informational', 'Verbose', 'Debug')]
        [string] $Level = 'Informational',

        [ValidateRange(1, 30)]
        [Int16] $Indent = 0,

        [IO.FileInfo] $Path = "$global:SBLogPath",

        [System.Management.Automation.ErrorRecord] $Exception
    )

    Begin
    {
        # Accumulate the list of Messages, whether by pipeline or parameter.
        $messages = @()
    }

    Process
    {
        foreach ($m in $Message)
        {
            $messages += $m
        }
    }

    End
    {
        if ($null -ne $Exception)
        {
            # If we have an exception, add it after the accumulated messages.
            $messages += Out-String -InputObject $Exception
        }
        elseif ($messages.Count -eq 0)
        {
            # If no exception and no messages, we should early return.
            return
        }

        # Finalize the string to be logged.
        $finalMessage = $messages -join [Environment]::NewLine

        # Build the console and log-specific messages.
        $date = Get-Date
        $dateString = $date.ToString("yyyy-MM-dd HH:mm:ss")
        if ($global:SBUseUTC)
        {
            $dateString = $date.ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ssZ")
        }

        $consoleMessage = '{0}{1} : {2} : {3}' -f
            (" " * $Indent),
            $dateString,
            $env:username,
            $finalMessage

        if ($global:SBShouldLogPid)
        {
            $maxPidDigits = 10 # This is an estimate (see https://stackoverflow.com/questions/17868218/what-is-the-maximum-process-id-on-windows)
            $pidColumnLength = $maxPidDigits + "[]".Length
            $logFileMessage = "{0}{1} : {2, -$pidColumnLength} : {3} : {4} : {5}" -f
                (" " * $Indent),
                $dateString,
                "[$global:PID]",
                $env:username,
                $Level.ToUpper(),
                $finalMessage
        }
        else
        {
            $logFileMessage = '{0}{1} : {2} : {3} : {4}' -f
                (" " * $Indent),
                $dateString,
                $env:username,
                $Level.ToUpper(),
                $finalMessage
        }

        # Write the message to screen/log.
        # Note that the below logic could easily be moved to a separate helper function, but a concious
        # decision was made to leave it here. When this cmdlet is called with -Level Error, Write-Error
        # will generate a WriteErrorException with the origin being Write-Log. If this call is moved to
        # a helper function, the origin of the WriteErrorException will be the helper function, which
        # could confuse an end user.
        switch ($Level)
        {
            # Need to explicitly say SilentlyContinue here so that we continue on, given that
            # we've assigned a script-level ErrorActionPreference of "Stop" for the module.
            'Error'   { Write-Error $consoleMessage -ErrorAction SilentlyContinue }
            'Warning' { Write-Warning $consoleMessage }
            'Verbose' { Write-Verbose $consoleMessage }
            'Debug'   { Write-Debug $consoleMessage }
            'Informational'    {
                # We'd prefer to use Write-Information to enable users to redirect that pipe if
                # they want, unfortunately it's only available on v5 and above.  We'll fallback to
                # using Write-Host for earlier versions (since we still need to support v4).
                if ($PSVersionTable.PSVersion.Major -ge 5)
                {
                    Write-Information $consoleMessage -InformationAction Continue
                }
                else
                {
                    Write-InteractiveHost $consoleMessage
                }
            }
        }

        try
        {
            if ($global:SBLoggingEnabled)
            {
                $logFileMessage | Out-File -FilePath $Path -Append
            }
        }
        catch
        {
            $output = @()
            $output += "Failed to add log entry to [$Path]. The error was:"
            $output += Out-String -InputObject $_

            if (Test-Path -Path $Path -PathType Leaf)
            {
                # The file exists, but likely is being held open by another process.
                # Let's do best effort here and if we can't log something, just report
                # it and move on.
                $output += "This is non-fatal, and your command will continue.  Your log file will be missing this entry:"
                $output += $consoleMessage
                Write-Warning ($output -join [Environment]::NewLine)
            }
            else
            {
                # If the file doesn't exist and couldn't be created, it likely will never
                # be valid.  In that instance, let's stop everything so that the user can
                # fix the problem, since they have indicated that they want this logging to
                # occur.
                throw ($output -join [Environment]::NewLine)
            }
        }
    }
}

$script:alwaysRedactParametersForLogging = @(
    'AccessToken' # Would be a security issue
)

$script:alwaysExcludeParametersForLogging = @(
    'NoStatus'
)

function Write-InvocationLog
{
    <#
    .SYNOPSIS
        Writes a log entry for the invoke command.

    .DESCRIPTION
        Writes a log entry for the invoke command.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER InvocationInfo
        The '$MyInvocation' object from the calling function.
        No need to explicitly provide this if you're trying to log the immediate function this is
        being called from.

    .PARAMETER RedactParameter
        An optional array of parameter names that should be logged, but their values redacted.

    .PARAMETER ExcludeParameter
        An optional array of parameter names that should simply not be logged.

    .EXAMPLE
        Write-InvocationLog -Invocation $MyInvocation

    .EXAMPLE
        Write-InvocationLog -Invocation $MyInvocation -ExcludeParameter @('Properties', 'Metrics')

    .NOTES
        The actual invocation line will not be _completely_ accurate as converted parameters will
        be in JSON format as opposed to PowerShell format.  However, it should be sufficient enough
        for debugging purposes.

        ExcludeParamater will always take precedence over RedactParameter.
#>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Management.Automation.InvocationInfo] $Invocation = (Get-Variable -Name MyInvocation -Scope 1 -ValueOnly),

        [string[]] $RedactParameter,

        [string[]] $ExcludeParameter
    )

    $jsonConversionDepth = 20 # Seems like it should be more than sufficient

    # Build up the invoked line, being sure to exclude and/or redact any values necessary
    $params = @()
    foreach ($param in $Invocation.BoundParameters.GetEnumerator())
    {
        if ($param.Key -in ($script:alwaysExcludeParametersForLogging + $ExcludeParameter))
        {
            continue
        }

        if ($param.Key -in ($script:alwaysRedactParametersForLogging + $RedactParameter))
        {
            $params += "-$($param.Key) <redacted>"
        }
        else
        {
            if ($param.Value -is [switch])
            {
                $params += "-$($param.Key):`$$($param.Value.ToBool().ToString().ToLower())"
            }
            else
            {
                $params += "-$($param.Key) $($param.Value | ConvertTo-Json -Depth $jsonConversionDepth -Compress)"
            }
        }
    }

    Write-Log -Message "[$($Invocation.MyCommand.Module.Version)] Executing: $($Invocation.MyCommand) $($params -join ' ')" -Level Verbose
}

function New-TemporaryDirectory
{
<#
    .SYNOPSIS
        Creates a new subdirectory within the users's temporary directory and returns the path.

    .DESCRIPTION
        Creates a new subdirectory within the users's temporary directory and returns the path.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .EXAMPLE
        New-TemporaryDirectory
        Creates a new directory with a GUID under $env:TEMP

    .OUTPUTS
        System.String - The path to the newly created temporary directory
#>
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="Methods called within here make use of PSShouldProcess, and the switch is passed on to them inherently.")]
    param()

    $guid = [System.GUID]::NewGuid()
    while (Test-Path -PathType Container (Join-Path -Path $env:TEMP -ChildPath $guid))
    {
        $guid = [System.GUID]::NewGuid()
    }

    $tempFolderPath = Join-Path -Path $env:TEMP -ChildPath $guid

    Write-Log -Message "Creating temporary directory: $tempFolderPath" -Level Verbose
    New-Item -ItemType Directory -Path $tempFolderPath
}

function Send-SBMailMessage
{
<#
    .SYNOPSIS
        Sends an email message.

    .DESCRIPTION
        A StoreBroker wrapper around Send-MailMessage.
        This will automatically CC the sender if they aren't in the receipient list already.
        This will automatically add a default domain name to any incomplete email address.

        Users can configure a number of global variables to change the behavior of this method.
        These variables are given default values upon module load
        $global:SBNotifyDefaultDomain - The default domain name to append to any incomplete email address
                                        [defaults to $null]
        $global:SBNotifyDefaultFrom   - The default sender's email address
                                        [defaults to the logged-in user's username]
        $global:SBNotifySmtpServer    - The SMTP Server to be used
                                        [defaults to $null]
        $global:SBNotifyCredential    - The credentials needed to send mail through that SMTP Server
                                        [defaults to $null]

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER Subject
        The subject of the email message.

    .PARAMETER Body
        The body of the email message.

    .PARAMETER To
        This can be a single email address, or a list of email address to send the email to.

    .EXAMPLE
        Send-SBMailMessage -Subject "Test" -Body "Hello"
        Assuming the user hasn't modified the global SBNotify* global variables, this will send
        a new email message with the subject "Test" and body "Hello" from $($env:username)@microsoft.com,
        and To that same email address, using Microsoft's internal SMTP server that doesn't require
        additional authentication information beyond logged-in user domain credentials.
#>
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidGlobalVars", "", Justification="We use global variables sparingly and intentionally for module configuration, and employ a consistent naming convention.")]
    param(
        [string] $Subject,
        [string] $Body,
        [string[]] $To = $global:SBNotifyDefaultFrom
    )

    # Normalize all the "To" email addresses and make sure that they have a domain name attached to them
    $fixedTo = @()
    $To | ForEach-Object {
        if ($_ -like "*@*")
        {
            $fixedTo += $_
        }
        else
        {
            $fixedTo += "$_@$global:SBNotifyDefaultDomain"
        }
    }

    # Do the same for the "From" email address
    $fixedFrom = $global:SBNotifyDefaultFrom
    if ($fixedFrom -notlike "*@*")
    {
        $fixedFrom = "$fixedFrom@$global:SBNotifyDefaultDomain"
    }

    $params = @{}
    $params.Add("To", $fixedTo)
    $params.Add("From", $fixedFrom)
    $params.Add("Subject", $Subject)
    $params.Add("Body", $Body)
    $params.Add("SmtpServer", $global:SBNotifySmtpServer)

    # We'll always CC the sender if they're not already sending the mail to themselves
    if (-not $fixedTo.Contains($fixedFrom))
    {
        $params.Add("CC", $fixedFrom)
    }

    # Only add the Credential if the user had to specify it
    if ($null -ne $global:SBNotifyCredential)
    {
        $params.Add("Credential", $global:SBNotifyCredential)
    }

    if ($PSCmdlet.ShouldProcess($Params, "Send-MailMessage"))
    {
        $maxRetries = 5;           # Some SMTP servers are flakey, so we'll allow for retrying on failure.
        $retryBackoffSeconds = 30; # When we do retry, how much time will we wait before trying again?

        $remainingAttempts = $maxRetries
        while ($remainingAttempts -gt 0)
        {
            $remainingAttempts--
            Write-Log -Message "Sending email to $($fixedTo -join ', ')" -Level Verbose

            try
            {
                Send-MailMessage @Params
                $remainingAttempts = 0
            }
            catch
            {
                if ($remainingAttempts -gt 0)
                {
                    Write-Log -Message "Exception trying to send mail. Will try again in $retryBackoffSeconds seconds." -Exception $_ -Level Warning
                    Start-Sleep -Seconds $retryBackoffSeconds
                }
                else
                {
                    Write-Log -Message "Exception trying to send mail. Retry attempts exhausted. Unable to send email." -Exception $_ -Level Error
                }
            }
        }
    }
}

function Write-InteractiveHost
{
<#
    .SYNOPSIS
        Forwards to Write-Host only if the host is interactive, else does nothing.

    .DESCRIPTION
        A proxy function around Write-Host that detects if the host is interactive
        before calling Write-Host. Use this instead of Write-Host to avoid failures in
        non-interactive hosts.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .EXAMPLE
        Write-InteractiveHost "Test"
        Write-InteractiveHost "Test" -NoNewline -f Yellow

    .NOTES
        Boilerplate is generated using these commands:
        # $Metadata = New-Object System.Management.Automation.CommandMetaData (Get-Command Write-Host)
        # [System.Management.Automation.ProxyCommand]::Create($Metadata) | Out-File temp
#>

    [CmdletBinding(
        HelpUri='http://go.microsoft.com/fwlink/?LinkID=113426',
        RemotingCapability='None')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "", Justification="This provides a wrapper around Write-Host. In general, we'd like to use Write-Information, but it's not supported on PS 4.0 which we need to support.")]
    param(
        [Parameter(
            Position=0,
            ValueFromPipeline,
            ValueFromRemainingArguments)]
        [System.Object] $Object,

        [switch] $NoNewline,

        [System.Object] $Separator,

        [System.ConsoleColor] $ForegroundColor,

        [System.ConsoleColor] $BackgroundColor
    )

    # Determine if the host is interactive
    if ([Environment]::UserInteractive -and `
        ![Bool]([Environment]::GetCommandLineArgs() -like '-noni*') -and `
        (Get-Host).Name -ne 'Default Host')
    {
        # Special handling for OutBuffer (generated for the proxy function)
        $outBuffer = $null
        if ($PSBoundParameters.TryGetValue('OutBuffer', [ref]$outBuffer))
        {
            $PSBoundParameters['OutBuffer'] = 1
        }

        Write-Host @PSBoundParameters
    }
}

function Resolve-UnverifiedPath
{
<#
    .SYNOPSIS
        A wrapper around Resolve-Path that works for paths that exist as well
        as for paths that don't (Resolve-Path normally throws an exception if
        the path doesn't exist.)

    .DESCRIPTION
        A wrapper around Resolve-Path that works for paths that exist as well
        as for paths that don't (Resolve-Path normally throws an exception if
        the path doesn't exist.)

        The Git repo for this module can be found here: https://aka.ms/StoreBroker

    .EXAMPLE
        Resolve-UnverifiedPath -Path 'c:\windows\notepad.exe'

        Returns the string 'c:\windows\notepad.exe'.

    .EXAMPLE
        Resolve-UnverifiedPath -Path '..\notepad.exe'

        Returns the string 'c:\windows\notepad.exe', assuming that it's executed from
        within 'c:\windows\system32' or some other sub-directory.

    .EXAMPLE
        Resolve-UnverifiedPath -Path '..\foo.exe'

        Returns the string 'c:\windows\foo.exe', assuming that it's executed from
        within 'c:\windows\system32' or some other sub-directory, even though this
        file doesn't exist.

    .OUTPUTS
        [string] - The fully resolved path

#>
    [CmdletBinding()]
    param(
        [Parameter(
            Position=0,
            ValueFromPipeline)]
        [string] $Path
    )

    $resolvedPath = Resolve-Path -Path $Path -ErrorVariable resolvePathError -ErrorAction SilentlyContinue

    if ($null -eq $resolvedPath)
    {
        return $resolvePathError[0].TargetObject
    }
    else
    {
        return $resolvedPath.ProviderPath
    }
}

function Ensure-Directory
{
<#
    .SYNOPSIS
        A utility function for ensuring a given directory exists.

    .DESCRIPTION
        A utility function for ensuring a given directory exists.

        If the directory does not already exist, it will be created.

    .PARAMETER Path
        A full or relative path to the directory that should exist when the function exits.

    .NOTES
        Uses the Resolve-UnverifiedPath function to resolve relative paths.
#>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseApprovedVerbs", "", Justification = "Unable to find a standard verb that satisfies describing the purpose of this internal helper method.")]
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    try
    {
        $Path = Resolve-UnverifiedPath -Path $Path

        if (-not (Test-Path -PathType Container -Path $Path))
        {
            Write-Log -Message "Creating directory: [$Path]" -Level Verbose
            New-Item -ItemType Directory -Path $Path | Out-Null
        }
    }
    catch
    {
        Write-Log -Message "Could not ensure directory: [$Path]" -Level Error

        throw
    }
}

function Get-HttpWebResponseContent
{
<#
    .SYNOPSIS
        Returns the content that may be contained within an HttpWebResponse object.

    .DESCRIPTION
        Returns the content that may be contained within an HttpWebResponse object.

        This would commonly be used when trying to get the potential content
        returned within a failing WebResponse.  Normally, when you call
        Invoke-WebRequest, it returns back a BasicHtmlWebResponseObject which
        directly contains a Content property, however if the web request fails,
        you get a WebException which contains a simpler WebResponse, which
        requires a bit more effort in order to acccess the raw response content.

    .PARAMETER WebResponse
        An HttpWebResponse object, typically the Response property on a WebException.

    .OUTPUTS
        System.String - The raw content that was included in a WebResponse; $null otherwise.
#>
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [System.Net.HttpWebResponse] $WebResponse
    )

    $streamReader = $null

    try
    {
        $content = $null

        if (($null -ne $WebResponse) -and ($WebResponse.ContentLength -gt 0))
        {
            $stream = $WebResponse.GetResponseStream()
            $encoding = [System.Text.Encoding]::UTF8
            if (-not [String]::IsNullOrWhiteSpace($WebResponse.ContentEncoding))
            {
                $encoding = [System.Text.Encoding]::GetEncoding($WebResponse.ContentEncoding)
            }

            $streamReader = New-Object -TypeName System.IO.StreamReader -ArgumentList ($stream, $encoding)
            $content = $streamReader.ReadToEnd()
        }

        return $content
    }
    finally
    {
        if ($null -ne $streamReader)
        {
            $streamReader.Close()
        }
    }
}

function Convert-EnumToString
{
<#
    .SYNOPSIS
        Converts all keys and values in arrays and hashtables that are enum values
        within InputObject into strings.

    .DESCRIPTION
        Converts all keys and values in arrays and hashtables that are enum values
        within InputObject into strings.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER InputObject
        The object that potentially has enum values to convert to string.

    .EXAMPLE
        @{[StoreBrokerSubmissionProperty]::isManualPublish = $true; 'array' = @(1, 2, 3, [StoreBrokerSubmissionState]::Published)} | Convert-EnumToString

        Returns @{ "isManualPublish":  true; 'array': @(1, 2, 3, 'Published') }

    .NOTES
        While new arrays and hashtables are created to hold the converted values, the original
        object(s) will be used within the returned object if they are neither arrays,
        hashtables or enum values.
#>
    [CmdletBinding()]
    [OutputType([Object[]])]
    param(
        [Parameter(
            ValueFromPipeline,
            Mandatory)]
        $InputObject
    )

    # ConvertTo-Json only works if the keys are strings.
    # We need to string-ify all keys
    if ($InputObject -is [array])
    {
        $modified = @()
        foreach ($item in $InputObject)
        {
            $modified += (Convert-EnumToString -InputObject $item)
        }

        return @($modified)
    }
    elseif ($InputObject -is [hashtable])
    {
        $modified = @{}
        foreach ($key in $InputObject.Keys.GetEnumerator())
        {
            $converted = (Convert-EnumToString -InputObject $InputObject[$key])
            if ($InputObject[$key] -is [array])
            {
                $converted = @($converted)
            }

            $modified[$key.ToString()] = $converted
        }

        return $modified
    }
    elseif ($InputObject -is [System.Enum])
    {
        return $InputObject.ToString()
    }
    else
    {
        return $InputObject
    }
}

function Get-JsonBody
{
<#
    .SYNOPSIS
        A wrapper around ConvertTo-Json that ensures any Enum value is converted to
        a string before the JSON conversion occurs.

    .DESCRIPTION
        A wrapper around ConvertTo-Json that ensures any Enum value is converted to
        a string before the JSON conversion occurs.

        This exists primarily because hashtable keys must be strings for serialization purposes.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER InputObject
        The object that is to be converted into JSON.

    .EXAMPLE
        @{[StoreBrokerSubmissionProperty]::isManualPublish = $true} | Get-JsonBody

        Returns { "isManualPublish":  true }
#>
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(
            ValueFromPipeline,
            Mandatory)]
        $InputObject
    )

    return ConvertTo-Json -InputObject (Convert-EnumToString -InputObject $InputObject) -Depth $script:jsonConversionDepth
}

function Test-PropertyExists
{
<#
    .SYNOPSIS
        Determines if an object contains a property with a specified name.

    .DESCRIPTION
        Determines if an object contains a property with a specified name.

        This is essentially using Get-Member to verify that a property exists,
        but additionally adds a check to ensure that InputObject isn't null.

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER InputObject
        The object to check to see if it has a property named Name.

    .PARAMETER Name
        The name of the property on InputObject that is being tested for.

    .EXAMPLE
        Test-PropertyExists -InputObject $listing -Name 'title'

        Returns $true if $listing is non-null and has a property named 'title'.
        Returns $false otherwise.

    .NOTES
        Internal-only helper method.
#>
    [CmdletBinding()]
    [OutputType([bool])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "", Justification="This is gramatically correct.")]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        $InputObject,

        [Parameter(Mandatory)]
        [String] $Name
    )

    return (($null -ne $InputObject) -and
            ($null -ne (Get-Member -InputObject $InputObject -Name $Name -MemberType Properties)))
}

function Set-ObjectProperty
{
<#
    .SYNOPSIS
        Reliably sets a property on a PSCustomObject, whether or not the property already exists.

    .DESCRIPTION
        Reliably sets a property on a PSCustomObject, whether or not the property already exists.

        This is, by and large, a wrapper on top of Add-Member.  It's main benefit is to also
        wrap the logic to support only setting the value if the source property exists (a requirement
        if a user is providing a minimal object).

        The Git repo for this module can be found here: http://aka.ms/StoreBroker

    .PARAMETER InputObject
        The object that has a property named Name that should be getting assigned a new value.

    .PARAMETER Name
        The name of the property on InputObject whose value should get assigned.

    .PARAMETER Value
        The value that should be assgined to the Name property on InputObject.

    .PARAMETER SourceObject
        An object with a property called SourceName that contains the value that is desired
        to be assigned to the Name property on InputObject.

    .PARAMETER SourceName
        The property on SourceObject that contains the value that is desired to be assigned
        to the Name property on InputObject.

    .PARAMETER SkipIfNotDefined
        Only set the value on InputObject if SourceObject exists and has a property on in
        called SourceName.  This would commonly be set if being used with a minimal object,
        and thus only want to update an object if the minimal (source) object contains the
        property being updated.

    .EXAMPLE
        Set-ObjectProperty -InputObject $listing -Name 'title' -Value 'Photos'

        Sets the title of $listing.title = 'Photos', adding the 'title' property to $listing
        if it didn't already exist.

    .EXAMPLE
        Set-ObjectProperty -InputObject $listing -Name 'title' -SourceObject $suppliedListing -SourceName 'title'

        Sets the title of $listing.title = $suppliedListing.title, adding the 'title' property to
        $listing if it didn't already exist.

    .EXAMPLE
        Set-ObjectProperty -InputObject $listing -Name 'title' -SourceObject $suppliedListing -SourceName 'title' -SkipIfNotDefined

        If $suppliedListing is not null, and it has a property called 'title', then it will
        set the title of $listing.title = $suppliedListing.title, adding the 'title' property to
        $listing if it didn't already exist.  Otherwise, it will do nothing.

    .NOTES
        Internal-only helper method.
#>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "", Justification="This module's use case precludes the need to support ShouldProcess on this function.")]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject] $InputObject,

        [Parameter(Mandatory)]
        [String] $Name,

        [Parameter(
            Mandatory,
            ParameterSetName="DirectValue")]
        [AllowNull()]
        [AllowEmptyString()]
        $Value,

        [Parameter(
            Mandatory,
            ParameterSetName="SourceObject")]
        [AllowNull()]
        $SourceObject,

        [Parameter(
            Mandatory,
            ParameterSetName="SourceObject")]
        $SourceName,

        [Parameter(ParameterSetName="SourceObject")]
        [switch] $SkipIfNotDefined
    )

    if ($PSCmdlet.ParameterSetName -eq 'SourceObject')
    {
        if ($SkipIfNotDefined -and
            (-not (Test-PropertyExists -InputObject $SourceObject -Name $SourceName)))
        {
            return
        }

        $Value = $SourceObject.$SourceName
    }

    Add-Member -InputObject $InputObject -Name $Name -Value $Value -MemberType NoteProperty -Force
}
