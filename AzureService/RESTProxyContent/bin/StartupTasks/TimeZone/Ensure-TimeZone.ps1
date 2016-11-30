# Copyright (C) Microsoft Corporation.  All rights reserved.

function Get-TimeZone
{
<#
    .SYNOPSIS
        Gets the ID of the device's current timezone.

    .DESCRIPTION
        Gets the ID of the device's current timezone.
        
        The Git repo for this cmdlet can be found here: http://aka.ms/StoreBroker

    .EXAMPLE
        Get-TimeZone

        Gets the ID of the device's current timezone.

    .OUTPUTS
        System.String - The ID of the timezone
#>
    [CmdletBinding()]
    [OutputType([String])]
    param()

    [System.TimeZoneInfo]::ClearCachedData()
    $localTimeZone = [system.timezoneinfo]::Local
    $localTimeZone.Id
}

function Set-TimeZone
{
<#
    .SYNOPSIS
        Changes the device to use the specified timezone.

    .DESCRIPTION
        Changes the device to use the specified timezone.
        
        The Git repo for this cmdlet can be found here: http://aka.ms/StoreBroker

    .PARAMETER TimeZoneId
        The ID of the timezone that should be used for this device.

    .EXAMPLE
        Set-TimeZone -TimeZoneId 'Pacific Standard Time'

        Sets the device to use the PST timezone.
#>
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingInvokeExpression", "", Justification="There doesn't appear to be a better way to change the timezone.")]
    param(
        [Parameter(
            Mandatory,
            ValueFromPipeline,
            Position=0)]
        [string] $TimeZoneId
    )

    if ($PSCmdlet.ShouldProcess($TimeZoneId, "tzutil.exe /s"))
    {
        Invoke-Expression "tzutil.exe /s ""$TimeZoneId""" -ErrorAction Stop
    }
}

function Ensure-TimeZone
{
<#
    .SYNOPSIS
        Updates the device's timezone to the specified timezone if it isn't already
        using it.

    .DESCRIPTION
        Updates the device's timezone to the specified timezone if it isn't already
        using it.
        
        The Git repo for this cmdlet can be found here: http://aka.ms/StoreBroker

    .PARAMETER TimeZoneId
        The ID of the timezone that should be used for this device.

    .EXAMPLE
        Ensure-TimeZone -TimeZoneId 'Pacific Standard Time'

        Sets the device to use the PST timezone if it's not already in PST.
#>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseApprovedVerbs", "", Justification="Best description for purpose")]
    param(
        [Parameter(
            Mandatory,
            ValueFromPipeline,
            Position=0)]
        [string] $TimeZoneId
    )

    try
    {
        Write-Verbose "Ensuring that the time zone id is set to ""$TimeZoneId""."
        $currentTimeZoneId = Get-TimeZone -ErrorAction Stop;
        Write-Verbose "Current time zone id is ""$currentTimeZoneId""."

        if ($currentTimeZoneId -ne $TimeZoneId)
        {
            Write-Verbose "Time zone ids do not match. Setting time zone to ""$timeZoneId""."
            Set-TimeZone $timeZoneId -ErrorAction Stop
            Write-Verbose "Successfully set the time zone to ""$timeZoneId""."
        }
        else
        {
            Write-Verbose "Current time zone matches expected time zone."
        }
    }
    catch
    {
        Write-Error "Unable to ensure the time zone is set properly."
        throw $_
    }
}