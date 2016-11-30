// Copyright (c) Microsoft Corporation. All rights reserved.

namespace Microsoft.Windows.Source.StoreBroker.RestProxy.Models
{
    using System;
    using System.Collections.Generic;
    using System.Diagnostics;
    using System.IO;
    using System.Net;
    using System.Net.Http;
    using System.Reflection;
    using System.Security;
    using System.Security.Principal;
    using System.Text;
    using System.Threading.Tasks;
    using ApplicationInsights;
    using Azure;
    using Newtonsoft.Json;
    using Newtonsoft.Json.Linq;
    using WindowsAzure.ServiceRuntime;

    /// <summary>
    /// This is the workhorse of the proxy service.
    /// The sole purpose of this class is to proxy requests to the real Store API.
    /// Internally, it knows how to authenticate with that API and how to validate permissions
    /// of the users issuing the requests to this service.
    /// </summary>
    public static class ProxyManager
    {
        /// <summary>
        ///  The media type that describes a JSON payload.
        /// </summary>
        private const string JsonMediaType = "application/json";

        /// <summary>
        /// The Application Insights client that will be used for "logging" all of the user requests
        /// </summary>
        private static TelemetryClient telemetryClient = new TelemetryClient();

        /// <summary>
        /// Stores the relevant info for each of the possible REST endpoints that we may proxy to.
        /// </summary>
        private static Dictionary<EndpointType, EndpointInfo> endpointInfo = new Dictionary<EndpointType, EndpointInfo>
        {
            {
              EndpointType.Prod,
              new EndpointInfo(
                baseUri: "https://manage.devcenter.microsoft.com",
                clientId: CloudConfigurationManager.GetSetting("ClientIdProd"))
            },
            {
              EndpointType.Int,
              new EndpointInfo(
                baseUri: "https://manage.devcenter.microsoft-int.com",
                clientId: CloudConfigurationManager.GetSetting("ClientIdInt"))
            }
        };

        /// <summary>
        /// Describes the type of endpoint that the request will be proxy-ed through.
        /// </summary>
        public enum EndpointType
        {
            /// <summary>
            /// The production (live) endpoint.
            /// Changes made via this endpoint will be affect customers.
            /// </summary>
            Prod,

            /// <summary>
            /// The internal, testing endpoint.
            /// Changes made here will never be seen publicly.
            /// </summary>
            Int
        }

