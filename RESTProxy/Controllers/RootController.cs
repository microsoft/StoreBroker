// Copyright (c) Microsoft Corporation. All rights reserved.

namespace Microsoft.Windows.Source.StoreBroker.RestProxy.Controllers
{
    using System.Collections.Generic;
    using System.Diagnostics.CodeAnalysis;
    using System.Net.Http;
    using System.Text;
    using System.Threading.Tasks;
    using System.Web.Http;
    using Models;

    /// <summary>
    /// This controller is designed to handle all requests that come into the web service.
    /// </summary>
    public class RootController : ApiController
    {
        /// <summary>
        /// This _highly_ generic method should be able to capture all current and future
        /// REST API's exposed by the Store team.
        /// </summary>
        /// <returns>HttpResponseMessage to be seen by the user.</returns>
        /// <remarks>
        /// A Uri that will match this method looks like this:
        /// v1.0/my/{command}/{commandId}/{subCommand}/{subCommandId}/{subCommand2}/{subCommandId2}/{subCommand3}/{subCommandId3}/{subCommand4}/{subCommandId4}/{subCommand5}/{subCommandId5}
        /// (this is defined in WebApiConfig.cs).
        /// <para />
        /// We don't care at all about the parameters because all we end up doing is grabbing the
        /// full AbsoluteUri and $proxying$ that request to the real API.  This is very abnormal 
        /// usage of ASP.NET WebApi, but doing things this way makes the code SUPER-concise.
        /// <para />
        /// The only event where this method will ever need to be updated is if additional
        /// query parameters are added to the Store API.  In that event, the query parameters simply
        /// needed to be added to the parameter list in this method.  They will never actually
        /// be used, but the magic of WebApi means that it will be looking for a method on
        /// this controller that understands what to do with the query parameters.  The name of
        /// the new API query parameter must match exactly to the parameter that you add to this
        /// method.
        /// </remarks>
        [SuppressMessage("StyleCop.CSharp.DocumentationRules", "SA1611:ElementParametersMustBeDocumented", Justification = "The parameters are all irrelevant.")]
        [AcceptVerbs("GET", "DELETE", "PUT", "POST")]
        public async Task<HttpResponseMessage> RouteRequest(
            string version,
            string annotation,
            string command = null,
            string commandId = null,
            string subCommand = null,
            string subCommandId = null,
            string subCommand2 = null,
            string subCommandId2 = null,
            string subCommand3 = null,
            string subCommandId3 = null,
            string subCommand4 = null,
            string subCommandId4 = null,
            string subCommand5 = null,
            string subCommandId5 = null,
            int skip = -1,
            int top = -1)
        {
            // Grab the body (if it even exists)
            string body = Encoding.UTF8.GetString(await Request.Content.ReadAsByteArrayAsync());

            // Check to see if this should use the INT endpoint or stay with PROD.
            // We don't care about the value of the header...just its existence.
            IEnumerable<string> headerValues;
            ProxyManager.EndpointType endpointType = Request.Headers.TryGetValues("UseINT", out headerValues) ?
                ProxyManager.EndpointType.Int :
                ProxyManager.EndpointType.Prod;

            // Now, just proxy the request over to the real API.
            return await ProxyManager.PerformRequest(
                pathAndQuery: Request.RequestUri.PathAndQuery,
                method: Request.Method,
                onBehalfOf: Request.GetRequestContext().Principal,
                body: body,
                endpointType: endpointType);
        }
   }
}
