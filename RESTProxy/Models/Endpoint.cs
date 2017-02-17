// Copyright (c) Microsoft Corporation. All rights reserved.

namespace Microsoft.Windows.Source.StoreBroker.RestProxy.Models
{
    using System;
    using System.ComponentModel;
    using System.IO;
    using System.Net;
    using System.Net.Http;
    using System.Security;
    using System.Security.Principal;
    using System.Text;
    using System.Threading.Tasks;
    using Newtonsoft.Json;
    using Newtonsoft.Json.Converters;
    using Newtonsoft.Json.Linq;

    /// <summary>
    /// Encapsulates the information related to a specific endpoint, as well as the ability
    /// to proxy a request through that endpoint.
    /// </summary>
    public class Endpoint
    {
        /// <summary>
        /// Initializes a new instance of the <see cref="Endpoint"/> class.
        /// </summary>
        /// <param name="tenantId">
        /// The tenantId that should be used for requests by this endpoint.
        /// </param>
        /// <param name="tenantFriendlyName">The friendly name for this endpoint.</param>
        /// <param name="endpointType">
        /// The type of endpoint that this info object represents.
        /// </param>
        /// <param name="clientId">
        /// The ClientId that is used for authentication with the Store API.
        /// The Documentation\SETUP.md file within <c>http://aka.ms/StoreBroker</c>
        /// explains how to create a client and get its ClientId and Secret.
        /// </param>
        /// <param name="clientSecretEncrypted">
        /// The encrypted Client Secret used for API access.
        /// The Documentation\SETUP.md file within <c>http://aka.ms/StoreBroker</c>
        /// explains how to create a client and get its ClientId and Secret, and the
        /// RESTPROXY.md documentation covers how to encrypt the client secret.
        /// </param>
        /// <param name="clientSecretCertificateThumbprint">
        /// The thumbprint of the certificate that can be used to decrypt
        /// <paramref name="clientSecretEncrypted"/>. The Documentation\RESTPROXY.md file
        /// within <c>http://aka.ms/StoreBroker</c> explains how to get the certificate thumbprint.
        /// </param>
        /// <param name="readOnlySecurityGroupAlias">
        /// The security group that users must be in to perform GET API requests from this
        /// endpoint.
        /// </param>
        /// <param name="readWriteSecurityGroupAlias">
        /// The security group that users must be in to perform GET, POST, PUT, DELETE requests
        /// from this endpoint.
        /// </param>
        public Endpoint(
            string tenantId,
            string tenantFriendlyName,
            EndpointType endpointType,
            string clientId,
            string clientSecretEncrypted,
            string clientSecretCertificateThumbprint,
            string readOnlySecurityGroupAlias,
            string readWriteSecurityGroupAlias)
        {
            this.TenantId = tenantId;
            this.TenantFriendlyName = tenantFriendlyName;
            this.Type = endpointType;
            this.ClientId = clientId;
            this.ClientSecretEncrypted = clientSecretEncrypted;
            this.ReadOnlySecurityGroupAlias = readOnlySecurityGroupAlias;
            this.ReadWriteSecurityGroupAlias = readWriteSecurityGroupAlias;
            this.ClientSecretCertificateThumbrint = clientSecretCertificateThumbprint;
            this.AccessToken = string.Empty;
            this.ValidThru = DateTime.Now;
            this.AsyncLock = new AsyncLock();
        }

        /// <summary>
        /// Describes the type of endpoint that the request will be proxy-ed through.
        /// </summary>
        public enum EndpointType
        {
            /// <summary>
            /// The production (live) endpoint.
            /// Changes made via this endpoint will affect customers.
            /// </summary>
            Prod,

            /// <summary>
            /// The internal, testing endpoint.
            /// Changes made here will never be seen publicly.
            /// </summary>
            Int
        }

        /// <summary>
        /// Gets the TenantId associated with this developer account.
        /// </summary>
        public string TenantId { get; private set; }

        /// <summary>
        /// Gets the friendly name that can be used in lieu of specifying the <see cref="TenantId"/>.
        /// </summary>
        public string TenantFriendlyName { get; private set; }

