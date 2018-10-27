// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

namespace Microsoft.Windows.Source.StoreBroker.RestProxy
{
    using System.Collections.Generic;
    using System.Web.Http;
    using System.Web.Http.ExceptionHandling;
    using ApplicationInsights.Extensibility;
    using Azure;
    using Models;
    using Newtonsoft.Json;
    using WindowsAzure.ServiceRuntime;
    using static Models.Endpoint;

    /// <summary>
    /// The central class used for configuring the WebApi with the service.
    /// </summary>
    public static class WebApiConfig
    {
        /// <summary>
        /// Performs the necessary work to register the WebApi with
        /// the active service configuration.
        /// </summary>
        /// <param name="config">The service configuration</param>
        public static void Register(HttpConfiguration config)
        {
            // Web API routes
            config.MapHttpAttributeRoutes();

            // This is a really ugly, generic route.  All we're trying to do is capture every
            // possible REST API path that might come in, and route it to the same controller
            // that only has a single method, because all we want to do is turn around and send
            // the original query command (and any accompanying body) directly to the real REST
            // endpoint; there's no benefit that we would gain by making separate controllers
            // that truly mirror all of the possible real commands.
            config.Routes.MapHttpRoute(
                name: "Root",  // This name is friendly and has no impact to the code.
                routeTemplate: "{version}/{annotation}/{command}/{commandId}/{subCommand}/{subCommandId}/{subCommand2}/{subCommandId2}/{subCommand3}/{subCommandId3}/{subCommand4}/{subCommandId4}/{subCommand5}/{subCommandId5}/{subCommand6}/{subCommandId6}/{subCommand7}/{subCommandId7}",
                defaults: new
                {
                    controller = "root", // This tells it to route these requests to "RootController"
                    command = RouteParameter.Optional,
                    commandId = RouteParameter.Optional,
                    subCommand = RouteParameter.Optional,
                    subCommandId = RouteParameter.Optional,
                    subCommand2 = RouteParameter.Optional,
                    subCommandId2 = RouteParameter.Optional,
                    subCommand3 = RouteParameter.Optional,
                    subCommandId3 = RouteParameter.Optional,
                    subCommand4 = RouteParameter.Optional,
                    subCommandId4 = RouteParameter.Optional,
                    subCommand5 = RouteParameter.Optional,
                    subCommandId5 = RouteParameter.Optional,
                    subCommand6 = RouteParameter.Optional,
                    subCommandId6 = RouteParameter.Optional,
                    subCommand7 = RouteParameter.Optional,
                    subCommandId7 = RouteParameter.Optional,
                });

            WebApiConfig.ConfigureTelemetry(config);
            ConfigureProxyManager();
        }

        /// <summary>
        /// Performs the necessary work to configure the Telemetry
        /// for this service
        /// </summary>
        /// <param name="config">The service configuration</param>
        /// <remarks>
        /// Current behavior is to:
        ///  * Set default values for new TelemetryClients
        ///  * Configure automatic exception logging
        /// </remarks>
        private static void ConfigureTelemetry(HttpConfiguration config)
        {
            // Sets the default configuration for any newly created TelemetryClient
            string appInsightsKey = string.Empty;
            if (RoleEnvironment.IsAvailable)
            {
                appInsightsKey = CloudConfigurationManager.GetSetting("APPINSIGHTS_INSTRUMENTATIONKEY");
            }

            if (!string.IsNullOrWhiteSpace(appInsightsKey))
            {
                // If we have an instrumentation key, configure App Insights
                TelemetryConfiguration.Active.InstrumentationKey = appInsightsKey;
            }
            else
            {
                // Otherwise, disable it
                TelemetryConfiguration.Active.DisableTelemetry = true;
            }

            // Causes any unhandled exception to be logged to Application Insights.
            config.Services.Add(typeof(IExceptionLogger), new AiExceptionLogger());
        }

        /// <summary>
        /// Retrieves the configuration settings from the cloud deployment, and configures
        /// the ProxyManager with these settings.
        /// </summary>
        private static void ConfigureProxyManager()
        {
            // DEBUGGING NOTE: When debugging the RESTProxy service directly (not using the
            // AzureService project), it won't be reading the values from your ServiceConfiguration
            // files, so these two values will come back empty.  You'll need to temporarily modify
            // this code and directly set the values for defaultTenantId and configJson.
            // When doing that, you'll need to replace any &quot; with \".
            // Also keep in mind that in that scenario, you won't have access to the encryption
            // certificate stored in Azure, so you'll need to modify your EndpointJsonConfig by
            // changing clientSecretEncrypted to the *unencrypted* values and clearing out the
            // values for the clientSecretCertificateThumbprints.
            string defaultTenantId = CloudConfigurationManager.GetSetting("DefaultTenantId");
            string configJson = CloudConfigurationManager.GetSetting("EndpointJsonConfig");

            if (!string.IsNullOrWhiteSpace(configJson))
            {
                List<Endpoint> endpoints = JsonConvert.DeserializeObject<List<Endpoint>>(configJson);
                Models.ProxyManager.Configure(endpoints, defaultTenantId);
            }
        }
    }
}
