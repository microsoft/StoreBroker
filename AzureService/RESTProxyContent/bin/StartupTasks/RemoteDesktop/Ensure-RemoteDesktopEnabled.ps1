# Copyright (C) Microsoft Corporation.  All rights reserved.

function Ensure-RegistryKeyProperty
{
<#
    .SYNOPSIS
        Ensures the registry key property is set with the indicated value.

    .DESCRIPTION
        Ensures the registry key property is set with the indicated value.
        
        The Git repo for this cmdlet can be found here: http://aka.ms/StoreBroker

    .PARAMETER RegistryKey
        The registry key that has the property that should be set.

    .PARAMETER Property
        The name of the property under RegistryKey to set the value for.

    .PARAMETER Value
        The new value for Property.

    .PARAMETER Type
        The type of registry value that is being set.

    .EXAMPLE
        Ensure-RegistryKeyProperty -RegistryKey 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' -Property 'fDenyTSConnections' -Value 0000

        Sets the DWORD property called fDenyTSConnections to the value 0 under the registry key
        SYSTEM\CurrentControlSet\Control\Terminal Server in HKEY_LOCAL_MACHINE.
#>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseApprovedVerbs", "", Justification="Best description for purpose")]
    param(
        [Parameter(Mandatory)]
        [string] $RegistryKey,

        [Parameter(Mandatory)]
        [string] $Property,

        [Parameter(Mandatory)]
        [string] $Value,

        [Microsoft.Win32.RegistryValueKind] $Type = 'DWord'
    )

    process
    {
        try
        {
            Set-ItemProperty -Path $RegistryKey -Name $Property -Value $Value -Type $Type -ErrorAction Stop
            Write-Verbose "Set property `"$Property`" in registry key `"$RegistryKey`" to `"$Value`" with a type of `"$Type`""
        }
        catch
        {
            Write-Error "Unable to set property $Property in registry key $RegistryKey to $Value"
            throw $_
        }
    }
}

function Ensure-RemoteDesktopEnabled
{
<#
    .SYNOPSIS
        Ensures that Remote Desktop access is enabled. It will always write a value to enable it.

    .DESCRIPTION
        Ensures that Remote Desktop access is enabled. It will always write a value to enable it.
        
        The Git repo for this cmdlet can be found here: http://aka.ms/StoreBroker

    .EXAMPLE
        Ensure-RemoteDesktopEnabled

        Writes the necessary value to the registry that will enable remote desktop access to
        users in the Remote Desktop Users group.
#>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseApprovedVerbs", "", Justification="Best description for purpose")]
    param()

    process
    {
        Ensure-RegistryKeyProperty -RegistryKey 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' -Property 'fDenyTSConnections' -Value 0000
    }
}