        /// <summary>
        /// Gets the type of endpoint that this info object represents.
        /// </summary>
        [JsonProperty("type")]
        [JsonConverter(typeof(StringEnumConverter))]
        [DefaultValue("Prod")]
        public EndpointType Type { get; private set; }

        /// <summary>
        /// Gets the starting part of the Uri (protocol and domain) that the rest of
        /// the Path and Query will be attended to when being proxy-ed.
        /// </summary>
        public string BaseUri
        {
            get
            {
                if (this.Type == EndpointType.Prod)
                {
                    return "https://manage.devcenter.microsoft.com";
                }
                else
                {
                    return "https://manage.devcenter.microsoft-int.com";
                }
            }
        }

        /// <summary>
        /// Gets the ClientId that is used for authentication with the Store API.
        /// The Documentation\SETUP.md file within <c>http://aka.ms/StoreBroker</c>
        /// explains how to create a client and get its ClientId and Secret.
        /// </summary>
        public string ClientId { get; private set; }

        /// <summary>
        /// Gets the unencrypted ClientSecret that is used for authentication with the Store API.
        /// </summary>
        public string ClientSecret
        {
            get
            {
                if (string.IsNullOrWhiteSpace(this.ClientSecretCertificateThumbrint))
                {
                    // Assume that this actually isn't encrypted -- a possible scenario
                    // when doing local development.
                    return this.ClientSecretEncrypted;
                }
                else
                {
                    return Encryption.DecryptSecret(
                        this.ClientSecretEncrypted,
                        this.ClientSecretCertificateThumbrint);
                }
            }
        }

        /// <summary>
        /// Gets the alias for the security group that protects R/O requests for this tenant.
        /// </summary>
        public string ReadOnlySecurityGroupAlias { get; private set; }

        /// <summary>
        /// Gets the alias for the security group that protects R/W requests for this tenant.
        /// </summary>
        public string ReadWriteSecurityGroupAlias { get; private set; }

        /// <summary>
        /// Gets or sets the encrypted Client Secret used for API access.
        /// The Documentation\SETUP.md file within <c>http://aka.ms/StoreBroker</c>
        /// explains how to create a client and get its ClientId and Secret, and the
        /// RESTPROXY.md documentation covers how to encrypt the client secret.
        /// </summary>
        private string ClientSecretEncrypted { get; set; }

        /// <summary>
        /// Gets or sets the thumbprint of the certificate that can be used to decrypt
        /// <see cref="ClientCertificateEncrypted"/>.
        /// The Documentation\RESTPROXY.md file within <c>http://aka.ms/StoreBroker</c>
        /// explains how to get the certificate thumbprint.
        /// </summary>
        private string ClientSecretCertificateThumbrint { get; set; }

        /// <summary>
        /// Gets or sets an AccessToken is retrieved from the Windows Live/Azure service after
        /// authenticating with the ClientId and Secret.  We can use the same AccessToken for
        /// as many subsequent API requests as we'd like until its <see cref="ValidThru"/> time
        /// has expired.  This value will be updated by <see cref="RefreshAccessToken"/>.  We
        /// are choosing to cache this value instead of getting it every time for performance
        /// reasons.
        /// </summary>
        private string AccessToken { get; set; }

        /// <summary>
        /// Gets or sets the time at which <see cref="AccessToken"/> will cease to be valid for
        /// authentication with the Store REST API.
        /// </summary>
        private DateTime ValidThru { get; set; }

        /// <summary>
        /// Gets or sets a lock that will ensure that we only have one request trying to refresh the
        /// <see cref="AccessToken"/> at any given time.  We need a special <see cref="AsyncLock"/>
        /// to do that since it'll be protecting an asynchronous call.
        /// </summary>
        private AsyncLock AsyncLock { get; set; }

        /// <summary>
        /// Creates a new instance of an <see cref="Endpoint"/> object containing all of
        /// the initial configuration data for this Endpoint.
        /// </summary>
        /// <returns>
        /// A new instance of an <see cref="Endpoint"/> object containing all of
        /// the initial configuration data for this Endpoint.
        /// </returns>
        public Endpoint Duplicate()
        {
            return new Endpoint(
                this.TenantId,
                this.TenantFriendlyName,
                this.Type,
                this.ClientId,
                this.ClientSecretEncrypted,
                this.ClientSecretCertificateThumbrint,
                this.ReadOnlySecurityGroupAlias,
                this.ReadWriteSecurityGroupAlias);
        }

