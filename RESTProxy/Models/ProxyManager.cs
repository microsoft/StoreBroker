// Copyright (c) Microsoft Corporation. All rights reserved.

namespace Microsoft.Windows.Source.StoreBroker.RestProxy.Models
{
    using System.Collections.Generic;
    using System.Diagnostics;
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
        /// The Application Insights client that will be used for "logging" all of the user requests
        /// </summary>
        private static TelemetryClient telemetryClient = new TelemetryClient();

        /// <summary>
        /// Stores the relevant info for each of the possible REST endpoints that we may proxy to,
        /// indexed by TenantId, and then by endpoint type.
        /// </summary>
        private static Dictionary<string, Dictionary<EndpointType, Endpoint>> endpointByTenantId = new Dictionary<string, Dictionary<EndpointType, Endpoint>>();

        /// <summary>
        /// Stores the relevant info for each of the possible REST endpoints that we may proxy to,
        /// indexed by Tenant Friendly Name, and then by endpoint type.
        /// </summary>
        private static Dictionary<string, Dictionary<EndpointType, Endpoint>> endpointByTenantName = new Dictionary<string, Dictionary<EndpointType, Endpoint>>();

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
                // To maintain operational integrity, we don't want external entities to have
                // access to the endpoints being used when ProxyManager is running.  Therefore,
                // we will duplicate the endpoint being passed-in during configuration, and that
                // duplicate is what will be shared between our private dictionaries.
                Endpoint duplicatedEndpoint = endpoint.Duplicate();
                string tenantId = endpoint.TenantId.ToLowerInvariant();
                string tenantFriendlyName = endpoint.TenantFriendlyName.ToLowerInvariant();

                Dictionary<EndpointType, Endpoint> endpointsByType;
                if (ProxyManager.endpointByTenantId.TryGetValue(tenantId, out endpointsByType))
                {
                    endpointsByType.Add(endpoint.Type, duplicatedEndpoint);
                    ProxyManager.endpointByTenantId[tenantId] = endpointsByType;
                }
                else
                {
                    endpointsByType = new Dictionary<EndpointType, Endpoint>();
                    endpointsByType.Add(endpoint.Type, duplicatedEndpoint);
                    ProxyManager.endpointByTenantId.Add(tenantId, endpointsByType);
                }

                if (ProxyManager.endpointByTenantName.TryGetValue(tenantFriendlyName, out endpointsByType))
                {
                    endpointsByType.Add(endpoint.Type, duplicatedEndpoint);
                    ProxyManager.endpointByTenantName[tenantFriendlyName] = endpointsByType;
                }
                else
                {
                    endpointsByType = new Dictionary<EndpointType, Endpoint>();
                    endpointsByType.Add(endpoint.Type, duplicatedEndpoint);
                    ProxyManager.endpointByTenantName.Add(tenantFriendlyName, endpointsByType);
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
        /// <returns>The <see cref="HttpResponseMessage"/> to be sent to the user.</returns>
        public static async Task<HttpResponseMessage> PerformRequestAsync(
            string pathAndQuery,
            HttpMethod method,
            IPrincipal onBehalfOf,
            string body = null,
            string tenantId = null,
            string tenantName = null,
            EndpointType endpointType = EndpointType.Prod)
        {
            // We'll track how long this takes, for telemetry purposes.
            Stopwatch stopwatch = Stopwatch.StartNew();

            // Assume ok unless we find out otherwise.
            HttpStatusCode statusCode = HttpStatusCode.OK;

            try
            {
                Endpoint endpoint = null;
                HttpResponseMessage response;
                if (ProxyManager.TryGetEndpoint(tenantId, tenantName, endpointType, out endpoint, out response))
                {
                    response = await endpoint.PerformRequestAsync(pathAndQuery, method, onBehalfOf, body);
                }

                statusCode = response.StatusCode; // used in the finally block
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
                    endpointType,
                    statusCode,
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
            Dictionary<EndpointType, Endpoint> endpointByType;

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
                        if (ProxyManager.endpointByTenantId.TryGetValue(ProxyManager.defaultTenantId, out endpointByType))
                        {
                            if (!endpointByType.TryGetValue(endpointType, out endpoint))
                            {
                                errorMessage = string.Format(
                                    "No TenantId was specified with this request, and the default TenantId for this Proxy is not configured to handle requests for the specified endpoint type [{0}].",
                                    endpointType.ToString());
                                return false;
                            }
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
                    if (ProxyManager.endpointByTenantId.TryGetValue(tenantId.ToLowerInvariant(), out endpointByType))
                    {
                        if (!endpointByType.TryGetValue(endpointType, out endpoint))
                        {
                            errorMessage = string.Format(
                                "This Proxy is not configured to handle requests for TenantId [{0}] with the endpoint type of [{1}].",
                                tenantId,
                                endpointType.ToString());
                            return false;
                        }
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
                    if (ProxyManager.endpointByTenantName.TryGetValue(tenantName.ToLowerInvariant(), out endpointByType))
                    {
                        if (!endpointByType.TryGetValue(endpointType, out endpoint))
                        {
                            errorMessage = string.Format(
                                "This Proxy is not configured to handle requests for Tenant [{0}] with the endpoint type of [{1}].",
                                tenantName,
                                endpointType.ToString());
                            return false;
                        }
                    }
                    else
                    {
                        errorMessage = string.Format(
                            "This Proxy is not configured to handle requests for the requested Tenant [{0}].",
                            tenantName);
                        return false;
                    }
                }

                return true;
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
        /// <param name="endpointType">The type of endpoint that should be used for the request.</param>
        /// <param name="statusCode">The <see cref="HttpStatusCode"/> for the result of the request.</param>
        /// <param name="duration">The total number of seconds that the request took to complete.</param>
        private static void LogTelemetryEvent(
            string userName,
            string pathAndQuery,
            HttpMethod method,
            string tenantId,
            string tenantName,
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
            properties.Add("TenantId", tenantId);
            properties.Add("TenantFriendlyName", tenantName);

            Dictionary<string, double> metrics = new Dictionary<string, double>();
            metrics.Add("Duration", duration);

            ProxyManager.telemetryClient.TrackEvent("ProxyRequest", properties, metrics);
        }
    }
}