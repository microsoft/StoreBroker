# Copyright (C) Microsoft Corporation.  All rights reserved.

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
    param()

    # We only set their values if they don't already have values defined.
    # We use -ErrorAction SilentlyContinue during the Get-Variable check since it throws an exception
    # by default if the variable we're getting doesn't exist, and we just want the bool result.
    if (!(Get-Variable -Name SBLoggingEnabled -Scope Global -ValueOnly -ErrorAction SilentlyContinue))
    {
        $global:SBLoggingEnabled = $true
    }

    # $Home relies on existence of $env:HOMEDRIVE and $env:HOMEPATH which are only 
    # set when a user logged in interactively, which may not be the case for some build machines.
    # $env:USERPROFILE is the equivalent of $Home, and should always be available.
    if (!(Get-Variable -Name SBLogPath -Scope Global -ValueOnly -ErrorAction SilentlyContinue))
    {
        if (-not [System.String]::IsNullOrEmpty($env:USERPROFILE))
        {
            $global:SBLogPath = $(Join-Path $env:USERPROFILE "Documents\StoreBroker.log")
        }
        else
        {
            $global:SBLoggingEnabled = $false
        }
    }

    if (!(Get-Variable -Name SBNotifyDefaultDomain -Scope Global -ValueOnly -ErrorAction SilentlyContinue))
    {
        $global:SBNotifyDefaultDomain = $null
    }

    if (!(Get-Variable -Name SBNotifySmtpServer -Scope Global -ValueOnly -ErrorAction SilentlyContinue))
    {
        $global:SBNotifySmtpServer = $null
    }

    if (!(Get-Variable -Name SBNotifyDefaultFrom -Scope Global -ValueOnly -ErrorAction SilentlyContinue))
    {
        $global:SBNotifyDefaultFrom = $env:username
    }

    if (!(Get-Variable -Name SBNotifyCredential -Scope Global -ValueOnly -ErrorAction SilentlyContinue))
    {
        $global:SBNotifyCredential = [PSCredential]$null
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

    .PARAMETER jobName
        The name of the job that we are waiting to complete.

    .EXAMPLE
        Wait-JobWithAnimation Job1
        Waits for a job named "Job1" to exit the "Running" state.  While waiting, shows
        a waiting cursor and the elapsed time.

    .NOTES
        This is not a stand-in replacement for Wait-Job.  It does not provide the full
        set of configuration options that Wait-Job does.
#>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "", Justification="This function is intended for human interaction, not for scripting.  Write-Host makes the most sense for visible feedback.")]
    Param(
        [Parameter(Mandatory)]
        [string] $JobName,

        [string] $Description = ""
    )

    $animationFrames = '|','/','-','\'
    $framesPerSecond = 9

    # We'll wrap the description (if provided) in brackets for display purposes.
    if ($Description -ne "")
    {
        $Description = "[$Description]"
    }

    $iteration = 0
    while (((Get-Job -Name $JobName).state -eq 'Running'))
    {
        Write-Host "`r$($animationFrames[$($iteration % $($animationFrames.Length))])  Elapsed: $([int]($iteration / $framesPerSecond)) second(s) $Description" -NoNewline -f Yellow
        Start-Sleep -Milliseconds ([int](1000/$framesPerSecond))
        $iteration++
    }

    if ((Get-Job -Name $JobName).state -eq 'Completed')
    {
        Write-Host "`rDONE - Operation took $([int]($iteration / $framesPerSecond)) second(s) $Description" -NoNewline -f Green

        # We forcibly set Verbose to false here since we don't need it printed to the screen, since we just did above -- we just need to log it.
        Write-Log "DONE - Operation took $([int]($iteration / $framesPerSecond)) second(s) $Description" -Level Verbose -Verbose:$false
    }
    else
    {
        Write-Host "`rDONE (FAILED) - Operation took $([int]($iteration / $framesPerSecond)) second(s) $Description" -NoNewline -f Red

        # We forcibly set Verbose to false here since we don't need it printed to the screen, since we just did above -- we just need to log it.
        Write-Log "DONE (FAILED) - Operation took $([int]($iteration / $framesPerSecond)) second(s) $Description" -Level Verbose -Verbose:$false
    }

    Write-Host ""
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

    .SYNOPSIS
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
        [string] $PlainText
    )

    $sha512= New-Object -TypeName System.Security.Cryptography.SHA512CryptoServiceProvider
    $utf8 = New-Object -TypeName System.Text.UTF8Encoding
    return [System.BitConverter]::ToString($sha512.ComputeHash($utf8.GetBytes($PlainText))) -replace '-', ''
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
        The message to be logged.

    .PARAMETER Level
        The type of message to be logged.
        
    .PARAMETER Indent
        The number of spaces to indent the line in the log file.

    .PARAMETER Path
        The log file path.
        Defaults to $env:USERPROFILE\Documents\StoreBroker.log
        
    .EXAMPLE
        Write-Log -Message "Everything worked." -Path C:\Debug.log

        Writes the message "It's all good!" to the screen as well as to a log file at "c:\Debug.log",
        with the caller's username and a date/time stamp prepended to the message.

    .EXAMPLE
        Write-Log -Message "There may be a problem..." -Level Warning -Indent 2

        Writes the message "There may be a problem..." to the warning pipeline indented two spaces,
        as well as to the default log file with the caller's username and a date/time stamp
        prepended to the message.

    .INPUTS
        System.String

    .NOTES
        $global:SBLogPath indicates where the log file will be created.
        $global:SBLoggingEnabled determines if log entries will be made to the log file.
           If $false, log entries will ONLY go to the relevant output pipeline.
