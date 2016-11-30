# Copyright (C) Microsoft Corporation.  All rights reserved.

function Ensure-IsInGroup
{
<#
    .SYNOPSIS
        Ensures the user is in the specified group. If not, it will add them.

    .DESCRIPTION
        Ensures the user is in the specified group. If not, it will add them.
        
        The Git repo for this cmdlet can be found here: http://aka.ms/StoreBroker

    .PARAMETER UserName
        The user that should be in Group

    .PARAMETER Group
        The group that UserName should be a member of.

    .PARAMETER Domain
        The domain for UserName (if relevant)

    .EXAMPLE
        Ensure-IsInGroup -UserName "myUser" -Group "Administrators"

        Checks to see if the user "myUser" is in the Administrators group.  If not, adds them.
#>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseApprovedVerbs", "", Justification="Best description for purpose")]
    param(
        [Parameter(Mandatory)]
        [string] $UserName,

        [Parameter(Mandatory)]
        [string] $Group,

        [string] $Domain = $null
    )

    process
    {
        Write-Verbose "Ensuring user [$UserName] is a member of the [$Group] group."

        # ADSI == Active Directory Service Interface
        $groupAdsi = [ADSI]"WinNT://${env:Computername}/$Group, group"
        $members = @($groupAdsi.psbase.Invoke("Members")) | ForEach-Object { ([ADSI]$_).InvokeGet("Name") }

        if ($members -notcontains $UserName)
        {
            Write-Verbose "User [$UserName] is not a member of the [$Group] group. They will be added."

            try
            {
                if ([string]::IsNullOrEmpty($Domain))
                {
                    $groupAdsi.Add("WinNT://${env:Computername}/$UserName, user")
                }
                else
                {
                    $groupAdsi.psbase.Invoke("Add", ([ADSI]"WinNT://$Domain/$UserName").path)
                }
                
                Write-Verbose "User [$UserName] was added to the [$Group] group."
            }
            catch
            {
                Write-Error "Unable to add user [$UserName] to the [$Group] group."
                throw $_
            }
        }
        else
        {
            Write-Verbose "User [$UserName] is already a member of the [$Group] group."
        }

    }
}

function Ensure-IsInAdministratorsGroup
{
<#
    .SYNOPSIS
        Ensures the user is in the Administrators group. If not, it will add them.

    .DESCRIPTION
        Ensures the user is in the Administrators group. If not, it will add them.
        
        The Git repo for this cmdlet can be found here: http://aka.ms/StoreBroker

    .PARAMETER UserName
        The user that should be in Administrators group

    .PARAMETER Domain
        The domain for UserName (if relevant)

    .EXAMPLE
        Ensure-IsInAdministratorsGroup "myUser"

        Checks to see if the user "myUser" is in the Administrators group.  If not, adds them.
#>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseApprovedVerbs", "", Justification="Best description for purpose")]
    param(
        [Parameter(Mandatory)]
        [string] $UserName,

        [string] $Domain = $null
    )

    process
    {
        Ensure-IsInGroup -UserName $UserName -Group 'Administrators' -Domain $Domain
    }
}

function Ensure-IsInRemoteDesktopUsersGroup
{
<#
    .SYNOPSIS
        Ensures the user is in the Remote Desktop Users group. if not, it will add them.

    .DESCRIPTION
        Ensures the user is in the Remote Desktop Users group. if not, it will add them.
        
        The Git repo for this cmdlet can be found here: http://aka.ms/StoreBroker

    .PARAMETER UserName
        The user that should be in Remote Desktop Users group

    .PARAMETER Domain
        The domain for UserName (if relevant)

    .EXAMPLE
        Ensure-IsInRemoteDesktopUsersGroup "myUser"

        Checks to see if the user "myUser" is in the Remote Desktop Users group.  If not, adds them.
#>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseApprovedVerbs", "", Justification="Best description for purpose")]
    param(
        [Parameter(Mandatory)]
        [string] $UserName,

        [string] $Domain = $null
    )

    process
    {
        Ensure-IsInGroup -UserName $UserName -Group 'Remote Desktop Users' -Domain $Domain
    }
}