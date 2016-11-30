// Copyright (c) Microsoft Corporation. All rights reserved.

namespace Microsoft.Windows.Source.StoreBroker.RestProxy
{
    using System.Web.Http;
    using System.Web.Http.ExceptionHandling;
    using ApplicationInsights.Extensibility;
    using Azure;
    using Microsoft.Web.Administration;
    using WindowsAzure.ServiceRuntime;

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
                routeTemplate: "{version}/{annotation}/{command}/{commandId}/{subCommand}/{subCommandId}/{subCommand2}/{subCommandId2}/{subCommand3}/{subCommandId3}/{subCommand4}/{subCommandId4}/{subCommand5}/{subCommandId5}",
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
                });

            WebApiConfig.ConfigureTelemetry(config);
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
    }
}
