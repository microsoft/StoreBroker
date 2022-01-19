// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

namespace Microsoft.Windows.Source.StoreBroker.RestProxy.Models
{
    using System.Collections.Generic;
    using System.Diagnostics;
    using System.Linq;
    using System.Net;
    using System.Net.Http;
    using System.Reflection;
    using System.Security.Principal;
    using System.Text;
    using System.Threading.Tasks;
    using ApplicationInsights;
    using Newtonsoft.Json;
    using static Endpoint;

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
        public const string JsonMediaType = "application/json";

        /// <summary>
        ///  The header name for the RequestId that the API adds for post-mortem diagnostics.
        /// </summary>
        public const string RequestIdHeader = "Request-ID";

        /// <summary>
        ///  The header name for the RequestId that clients can set for tracking an individual request
        ///  during post-mortem diagnostics.
        /// </summary>
        public const string MSClientRequestIdHeader = "Client-Request-ID";

        /// <summary>
        /// The header name for a special header that the API uses for telemetry/tracking of API clients.
        /// </summary>
        public const string ClientNameHeader = "X-ClientName";

        /// <summary>
        /// The Application Insights client that will be used for "logging" all of the user requests
        /// </summary>
        private static TelemetryClient telemetryClient = new TelemetryClient();

        /// <summary>
        /// Stores the relevant info for each of the possible REST endpoints that we may proxy to,
        /// indexed by TenantId, and then by endpoint type.
        /// </summary>
        private static Dictionary<string, TenantEndpointCollection> endpointByTenantId = new Dictionary<string, TenantEndpointCollection>();

        /// <summary>
        /// Stores the relevant info for each of the possible REST endpoints that we may proxy to,
        /// indexed by Tenant Friendly Name, and then by endpoint type.
        /// </summary>
        private static Dictionary<string, TenantEndpointCollection> endpointByTenantName = new Dictionary<string, TenantEndpointCollection>();

        /// <summary>
        /// The default TenantId that should be used for determining the appropriate
        /// <see cref="Endpoint"/> to use for an incoming request when one has not been
        /// explicitly specified.
        /// </summary>
        private static string defaultTenantId = null;

