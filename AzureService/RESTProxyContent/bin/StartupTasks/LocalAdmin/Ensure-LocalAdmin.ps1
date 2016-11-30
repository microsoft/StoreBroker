# Copyright (C) Microsoft Corporation.  All rights reserved.

# Load the helper cmdlets
. $PSScriptRoot\..\Helpers\Encryption.ps1
. $PSScriptRoot\..\Helpers\GroupManagement.ps1

function Ensure-LocalUserExists
{
<#
    .SYNOPSIS
        Ensures the local user exists. If it doesn't, it will create it.

    .DESCRIPTION
        Ensures the local user exists. If it doesn't, it will create it.
        
        The Git repo for this cmdlet can be found here: http://aka.ms/StoreBroker

    .PARAMETER UserName
        The name of the local user to ensure exists.

    .PARAMETER Secret
        The Base64 encrypted password for UserName.

    .PARAMETER CertThumbprint
        The thumbprint (40-digit hex number) of the certificate to use to decode Secret.

    .PARAMETER CertStore
        The certificate store that the certificate with CertThumbrint can be found.

    .EXAMPLE
        Ensure-LocalUserExists -UserName "myUser" -Secret $encrypted -CertThumbrint 1234567890ABCDEF1234567890ABCDEF12345678

        Will ensure that the current computer has a local user named "myUser" with a password that
        is found after decrypting $encrypted using the certificate found with the specified
        thumbprint in the local computer certificate store.
#>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseApprovedVerbs", "", Justification="Best description for purpose")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "", Justification="Exists isn't plural in this instance.")]
    param(
        [Parameter(Mandatory)]
        [string] $UserName,

        [Parameter(Mandatory)]
        [string] $Secret,

        [Parameter(Mandatory)]
        [string] $CertThumbprint,

        [string] $CertStore = "cert:\LocalMachine\My"
    )
    process
    {
        Write-Verbose "Ensuring user [$UserName] exists"

        # ADSI == Active Directory Service Interface
        $computerAdsi = [ADSI]"WinNT://${env:Computername}"
        $localUsers = $computerAdsi.Children |
            Where-Object { $_.SchemaClassName -eq 'user' } |
            ForEach-Object { $_.name[0].ToString() }

        if ($localUsers -notcontains $UserName)
        {
            Write-Verbose "User [$UserName] does not exit. It will be created."

            try
            {
                Write-Verbose "Decrypting password."
                $password = Decrypt-Asymmetric -EncryptedBase64String $Secret -CertThumbprint $CertThumbprint -CertStore $CertStore -ErrorAction Stop

                Write-Verbose "Password decrypted."
                $user = $computerAdsi.Create("User", $UserName)
                $user.setPassword($password)
                $user.SetInfo();
                $user.description = "Local Admin created via Cloud Service startup script."
                $user.SetInfo();

                Write-Verbose "Created user [$UserName]"
            }
            catch
            {
                Write-Error "Unable to create user [$UserName]"
                Throw $_
            }
        }
        else
        {
            Write-Verbose "User [$UserName] already exists."
        }
    }

}

function Ensure-LocalAdmin
{
<#
    .SYNOPSIS
        Ensures the specified user exists and is an Administrator with RDP access.

    .DESCRIPTION
        Ensures the specified user exists and is an Administrator with RDP access.
        
        The Git repo for this cmdlet can be found here: http://aka.ms/StoreBroker

    .PARAMETER UserName
        The name of the local user that should be an administrator with RDP access.

    .PARAMETER Secret
        The Base64 encrypted password for UserName.

    .PARAMETER CertThumbprint
        The thumbprint (40-digit hex number) of the certificate to use to decode Secret.

    .PARAMETER CertStore
        The certificate store that the certificate with CertThumbrint can be found.

    .EXAMPLE
        Ensure-LocalAdmin -UserName "myUser" -Secret $encrypted -CertThumbrint 1234567890ABCDEF1234567890ABCDEF12345678

        Will ensure that the current computer has a local user named "myUser" with a password that
        is found after decrypting $encrypted using the certificate found with the specified
        thumbprint in the local computer certificate store.  That user will be a member of the
        Administrators group and the Remote Desktop Users group.
#>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseApprovedVerbs", "", Justification="Best description for purpose")]
    param(
        [Parameter(Mandatory)]
        [string] $UserName,

        [Parameter(Mandatory)]
        [string] $Secret,

        [Parameter(Mandatory)]
        [string] $CertThumbprint,

        [string] $CertStore = "cert:\LocalMachine\My"
    )
 
    process
    {
        Ensure-LocalUserExists -UserName $UserName -Secret $Secret -CertThumbprint $CertThumbprint -CertStore $CertStore
        Ensure-IsInAdministratorsGroup -UserName $UserName
        Ensure-IsInRemoteDesktopUsersGroup -UserName $UserName
    }
}