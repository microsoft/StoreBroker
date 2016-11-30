# Copyright (C) Microsoft Corporation.  All rights reserved.

Function Encrypt-Asymmetric
{
<#
    .SYNOPSIS
        Encrypts a string using the public key on a certificate.

    .DESCRIPTION
        Encrypts a string using the public key on a certificate.
        
        The Git repo for this cmdlet can be found here: http://aka.ms/StoreBroker

    .PARAMETER ClearText
        The text to encrypt.

    .PARAMETER PublicCertFilePath
        The path to the certificate file that has the public key to use for the encyption process.

    .EXAMPLE
        $encryptedText = Encrypt-Asymmetric "hello world" c:\certs\mycert.cer

        $encryptedText will contain the base64 encoded, encrypted version of
        the string "hello world", using the public key that is defined in the
        c:\certs\mycert.cer certificate.

    .OUTPUTS
        System.String - The encrypted string using Base64 encoding.
#>
    [CmdletBinding()]
    [OutputType([string])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseApprovedVerbs", "", Justification="Best description for purpose")]
    param(
        [Parameter(
            Mandatory=$true,
            Position=0)]
        [ValidateNotNullOrEmpty()]
        [string] $ClearText,

        [Parameter(
            Mandatory=$true,
            Position=1)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({Test-Path $_ -PathType Leaf})]
        [string] $PublicCertFilePath
    )

    # Encrypts a string with a public key
    $PublicCertFilePath = Resolve-Path -Path $PublicCertFilePath
    $publicCert = New-Object -TypeName System.Security.Cryptography.X509Certificates.X509Certificate2 -ArgumentList $PublicCertFilePath
    $byteArray = [System.Text.Encoding]::UTF8.GetBytes($ClearText)
    $encryptedByteArray = $publicCert.PublicKey.Key.Encrypt($byteArray,$true)
    $base64String = [Convert]::ToBase64String($encryptedByteArray)
 
    return $base64String
}


Function Decrypt-Asymmetric
{
<#
    .SYNOPSIS
        Decrypts a string using the private key of a certificate.

    .DESCRIPTION
        Decrypts a string using the private key of a certificate.
        
        The Git repo for this cmdlet can be found here: http://aka.ms/StoreBroker

    .PARAMETER EncryptedBase64String
        The encrypted string to decrypt.

    .PARAMETER CertThumbprint
        The thumbprint (40-digit hex number) of the certificate to use.
        Used to find the correct certificate in the certificate store.

    .PARAMETER CertStore
        The certificate store to search for a certificate matching CertThumbprint
        to use for the decryption of EncryptedBase64String.

    .PARAMETER PrivateCertPath
        The path to the private certificate to use for decryption, to be used instead of searching
        for the certificate by thumbprint in a given certificate store.

    .PARAMETER PrivateCertPassword
        The password for the certificate defined by PrivateCertPath so that the decryption process
        can occur.

    .EXAMPLE
        $clearText = Decrypt-Asymmetric -EncryptedBase64String $encryptedText -CertThumbprint 1234567890ABCDEF1234567890ABCDEF12345678 -CertStore "cert:\LocalMachine\My"

        $clearText will contain the decrypted version of $decryptedText, by looking up the
        certificate with the specified thumbrint in the local computer's certificate store for
        the private key.

    .EXAMPLE
        $clearText = Decrypt-Asymmetric -EncryptedBase64String $encryptedText -PrivateCertPath "c:\cert\MyCert.pfx" -PrivateCertPassword "myPa$$word"

        $clearText will contain the decrypted version of $decryptedText, by applying the
        specified password to the specified certiticate for decryption to occur.

    .OUTPUTS
        System.String - The encrypted string using Base64 encoding.
#>
    [CmdletBinding()]
    [OutputType([string])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseApprovedVerbs", "", Justification="Best description for purpose")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingConvertToSecureStringWithPlainText", "", Justification="This is the explicit purpose of this method")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPlainTextForPassword", "", Justification="Caller would be dealing in a plain text password in this scenario.")]
    param(
        [Parameter(
            ParameterSetName='store',
            Position=0,
            Mandatory=$true)]
        [Parameter(
            ParameterSetName='file',
            Position=0,
            Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string] $EncryptedBase64String,

        [Parameter(
            ParameterSetName='store',
            Position=1,
            Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string] $CertThumbprint,

        [Parameter(
            ParameterSetName='store',
            Position=2,
            Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string] $CertStore = "cert:\LocalMachine\My",

        [Parameter(
            ParameterSetName='file',
            Position=1,
            Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string] $PrivateCertPath,

        [Parameter(
            ParameterSetName='file',
            Position=2,
            Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string] $PrivateCertPassword
    )

    # Decrypts cipher text using the private key
    # Assumes the certificate is in the LocalMachine\My (Personal) Store
    switch ($PSCmdlet.ParameterSetName)
    {
        'store' 
        {
            $cert = Get-ChildItem -Path $CertStore | Where-Object { $_.Thumbprint -eq $CertThumbprint }
        }

        'file'
        {
            $PrivateCertPath = Resolve-Path -Path $PrivateCertPath
            $privateCertSecurePassword = $PrivateCertPassword | ConvertTo-SecureString -AsPlainText -Force
            $cert = New-Object -TypeName System.Security.Cryptography.X509Certificates.X509Certificate2 -ArgumentList ($PrivateCertPath, $privateCertSecurePassword)
        }
    }

    if ($null -ne $cert)
    {
        $encryptedByteArray = [Convert]::FromBase64String($EncryptedBase64String)
        $clearText = [System.Text.Encoding]::UTF8.GetString(
            $cert.PrivateKey.Decrypt(
                $encryptedByteArray,
                $true))
    }
    else
    {
        switch ($PSCmdlet.ParameterSetName)
        {
            'store'
            {
                Write-Error "Certificate with thumbprint `"$CertThumbprint`" in store `"$CertStore`" not found."
            }

            'file'
            {
                Write-Error "Certificate file `"$PrivateCertPath`" not found."
            }
        }
        
    }
 
    return $clearText
}