        /// <summary>
        /// Proxies the specified request to the actual Store REST API over this endpoint.
        /// </summary>
        /// <param name="pathAndQuery">
        /// The UriAbsolutePath and Query properties.  Simply, this is the entire Uri except for
        /// the protocol and domain information.
        /// </param>
        /// <param name="method">The <see cref="HttpMethod"/> of the REST API.</param>
        /// <param name="onBehalfOf">
        /// The <see cref="IPrincipal"/> of the user that we're performing the API request on behalf of.
        /// </param>
        /// <param name="body">The body content of the REST request (if needed).</param>
        /// <returns>The <see cref="HttpResponseMessage"/> to be sent to the user.</returns>
        public async Task<HttpResponseMessage> PerformRequestAsync(
            string pathAndQuery,
            HttpMethod method,
            IPrincipal onBehalfOf,
            string body = null)
        {
            // This is the real API endpoint that we'll be contacting.  We'll just append
            // pathAndQuery directly to this to get the final REST Uri that we need to use.
            string finalUri = string.Format(
                "{0}{1}",
                this.BaseUri,
                pathAndQuery);

            WebRequest request = HttpWebRequest.Create(finalUri);
            request.Method = method.ToString();
            request.ContentLength = 0;  // will be updated if there is a body.

            try
            {
                HttpResponseMessage errorMessage;

                // No reason to progress any further if they don't have the right permissions
                // to access the API that they're trying to use.
                if (!this.TryHasPermission(onBehalfOf, method, out errorMessage))
                {
                    return errorMessage;
                }

                // Every API request needs to authenticate itself by providing an AccessToken
                // in the authorization header.
                string accessToken = await this.GetAccessTokenAsync();
                request.Headers[HttpRequestHeader.Authorization] = string.Format("bearer {0}", accessToken);

                // Write the body to the request stream if one was provided.
                // Not every REST API will require a body.  For instance, the GET requests have
                // no body, and the (current) POST API's also have no body.
                if (!string.IsNullOrWhiteSpace(body))
                {
                    byte[] bytes = System.Text.Encoding.UTF8.GetBytes(body);
                    request.ContentLength = bytes.Length;
                    request.ContentType = $"{ProxyManager.JsonMediaType}; charset=UTF-8";

                    using (Stream requestStream = await request.GetRequestStreamAsync())
                    {
                        requestStream.Write(bytes, 0, bytes.Length);
                    }
                }

                // Send the actual response.
                using (WebResponse response = await request.GetResponseAsync())
                {
                    using (Stream stream = response.GetResponseStream())
                    {
                        using (StreamReader reader = new StreamReader(stream))
                        {
                            // Even though we got a simple WebResponse, in our scenario we would prefer
                            // an HttpWebResponse since it exposes a StatusCode property.
                            HttpWebResponse httpResponse = response as HttpWebResponse;
                            HttpStatusCode statusCode = (httpResponse == null) ?
                                HttpStatusCode.OK :
                                httpResponse.StatusCode;

                            HttpResponseMessage httpResponseMessage = new HttpResponseMessage(statusCode);

                            // Proxy all of the special headers that the API returns
                            // (which all begin with "MS-").  One example is "MS-CorrelationId"
                            // which is needed by the Windows Store Submission API team when they
                            // are investigating bug reports with the API.
                            foreach (string key in httpResponse.Headers.AllKeys)
                            {
                                if (key.StartsWith("MS-"))
                                {
                                    httpResponseMessage.Headers.Add(key, httpResponse.Headers[key]);
                                }
                            }

                            // Some commands, like DELETE have no response body.
                            string responseBody = reader.ReadToEnd();
                            if (!string.IsNullOrEmpty(responseBody))
                            {
                                // The contentType string tends to have the character encoding appended to it.
                                // We just want the actual contentType since we specify the content encoding separately.
                                string contentType = response.ContentType.Split(';')[0];
                                httpResponseMessage.Content = new StringContent(responseBody, Encoding.UTF8, contentType);
                            }

                            return httpResponseMessage;
                        }
                    }
                }
            }
            catch (WebException ex)
            {
                // Even though WebException stores the response as a simple WebResponse, in our scenario
                // it should actually be an HttpWebResponse.  We'd prefer that one, since HttpWebResponse
                // exposes a StatusCode property.
                HttpWebResponse httpResponse = ex.Response as HttpWebResponse;
                HttpStatusCode statusCode = (httpResponse == null) ?
                    HttpStatusCode.InternalServerError :
                    httpResponse.StatusCode;

                string responseBody = new StreamReader(ex.Response.GetResponseStream()).ReadToEnd();

                // The contentType string tends to have the character encoding appended to it.
                // We just want the actual contentType since we specify the content encoding separately.
                string contentType = ex.Response.ContentType.Split(';')[0];

                if (string.IsNullOrEmpty(responseBody))
                {
                    return new HttpResponseMessage(statusCode);
                }
                else
                {
                    return new HttpResponseMessage(statusCode)
                    {
                        Content = new StringContent(responseBody, Encoding.UTF8, contentType)
                    };
                }
            }
        }