#>
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="Methods called within here make use of PSShouldProcess, and the switch is passed on to them inherently.")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidGlobalVars", "", Justification="We use global variables sparingly and intentionally for module configuration, and employ a consistent naming convention.")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "", Justification="We'd like to use Write-Information instead, but it's not supported on PS 4.0 which we need to support.")]
    param(
        [Parameter(
            Mandatory,
            ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string] $Message,

        [ValidateSet('Error', 'Warning', 'Info', 'Verbose', 'Debug')]
        [string] $Level = 'Info',

        [ValidateRange(1, 30)]
        [Int16] $Indent = 0,

        [IO.FileInfo] $Path = "$global:SBLogPath"
    )

    Process
    {
        $logFileMessage = '{0}{1} : {2} : {3} : {4}' -f
            (" " * $Indent),
            (Get-Date -Format "yyyy-MM-dd HH:mm:ss"),
            $env:username,
            $Level.ToUpper(),
            $Message
            
        $consoleMessage = '{0}{1} : {2} : {3}' -f
            (" " * $Indent),
            (Get-Date -Format "yyyy-MM-dd HH:mm:ss"),
            $env:username,
            $Message

        switch ($Level)
        {
            'Error'   { Write-Error $ConsoleMessage }
            'Warning' { Write-Warning $ConsoleMessage }
            'Verbose' { Write-Verbose $ConsoleMessage }
            'Debug'   { Write-Degbug $ConsoleMessage }
            'Info'    {
                # We'd prefer to use Write-Information to enable users to redirect that pipe if
                # they want, unfortunately it's only available on v5 and above.  We'll fallback to
                # using Write-Host for earlier versions (since we still need to support v4).
                if ($PSVersionTable.PSVersion.Major -ge 5)
                {
                    Write-Information $ConsoleMessage -InformationAction Continue
                }
                else
                {
                    Write-Host $ConsoleMessage
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
            $output += "Failed to add log entry to [$Path]. The error was: '$_'."

            if (Test-Path -Path $Path -PathType Leaf)
            {
                # The file exists, but likely is being held open by another process.
                # Let's do best effort here and if we can't log something, just report
                # it and move on.
                $output += "This is non-fatal, and your command will continue.  Your log file will be missing this entry:"
                $output += $ConsoleMessage
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

    Write-Log "Creating temporary directory: $tempFolderPath" -Level Verbose
    New-Item -ItemType directory -Path $tempFolderPath
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
            Write-Log "Sending email to $($fixedTo -join ', ')" -Level Verbose

            try
            {
                Send-MailMessage @Params
                $remainingAttempts = 0
            }
            catch
            {
                if ($remainingAttempts -gt 0)
                {
                    Write-Log "Exception trying to send mail: $($_.Exception.Message). Will try again in $retryBackoffSeconds seconds." -Level Warning
                    Start-Sleep -Seconds $retryBackoffSeconds
                }
                else
                {
                    Write-Log "Exception trying to send mail: $($_.Exception.Message). Retry attempts exhausted.  Unable to send email." -Level Error
                }
            }
        }
    }
}