        /// <summary>
        /// Proxies the specified request to the actual Store REST API.
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
        /// <param name="endpointType">The type of endpoint that should be used for the request.</param>
        /// <returns>The <see cref="HttpResponseMessage"/> to be sent to the user.</returns>
        public static async Task<HttpResponseMessage> PerformRequest(
            string pathAndQuery,
            HttpMethod method,
            IPrincipal onBehalfOf,
            string body = null,
            EndpointType endpointType = EndpointType.Prod)
        {
            // We'll track how long this takes, for telemetry purposes.
            Stopwatch stopwatch = Stopwatch.StartNew();

            // Assume ok unless we find out otherwise.
            HttpStatusCode statusCode = HttpStatusCode.OK;

            // This is the real API endpoint that we'll be contacting.  We'll just append
            // pathAndQuery directly to this to get the final REST Uri that we need to use.
            string finalUri = string.Format(
                "{0}{1}",
                ProxyManager.endpointInfo[endpointType].BaseUri,
                pathAndQuery);

            WebRequest request = HttpWebRequest.Create(finalUri);
            request.Method = method.ToString();
            request.ContentLength = 0;  // will be updated if there is a body.

            try
            {
                // No reason to progress any further if they don't have the right permissions
                // to access the API that they're trying to use.
                HttpResponseMessage errorMessage;
                if (!ProxyManager.TryHasPermission(onBehalfOf, method, out errorMessage))
                {
                    statusCode = errorMessage.StatusCode; // used in the finally block
                    return errorMessage;
                }

                // Every API request needs to authenticate itself by providing an AccessToken
                // in the authorization header.
                string accessToken = await GetAccessToken(endpointType);
                request.Headers[HttpRequestHeader.Authorization] = string.Format("bearer {0}", accessToken);

                // Write the body to the request stream if one was provided.
                // Not every REST API will require a body.  For instance, the GET requests have
                // no body, and the (current) POST API's also have no body.
                if (!string.IsNullOrWhiteSpace(body))
                {
                    byte[] bytes = System.Text.Encoding.UTF8.GetBytes(body);
                    request.ContentLength = bytes.Length;
                    request.ContentType = $"{ProxyManager.JsonMediaType}; charset=utf8";

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
                            statusCode = (httpResponse == null) ?
                                HttpStatusCode.OK :
                                httpResponse.StatusCode;

                            string responseBody = reader.ReadToEnd();

                            if (string.IsNullOrEmpty(responseBody))
                            {
                                // Some commands, like DELETE have no response body.
                                return new HttpResponseMessage(statusCode);
                            }
                            else
                            {
                                // The contentType string tends to have the character encoding appended to it.
                                // We just want the actual contentType since we specify the content encoding separately.
                                string contentType = response.ContentType.Split(';')[0];

                                return new HttpResponseMessage(statusCode)
                                {
                                    Content = new StringContent(responseBody, Encoding.UTF8, contentType)
                                };
                            }
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
                statusCode = (httpResponse == null) ?
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
            finally
            {
                stopwatch.Stop();
                ProxyManager.LogTelemetryEvent(
                    onBehalfOf.Identity.Name,
                    pathAndQuery,
                    method,
                    endpointType,
                    statusCode,
                    stopwatch.Elapsed.TotalSeconds);
            }
        }

        /// <summary>
        /// Gets the AccessToken that is necessary for authenticating with the Store REST API.
        /// </summary>
        /// <param name="endpointType">The type of endpoint that should be used for the request.</param>
        /// <returns>The AccessToken to use with the Store REST API authentication.</returns>
        /// <remarks>
        /// The AccessToken retrieved is generally valid for only one hour.
        /// This will check ValidThru to see if the currently cached AccessToken is still valid.
        /// If it isn't, it will lock and then refresh the token (and ValidThru value).
        /// </remarks>
        private static async Task<string> GetAccessToken(EndpointType endpointType)
        {
            if (ProxyManager.endpointInfo[endpointType].ValidThru.CompareTo(DateTime.Now) <= 0)
            {
                using (await ProxyManager.endpointInfo[endpointType].AsyncLock.LockAsync())
                {
                    // To otimize the normal case, we won't acquire a lock when initially checking ValidThru,
                    // but that means we have to do the same comparison again once we grab the lock
                    // to make sure that it's still necessary to refresh once we grab it.
                    if (ProxyManager.endpointInfo[endpointType].ValidThru.CompareTo(DateTime.Now) <= 0)
                    {
                        await RefreshAccessToken(endpointType);
                    }
                }
            }

            return ProxyManager.endpointInfo[endpointType].AccessToken;
        }

        /// <summary>
        /// Updates the statically cached AccessToken (and its ValidThru property).
        /// </summary>
        /// <param name="endpointType">The type of endpoint that should be used for the request.</param>
        /// <returns>A Task for synchronization purposes.</returns>
        private static async Task RefreshAccessToken(EndpointType endpointType)
        {
            string tenantId = CloudConfigurationManager.GetSetting("TenantId");

            // These define the needed OAUTH2 URI and request body format for retrieving the AccessToken.
            const string TokenUrlFormat = "https://login.windows.net/{0}/oauth2/token";
            const string AuthBodyFormat = "grant_type=client_credentials&client_id={0}&client_secret={1}&resource={2}";

            // We set ValidThru to "Now" *here* because we'll be adding the "expires_in" value to
            // this (which is in seconds from the time the response was generated).  If we did
            // DateTime.Now after we get the response, it could potentially be multiple seconds
            // after the server generated that response.  It's safer to indicate that it expires
            // sooner than it really does and force an earlier Refresh than to incorrectly use an
            // AccessToken that has expired and get an undesirable API request failure.
            ProxyManager.endpointInfo[endpointType].ValidThru = DateTime.Now;

            string clientSecret = GetClientSecret(endpointType);
            string uri = string.Format(TokenUrlFormat, tenantId);
            string body = string.Format(
                AuthBodyFormat,
                System.Web.HttpUtility.UrlEncode(ProxyManager.endpointInfo[endpointType].ClientId),
                System.Web.HttpUtility.UrlEncode(clientSecret),
                ProxyManager.endpointInfo[endpointType].BaseUri);

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
                        ProxyManager.endpointInfo[endpointType].AccessToken = (string)jsonResponse["access_token"];

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
                        ProxyManager.endpointInfo[endpointType].ValidThru = ProxyManager.endpointInfo[endpointType].ValidThru.AddSeconds(expiresIn);
                    }
                }
            }
        }