        /// <summary>
        /// Gets the AccessToken that is necessary for authenticating with the Store REST API.
        /// </summary>
        /// <remarks>
        /// The AccessToken retrieved is generally valid for only one hour.
        /// This will check ValidThru to see if the currently cached AccessToken is still valid.
        /// If it isn't, it will lock and then refresh the token (and ValidThru value).
        /// </remarks>
        /// <returns>
        /// The AccessToken that can be used for API requests on this Endpoint.
        /// </returns>
        private async Task<string> GetAccessTokenAsync()
        {
            if (this.ValidThru.CompareTo(DateTime.Now) <= 0)
            {
                using (await this.AsyncLock.LockAsync())
                {
                    // To optimize the normal case, we won't acquire a lock when initially checking ValidThru,
                    // but that means we have to do the same comparison again once we grab the lock
                    // to make sure that it's still necessary to refresh once we grab it.
                    if (this.ValidThru.CompareTo(DateTime.Now) <= 0)
                    {
                        await this.RefreshAccessTokenAsync();
                    }
                }
            }

            return this.AccessToken;
        }

        /// <summary>
        /// Updates the cached AccessToken (and its ValidThru property).
        /// </summary>
        /// <returns>A Task for synchronization purposes.</returns>
        private async Task RefreshAccessTokenAsync()
        {
            // These define the needed OAUTH2 URI and request body format for retrieving the AccessToken.
            const string TokenUrlFormat = "https://login.windows.net/{0}/oauth2/token";
            const string AuthBodyFormat = "grant_type=client_credentials&client_id={0}&client_secret={1}&resource={2}";

            // We set ValidThru to "Now" *here* because we'll be adding the "expires_in" value to
            // this (which is in seconds from the time the response was generated).  If we did
            // DateTime.Now after we get the response, it could potentially be multiple seconds
            // after the server generated that response.  It's safer to indicate that it expires
            // sooner than it really does and force an earlier Refresh than to incorrectly use an
            // AccessToken that has expired and get an undesirable API request failure.
            this.ValidThru = DateTime.Now;

            string uri = string.Format(TokenUrlFormat, this.TenantId);
            string body = string.Format(
                AuthBodyFormat,
                System.Web.HttpUtility.UrlEncode(this.ClientId),
                System.Web.HttpUtility.UrlEncode(this.ClientSecret),
                this.BaseUri);

            WebRequest request = HttpWebRequest.Create(uri);
            request.Method = "POST";

            using (Stream requestStream = await request.GetRequestStreamAsync())
            {
                byte[] bytes = System.Text.Encoding.UTF8.GetBytes(body);
                requestStream.Write(bytes, 0, bytes.Length);
            }

            using (WebResponse response = await request.GetResponseAsync())
            {
                using (Stream stream = response.GetResponseStream())
                {
                    using (StreamReader reader = new StreamReader(stream))
                    {
                        string responseString = reader.ReadToEnd();

                        JObject jsonResponse = JObject.Parse(responseString);
                        this.AccessToken = (string)jsonResponse["access_token"];

                        // We'll intentionally expire the AccessToken a bit earlier since there is
                        // a non-zero amount of time that will be spent between when we check the
                        // expiration time of the token and when the REST request makes it to the
                        // real endpoint for authentication.
                        const int ExpirationBufferSeconds = 90;

                        // We intentionally aren't using
                        // DateTimeOffset.FromUnixTimeSeconds((long)jsonResponse["expires_on"]).UtcDateTime.
                        // The problem with that is the DateTime on this server may not be in sync
                        // with the remote server, and thus the relative time might be off by a
                        // matter of minutes (actually seen in practice).  Instead, we'll always
                        // operate off of our own system's time and use "expires_in" instead which
                        // is just a relative number of seconds from when the request was returned
                        // to us.
                        long expiresIn = (long)jsonResponse["expires_in"] - ExpirationBufferSeconds;
                        this.ValidThru = this.ValidThru.AddSeconds(expiresIn);
                    }
                }
            }
        }