        /// <summary>
        /// Configures the endpoints that <see cref="ProxyManager"/> will use when processing
        /// incoming requests.
        /// </summary>
        /// <param name="endpoints">
        /// A list of <see cref="Endpoint"/>s that define that set of endpoints that requests
        /// can be processed on by the <see cref="ProxyManager"/>.
        /// </param>
        /// <param name="defaultTenantId">The default TenantId that should be used when the request
        /// does not specify one explicitly.
        /// </param>
        public static void Configure(List<Endpoint> endpoints, string defaultTenantId)
        {
            foreach (Endpoint endpoint in endpoints)
            {
                string tenantId = endpoint.TenantId.ToLowerInvariant();
                string tenantFriendlyName = endpoint.TenantFriendlyName.ToLowerInvariant();

                TenantEndpointCollection tenantEndpointCollection;
                if (ProxyManager.endpointByTenantId.TryGetValue(tenantId, out tenantEndpointCollection))
                {
                    tenantEndpointCollection.Add(endpoint);
                    ProxyManager.endpointByTenantId[tenantId] = tenantEndpointCollection;
                }
                else
                {
                    tenantEndpointCollection = new TenantEndpointCollection(endpoint.TenantId, endpoint.TenantFriendlyName);
                    tenantEndpointCollection.Add(endpoint);
                    ProxyManager.endpointByTenantId.Add(tenantId, tenantEndpointCollection);
                }

                if (ProxyManager.endpointByTenantName.TryGetValue(tenantFriendlyName, out tenantEndpointCollection))
                {
                    tenantEndpointCollection.Add(endpoint);
                    ProxyManager.endpointByTenantName[tenantFriendlyName] = tenantEndpointCollection;
                }
                else
                {
                    tenantEndpointCollection = new TenantEndpointCollection(endpoint.TenantId, endpoint.TenantFriendlyName);
                    tenantEndpointCollection.Add(endpoint);
                    ProxyManager.endpointByTenantName.Add(tenantFriendlyName, tenantEndpointCollection);
                }
            }

            if (!string.IsNullOrWhiteSpace(defaultTenantId))
            {
                ProxyManager.defaultTenantId = defaultTenantId.ToLowerInvariant();
            }
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
        /// <param name="tenantId">
        /// [Optional] The tenantId that should be used for the request if the proxy supports
        /// multiple tenants.  Mutually exclusive with <paramref name="tenantName"/> since
        /// <paramref name="tenantName"/> is a "friendly" version of this value.  If neither this
        /// nor <paramref name="tenantName"/> are provided, the default TenantId will be used for
        /// this request.
        /// </param>
        /// <param name="tenantName">
        /// [Optional] The friendly name of the <paramref name="tenantId"/> that should be used for
        /// the request if the proxy supports multiple tenants.  Mutually exclusive with
        /// <paramref name="tenantId"/> since this is a friendly name version of that value.
        /// If neither this nor <paramref name="tenantId"/> are provided, the default TenantId will
        /// be used for this request.
        /// </param>
        /// <param name="endpointType">The type of endpoint that should be used for the request.</param>
        /// <param name="clientRequestId">
        /// An ID that a client may have set in the header (which we must proxy) to track an individual request.
        /// </param>
        /// <param name="clientName">
        /// The name of the requesting client that we can pass on to the API via a special header
        /// for tracking purposes.
        /// </param>
        /// <returns>The <see cref="HttpResponseMessage"/> to be sent to the user.</returns>
        public static async Task<HttpResponseMessage> PerformRequestAsync(
            string pathAndQuery,
            HttpMethod method,
            IPrincipal onBehalfOf,
            string body = null,
            string tenantId = null,
            string tenantName = null,
            EndpointType endpointType = EndpointType.Prod,
            string clientRequestId = null,
            string clientName = null)
        {
            // We'll track how long this takes, for telemetry purposes.
            Stopwatch stopwatch = Stopwatch.StartNew();

            // Assume ok unless we find out otherwise.
            HttpStatusCode statusCode = HttpStatusCode.OK;

            // We want to record the request header for every request in case we need to look up failures later.
            string requestId = string.Empty;

            // We also want to store the ClientId so that it's easier to see distribution of requests across Clients.
            string clientId = string.Empty;

            try
            {
                Endpoint endpoint = null;
                HttpResponseMessage response;
                if (ProxyManager.TryGetEndpoint(tenantId, tenantName, endpointType, out endpoint, out response))
                {
                    clientId = endpoint.ClientId;
                    response = await endpoint.PerformRequestAsync(pathAndQuery, method, onBehalfOf, body, clientRequestId, clientName);
                }

                // We'll capture the status code for use in the finally block.
                statusCode = response.StatusCode;

                // Get any of the request ID headers that can be used for post-mortem diagnostics.  We'll use them in the finally block.
                IEnumerable<string> headerValues;
                if (response.Headers.TryGetValues(ProxyManager.RequestIdHeader, out headerValues))
                {
                    requestId = headerValues.FirstOrDefault();
                }

                if (response.Headers.TryGetValues(ProxyManager.MSClientRequestIdHeader, out headerValues))
                {
                    // If the client supplied a clientRequestId, the value we're getting back from the API should be identical.
                    clientRequestId = headerValues.FirstOrDefault();
                }

                return response;
            }
            finally
            {
                stopwatch.Stop();
                ProxyManager.LogTelemetryEvent(
                    onBehalfOf.Identity.Name,
                    pathAndQuery,
                    method,
                    tenantId,
                    tenantName,
                    clientId,
                    endpointType,
                    statusCode,
                    requestId,
                    clientRequestId,
                    stopwatch.Elapsed.TotalSeconds);
            }
        }

        /// <summary>
        /// Tries to get the <see cref="Endpoint"/> that should be used to execute the request
        /// with the specified properties.
        /// </summary>
        /// <param name="tenantId">
        /// [Optional] The tenantId that should be used for the request if the proxy supports
        /// multiple tenants.  Mutually exclusive with <paramref name="tenantName"/> since
        /// <paramref name="tenantName"/> is a "friendly" version of this value.  If neither this
        /// nor <paramref name="tenantName"/> are provided, the default TenantId will be used for
        /// this request.
        /// </param>
        /// <param name="tenantName">
        /// [Optional] The friendly name of the <paramref name="tenantId"/> that should be used for
        /// the request if the proxy supports multiple tenants.  Mutually exclusive with
        /// <paramref name="tenantId"/> since this is a friendly name version of that value.
        /// If neither this nor <paramref name="tenantId"/> are provided, the default TenantId will
        /// be used for this request.
        /// </param>
        /// <param name="endpointType">The type of endpoint that should be used for the request.</param>
        /// <param name="endpoint">
        /// The resolved <see cref="Endpoint"/> that should be used for this request.
        /// </param>
        /// <param name="errorResponse">
        /// This contains the <see cref="HttpResponseMessage"/> that should be returned to the user
        /// with the appropriate explanation if we are unable to determine a valid
        /// <see cref="Endpoint"/> to execute this request on.
        /// </param>
        /// <returns>true if a valid <see cref="Endpoint"/> was found; false otherwise.</returns>
        /// <remarks>
        /// We are intentionally trying to encapsulate the exception handling within here, hence the
        /// "Try" naming scheme that returns a boolean with <paramref name="endpoint"/> and
        /// <paramref name="errorResponse"/> as out parameters.
        /// <para />
        /// When both tenantId and tenantName are specified, it will be considered a failure case.
        /// </remarks>
        private static bool TryGetEndpoint(
            string tenantId,
            string tenantName,
            EndpointType endpointType,
            out Endpoint endpoint,
            out HttpResponseMessage errorResponse)
        {
            endpoint = null;
            errorResponse = null;
            string errorMessage = string.Empty;
            TenantEndpointCollection tenantEndpointCollection;

            try
            {
                if (string.IsNullOrWhiteSpace(tenantId) && string.IsNullOrWhiteSpace(tenantName))
                {
                    if (string.IsNullOrWhiteSpace(ProxyManager.defaultTenantId))
                    {
                        errorMessage = "No TenantId was specified with this request, and this Proxy is not configured with a default TenantId.";
                        return false;
                    }
                    else
                    {
                        if (ProxyManager.endpointByTenantId.TryGetValue(ProxyManager.defaultTenantId, out tenantEndpointCollection))
                        {
                            endpoint = tenantEndpointCollection.GetNextEndpoint(endpointType);
                            return true;
                        }
                        else
                        {
                            errorMessage = "No TenantId was specified with this request, and the default TenantId for this Proxy is misconfigured.";
                            return false;
                        }
                    }
                }
                else if (!string.IsNullOrWhiteSpace(tenantId) && !string.IsNullOrWhiteSpace(tenantName))
                {
                    errorMessage = "Do not specify BOTH TenantId and TenantName.  Only specify one of those values to avoid ambiguity.";
                    return false;
                }
                else if (!string.IsNullOrWhiteSpace(tenantId))
                {
                    if (ProxyManager.endpointByTenantId.TryGetValue(tenantId.ToLowerInvariant(), out tenantEndpointCollection))
                    {
                        endpoint = tenantEndpointCollection.GetNextEndpoint(endpointType);
                        return true;
                    }
                    else
                    {
                        errorMessage = string.Format(
                            "This Proxy is not configured to handle requests for the requested TenantId [{0}].",
                            tenantId);
                        return false;
                    }
                }
                else
                {
                    if (ProxyManager.endpointByTenantName.TryGetValue(tenantName.ToLowerInvariant(), out tenantEndpointCollection))
                    {
                        endpoint = tenantEndpointCollection.GetNextEndpoint(endpointType);
                        return true;
                    }
                    else
                    {
                        errorMessage = string.Format(
                            "This Proxy is not configured to handle requests for the requested Tenant [{0}].",
                            tenantName);
                        return false;
                    }
                }
            }
            catch (KeyNotFoundException ex)
            {
                errorMessage = ex.Message;
                return false;
            }
            finally
            {
                if (endpoint == null)
                {
                    const string ErrorMessageFormat = "{{\"code\":\"BadRequest\", \"message\":{0}}}";
                    string formattedError = string.Format(ErrorMessageFormat, JsonConvert.ToString(errorMessage));
                    errorResponse = new HttpResponseMessage(HttpStatusCode.BadRequest)
                    {
                        Content = new StringContent(formattedError, Encoding.UTF8, ProxyManager.JsonMediaType)
                    };
                }
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
        /// <param name="tenantId">The TenantId of the account that this request was for.</param>
        /// <param name="tenantName">The friendly name of <paramref name="tenantId"/>.</param>
        /// <param name="clientId">The id of the <see cref="Endpoint"/> that owned the request.</param>
        /// <param name="endpointType">The type of endpoint that should be used for the request.</param>
        /// <param name="statusCode">The <see cref="HttpStatusCode"/> for the result of the request.</param>
        /// <param name="requestId">The ID given to the request by the API to enable post-mortem analysis.</param>
        /// <param name="clientRequestId">
        /// An ID that a client may have set in the header to track an individual request.
        /// </param>
        /// <param name="duration">The total number of seconds that the request took to complete.</param>
        private static void LogTelemetryEvent(
            string userName,
            string pathAndQuery,
            HttpMethod method,
            string tenantId,
            string tenantName,
            string clientId,
            EndpointType endpointType,
            HttpStatusCode statusCode,
            string requestId,
            string clientRequestId,
            double duration)
        {
            ProxyManager.telemetryClient.Context.Session.Id = System.Guid.NewGuid().ToString();
            ProxyManager.telemetryClient.Context.Component.Version = Assembly.GetExecutingAssembly().GetName().Version.ToString();

            Dictionary<string, string> properties = new Dictionary<string, string>();
            properties.Add("UserName", userName);
            properties.Add("PathAndQuery", pathAndQuery);
            properties.Add("Method", method.ToString());
            properties.Add("StatusCode", statusCode.ToString());
            properties.Add("RequestId", requestId);
            properties.Add("ClientRequestId", clientRequestId);
            properties.Add("EndpointType", endpointType.ToString());
            properties.Add("TenantId", tenantId);
            properties.Add("TenantFriendlyName", tenantName);
            properties.Add("ClientId", clientId);

            Dictionary<string, double> metrics = new Dictionary<string, double>();
            metrics.Add("Duration", duration);

            ProxyManager.telemetryClient.TrackEvent("ProxyRequest", properties, metrics);
        }
    }
}