        /// <summary>
        /// Retrieve the ClientSecret that needs to be used for authentication purposes with the
        /// Store REST API from the service configuration settings.
        /// </summary>
        /// <param name="endpointType">The type of endpoint that should be used for the request.</param>
        /// <returns>The ClientSecret for the StoreBroker application client.</returns>
        /// <remarks>
        /// The client secrets are stored *encrypted* in the service configuration settings.
        /// The certificate with the public key for encrypting these secrets is checked-in with
        /// this code in the "certs" folder.  The private key that can be used to *decrypt* the
        /// encrypted client secrets is only stored directly in Azure, associated with this service.
        /// </remarks>
        private static string GetClientSecret(EndpointType endpointType)
        {
            string clientSecret = string.Empty;

            // If we're running in Azure, use the credentials from the config.
            if (RoleEnvironment.IsAvailable)
            {
                if (endpointType == EndpointType.Prod)
                {
                    clientSecret = Encryption.DecryptSecret(
                        CloudConfigurationManager.GetSetting("ClientSecretProd"),
                        CloudConfigurationManager.GetSetting("ClientSecretProdCertThumbprint"));
                }
                else
                {
                    clientSecret = Encryption.DecryptSecret(
                        CloudConfigurationManager.GetSetting("ClientSecretInt"),
                        CloudConfigurationManager.GetSetting("ClientSecretIntCertThumbprint"));
                }
            }
            else
            {
                // When running this locally, you need to enter the clientSecret in clear text
                // (since you don't have the certificate's private key available for decryption).
                // Be sure not to check-in the code with the client secret in clear text though.
                if (endpointType == EndpointType.Prod)
                {
                    clientSecret = string.Empty; // DO NOT CHECK IN CODE WITH THIS SECRET!
                }
                else
                {
                    clientSecret = string.Empty; // DO NOT CHECK IN CODE WITH THIS SECRET!
                }
            }

            if (string.IsNullOrEmpty(clientSecret))
            {
                throw new Exception("ClientSecret was not retrieved.");
            }

            return clientSecret;
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
        private static bool TryHasPermission(IPrincipal userPrincipal, HttpMethod method, out HttpResponseMessage errorResponse)
        {
            string readOnlySecurityGroup = CloudConfigurationManager.GetSetting("ROSecurityGroupAlias");
            string readWriteSecurityGroup = CloudConfigurationManager.GetSetting("RWSecurityGroupAlias");

            // These are used for formatting the error message returned when the user doesn't have permission.
            const string UnauthorizedAccessMessageFormat = "You need to be a member of the \"{0}\" security group to access this API.";
            const string SecurityExceptionMessageFormat = "{{\"code\":\"Unauthorized\", \"message\":{0}}}";
            
            try
            {
                if (method == HttpMethod.Get)
                {
                    // GET methods are equivalent to R/O methods, but R/W gets access as well
                    if (!userPrincipal.IsInRole(readOnlySecurityGroup) &&
                        !userPrincipal.IsInRole(readWriteSecurityGroup))
                    {
                        throw new UnauthorizedAccessException(string.Format(UnauthorizedAccessMessageFormat, readOnlySecurityGroup));
                    }
                }
                else if (!userPrincipal.IsInRole(readWriteSecurityGroup))
                {
                    throw new UnauthorizedAccessException(string.Format(UnauthorizedAccessMessageFormat, readWriteSecurityGroup));
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

        /// <summary>
        /// Wrapper used for the purposes of logging user requests to Application Insights
        /// in case we need to review user actions at a later time.
        /// </summary>
        /// <param name="userName">The user that requested the action</param>
        /// <param name="pathAndQuery">
        /// The UriAbsolutePath and Query properties.  Simply, this is the entire Uri except for
        /// the protocol and domain information.
        /// </param>
        /// <param name="method">The <see cref="HttpMethod"/> of the REST API.</param>
        /// <param name="endpointType">The type of endpoint that should be used for the request.</param>
        /// <param name="statusCode">The <see cref="HttpStatusCode"/> for the result of the request.</param>
        /// <param name="duration">The total number of seconds that the request took to complete.</param>
        private static void LogTelemetryEvent(
            string userName,
            string pathAndQuery,
            HttpMethod method,
            EndpointType endpointType,
            HttpStatusCode statusCode,
            double duration)
        {
            ProxyManager.telemetryClient.Context.Session.Id = System.Guid.NewGuid().ToString();
            ProxyManager.telemetryClient.Context.Component.Version = Assembly.GetExecutingAssembly().GetName().Version.ToString();

            Dictionary<string, string> properties = new Dictionary<string, string>();
            properties.Add("UserName", userName);
            properties.Add("PathAndQuery", pathAndQuery);
            properties.Add("Method", method.ToString());
            properties.Add("StatusCode", statusCode.ToString());
            properties.Add("EndpointType", endpointType.ToString());

            Dictionary<string, double> metrics = new Dictionary<string, double>();
            metrics.Add("Duration", duration);

            ProxyManager.telemetryClient.TrackEvent("ProxyRequest", properties, metrics);
        }

        /// <summary>
        /// Encapsulates the information related to a specific endpoint
        /// </summary>
        private class EndpointInfo
        {
            /// <summary>
            /// Initializes a new instance of the <see cref="EndpointInfo"/> class.
            /// </summary>
            /// <param name="baseUri">
            /// The starting part of the Uri (protocol and domain) that the rest of
            /// the Path and Query will be attended to when being proxy-ed.
            /// </param>
            /// <param name="clientId">
            /// The ClientId that is used for authentication with the Store API.
            /// The Documentation\SETUP.md file within <c>http://aka.ms/StoreBroker</c>
            /// explains how to create a client and get its ClientId and Secret.
            /// </param>
            public EndpointInfo(string baseUri, string clientId)
            {
                this.BaseUri = baseUri;
                this.ClientId = clientId;
                this.AccessToken = string.Empty;
                this.ValidThru = DateTime.Now;
                this.AsyncLock = new AsyncLock();
            }

            /// <summary>
            /// Gets the starting part of the Uri (protocol and domain) that the rest of
            /// the Path and Query will be attended to when being proxy-ed.
            /// </summary>
            public string BaseUri { get; private set; }

            /// <summary>
            /// Gets the ClientId that is used for authentication with the Store API.
            /// The Documentation\SETUP.md file within <c>http://aka.ms/StoreBroker</c>
            /// explains how to create a client and get its ClientId and Secret.
            /// </summary>
            public string ClientId { get; private set; }

            /// <summary>
            /// Gets or sets an AccessToken is retrieved from the Windows Live/Azure service after
            /// authenticating with the ClientId and Secret.  We can use the same AccessToken for
            /// as many subsequent API requests as we'd like until its <see cref="ValidThru"/> time
            /// has expired.  This value will be updated by <see cref="RefreshAccessToken"/>.  We
            /// are choosing to cache this value instead of getting it every time for performance
            /// reasons.
            /// </summary>
            public string AccessToken { get; set; }

            /// <summary>
            /// Gets or sets the time at which <see cref="AccessToken"/> will cease to be valid for
            /// authentication with the Store REST API.
            /// </summary>
            public DateTime ValidThru { get; set; }

            /// <summary>
            /// Gets a lock that will ensure that we only have one request trying to refresh the
            /// <see cref="AccessToken"/> at any given time.  We need a special <see cref="AsyncLock"/>
            /// to do that since it'll be protecting an asynchronous call.
            /// </summary>
            public AsyncLock AsyncLock { get; private set; }
        }
    }
}