        /// <summary>
        /// Validates that a user has permission to use this API.
        /// We currently differentiate purely on the "method" of the request:
        ///    GET requests are read/only (won't cause any changes on the server side)
        ///    DELETE/POST/PUT requests are read/write
        /// </summary>
        /// <param name="userPrincipal">The <see cref="IPrincipal"/> of the user making the request.</param>
        /// <param name="method">The <see cref="HttpMethod"/> of the request.</param>
        /// <param name="errorResponse">
        /// If the user doesn't have permission, this contains the <see cref="HttpResponseMessage"/>
        /// that should be returned to the user with the appropriate explanation.
        /// </param>
        /// <returns>true if the user has permission to perform the requested action; false otherwise</returns>
        /// <remarks>
        /// We are intentionally trying to encapsulate the exception handling within here, hence the
        /// "Try" naming scheme that returns a boolean with the errorResponse as an out parameter.
        /// </remarks>
        private bool TryHasPermission(IPrincipal userPrincipal, HttpMethod method, out HttpResponseMessage errorResponse)
        {
            // These are used for formatting the error message returned when the user doesn't have permission.
            const string UnauthorizedAccessMessageFormat = "You need to be a member of the \"{0}\" security group to access this API.";
            const string SecurityExceptionMessageFormat = "{{\"code\":\"Unauthorized\", \"message\":{0}}}";

            try
            {
                if (method == HttpMethod.Get)
                {
                    // GET methods are equivalent to R/O methods, but R/W gets access as well
                    if (!userPrincipal.IsInRole(this.ReadOnlySecurityGroupAlias) &&
                        !userPrincipal.IsInRole(this.ReadWriteSecurityGroupAlias))
                    {
                        throw new UnauthorizedAccessException(string.Format(UnauthorizedAccessMessageFormat, this.ReadOnlySecurityGroupAlias));
                    }
                }
                else if (!userPrincipal.IsInRole(this.ReadWriteSecurityGroupAlias))
                {
                    throw new UnauthorizedAccessException(string.Format(UnauthorizedAccessMessageFormat, this.ReadWriteSecurityGroupAlias));
                }

                errorResponse = null;
                return true;
            }
            catch (UnauthorizedAccessException ex)
            {
                string response = string.Format(SecurityExceptionMessageFormat, JsonConvert.ToString(ex.Message));
                errorResponse = new HttpResponseMessage(HttpStatusCode.Unauthorized)
                {
                    Content = new StringContent(response, Encoding.UTF8, ProxyManager.JsonMediaType)
                };

                return false;
            }
            catch (SecurityException ex)
            {
                string response = string.Format(SecurityExceptionMessageFormat, JsonConvert.ToString(ex.Message));
                errorResponse = new HttpResponseMessage(HttpStatusCode.Unauthorized)
                {
                    Content = new StringContent(response, Encoding.UTF8, ProxyManager.JsonMediaType)
                };

                return false;
            }
        }
    }
}
