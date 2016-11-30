# Copyright (C) Microsoft Corporation.  All rights reserved.

# Load the helper cmdlets
. $PSScriptRoot\..\Helpers\Encryption.ps1
. $PSScriptRoot\..\Helpers\GroupManagement.ps1

function Get-JoinedDomain
{
<#
    .SYNOPSIS
        Gets the domain that the computer is currently joined to.

    .DESCRIPTION
        Gets the domain that the computer is currently joined to.
        
        The Git repo for this cmdlet can be found here: http://aka.ms/StoreBroker

    .PARAMETER Computer
        The name of the computer to check the domain join status of.

    .EXAMPLE
        Get-JoinedDomain "MyComputerName"

        Returns back the computer name and its joined domain if the computer is joined
        to a computer, otherwise throws an exception.

    .OUTPUTS
        PSCustomObject - An object with a "Name" and "Domain" property for the computer and its
                         domain.
#>
    param (
        [parameter(
            Position=0,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName)]
        [string] $Computer = "." 
    )

    process
    {
        Get-CimInstance -Class Win32_ComputerSystem -ComputerName $Computer -ErrorAction Stop |
            Select-Object Name, Domain
    }         
}

function Ensure-ComputerDomainJoined
{
<#
    .SYNOPSIS
        Ensures the computer is domain joined. If not, it will join the specified domain.

    .DESCRIPTION
        Ensures the computer is domain joined. If not, it will join the specified domain.
        
        The Git repo for this cmdlet can be found here: http://aka.ms/StoreBroker

    .PARAMETER Domain
        The name of the domain that the current to check the domain join status of.

    .PARAMETER UserName
        The usename for the user that will be authenticating the request to join the domain.

    .PARAMETER Secret
        The Base64 encrypted password for UserName.

    .PARAMETER CertThumbprint
        The thumbprint (40-digit hex number) of the certificate to use to decode Secret.

    .PARAMETER CertStore
        The certificate store that the certificate with CertThumbrint can be found.

    .PARAMETER Computer
        The computer that should be joined to Domain.

    .EXAMPLE
        Ensure-ComputerDomainJoined -Domain "foo" -UserName "sampleUser" -Secret $encrypted -CertThumbrint 1234567890ABCDEF1234567890ABCDEF12345678

        Will ensure that the current computer is joined to the foo domain.  If it's not,
        it will join the domain by authenticating with "sampleUser" and use the password that
        is found after decrypting $encrypted using the certificate found with the specified
        thumbprint in the local computer certificate store.
#>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseApprovedVerbs", "", Justification="Best description for purpose")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingConvertToSecureStringWithPlainText", "", Justification="We're getting the password in cleartext")]
    param(
        [Parameter(Mandatory)]
        [string] $Domain,

        [Parameter(Mandatory)]
        [string] $UserName,

        [Parameter(Mandatory)]
        [string] $Secret,

        [Parameter(Mandatory)]
        [string] $CertThumbprint,

        [string] $CertStore = "cert:\LocalMachine\My",

        [string] $Computer = "."
    )

    process
    {
        Write-Verbose "Ensuring computer is joined the [$Domain] domain"

        try
        {
            $domainInfo = Get-JoinedDomain
        }
        catch
        {
            Write-Error "Unable get computer information."
            throw $_
        }

        if ($domainInfo.Domain -ne $Domain)
        {
            Write-Verbose "Computer is not part of the specified domain. It will now be joined to the [$Domain] domain."

            try
            {
                Set-DnsClient -InterfaceAlias "Ethernet*" -ConnectionSpecificSuffix $Domain

                Write-Verbose "Decrypting password."
                $securePassword = Decrypt-Asymmetric -EncryptedBase64String $Secret -CertThumbprint $CertThumbprint -CertStore $CertStore -ErrorAction Stop |
                    ConvertTo-SecureString -AsPlainText -Force -ErrorAction Stop

                Write-Verbose "Password decrypted."
                $cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList("$Domain\$UserName", $securePassword)

                # Specifically not using the -Restart switch because that causes problems with
                # the rest of the service deployment.  Restarting doesn't actually appear to be
                # necessary anyway.  In the event that we really did have to restart here,
                # we could always just do something like 'shutdown -r -t 90' to allow some
                # time for the service to finish deploying before the VM was restarted.
                Add-Computer -DomainName $Domain -Credential $cred -Force -ErrorAction Stop
            }
            catch
            {
                Write-Error "Unable to add computer to the [$Domain] domain."
                throw $_
            }
        }
        else
        {
            Write-Verbose "Computer is already joined to the [$Domain] domain. Nothing to do."
        }
    }
}

function Ensure-DomainJoined
{
<#
    .SYNOPSIS
        Ensures the computer is domain joined. If not, it will join the specified domain.

    .DESCRIPTION
        Ensures the computer is domain joined. If not, it will join the specified domain.

        Additionally ensures that the specified user is an Administrator and a Remote Desktop user.
        
        The Git repo for this cmdlet can be found here: http://aka.ms/StoreBroker

    .PARAMETER Domain
        The name of the domain that the current to check the domain join status of.

    .PARAMETER UserName
        The usename for the user that will be authenticating the request to join the domain.

    .PARAMETER Secret
        The Base64 encrypted password for UserName.

    .PARAMETER CertThumbprint
        The thumbprint (40-digit hex number) of the certificate to use to decode Secret.

    .PARAMETER CertStore
        The certificate store that the certificate with CertThumbrint can be found.

    .PARAMETER Computer
        The computer that should be joined to Domain.

    .EXAMPLE
        Ensure-DomainJoined -Domain "foo" -UserName "sampleUser" -Secret $encrypted -CertThumbrint 1234567890ABCDEF1234567890ABCDEF12345678

        Will ensure that the current computer is joined to the foo domain.  If it's not,
        it will join the domain by authenticating with "sampleUser" and use the password that
        is found after decrypting $encrypted using the certificate found with the specified
        thumbprint in the local computer certificate store.
#>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseApprovedVerbs", "", Justification="Best description for purpose")]
    param(
        [Parameter(Mandatory)]
        [string] $Domain,

        [Parameter(Mandatory)]
        [string] $UserName,

        [Parameter(Mandatory)]
        [string] $Secret,

        [Parameter(Mandatory)]
        [string] $CertThumbprint,

        [string] $CertStore = "cert:\LocalMachine\My",

        [string] $Computer = "."
    )

    Ensure-ComputerDomainJoined -Domain $Domain -UserName $UserName -Secret $Secret -CertThumbprint $CertThumbprint -CertStore $CertStore -Computer $Computer
    Ensure-IsInAdministratorsGroup -UserName $UserName -Domain $Domain
    Ensure-IsInRemoteDesktopUsersGroup -UserName $UserName -Domain $Domain
}