// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

namespace Microsoft.Windows.Source.StoreBroker.RestProxy.Models
{
    using System;
    using System.Security.Cryptography;
    using System.Security.Cryptography.X509Certificates;
    using System.Text;

    /// <summary>
    /// Provides a collection of methods to make it easy to encrypt and decrypt secrets
    /// using certificates that are installed in the machines local certificate store.
    /// </summary>
    public static class Encryption
    {
        /// <summary>
        /// Encrypts the secret using the certificate provided
        /// </summary>
        /// <param name="secret">Secret to encrypt</param>
        /// <param name="certThumbprint">Certificate to use to encrypt</param>
        /// <returns>Encrypted secret</returns>
        /// <exception cref="ApplicationException">Certificate cannot be found with the specified thumbprint.</exception>
        public static string EncryptSecret(string secret, string certThumbprint)
        {
            X509Certificate2 certificate = Encryption.GetCertificateFromStore(certThumbprint);
            RSACryptoServiceProvider cryptoServiceProvider = (RSACryptoServiceProvider)certificate.PublicKey.Key;

            byte[] secretBytes = Encoding.UTF8.GetBytes(secret);
            byte[] encryptedBytes = cryptoServiceProvider.Encrypt(secretBytes, true);
            string encryptedString = Convert.ToBase64String(encryptedBytes);

            return encryptedString;
        }

        /// <summary>
        /// Decrypts the secret using the certificate provided
        /// </summary>
        /// <param name="encryptedSecret">Encrypted secret</param>
        /// <param name="certThumbprint">Certificate to use to decrypt</param>
        /// <returns>The clear text that is encrypted within <paramref name="encryptedSecret"/></returns>
        /// <exception cref="ApplicationException">Certificate cannot be found with the specified thumbprint.</exception>
        public static string DecryptSecret(string encryptedSecret, string certThumbprint)
        {
            X509Certificate2 certificate = Encryption.GetCertificateFromStore(certThumbprint);
            RSACryptoServiceProvider cryptoServiceProvider = (RSACryptoServiceProvider)certificate.PrivateKey;

            byte[] encryptedBytes = Convert.FromBase64String(encryptedSecret);
            byte[] decryptedBytes = cryptoServiceProvider.Decrypt(encryptedBytes, true);
            string decryptedString = Encoding.UTF8.GetString(decryptedBytes);

            return decryptedString;
        }

        /// <summary>
        /// Gets the certificate matching the thumbprint from LocalMachine\My store
        /// </summary>
        /// <param name="thumbprint">The Certificate Thumbprint (40-digit hex number)</param>
        /// <returns>Matched certificate</returns>
        /// <exception cref="ApplicationException">Certificate cannot be found with the specified thumbprint.</exception>
        private static X509Certificate2 GetCertificateFromStore(string thumbprint)
        {
            X509Store store = new X509Store(StoreName.My, StoreLocation.LocalMachine);

            try
            {
                store.Open(OpenFlags.ReadOnly);

                X509Certificate2Collection certificateCollection = store.Certificates.Find(
                    X509FindType.FindByThumbprint,
                    thumbprint,
                    false);

                if (certificateCollection.Count == 0)
                {
                    throw new ApplicationException(string.Format("Certificate with thumbprint {0} was not found within the local machine store.", thumbprint));
                }

                return certificateCollection[0];
            }
            finally
            {
                store.Close();
            }
        }
    }
}