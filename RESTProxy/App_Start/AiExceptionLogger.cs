// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

namespace Microsoft.Windows.Source.StoreBroker.RestProxy
{
    using System.Web.Http.ExceptionHandling;
    using Microsoft.ApplicationInsights;

    /// <summary>
    /// Will log exceptions to Application Insights.
    /// </summary>
    public class AiExceptionLogger : ExceptionLogger
    {
        /// <summary>
        /// The telemetry client that will be used for logging the exception
        /// </summary>
        private static TelemetryClient telemetryClient = new TelemetryClient();

        /// <summary>
        /// Called when an exception has occurred.
        /// </summary>
        /// <param name="context">The exception logger context.</param>
        /// <remarks>
        /// When overridden in a derived class, logs the exception synchronously.
        /// </remarks>
        public override void Log(ExceptionLoggerContext context)
        {
            if (context != null && context.Exception != null)
            {
                AiExceptionLogger.telemetryClient.TrackException(context.Exception);
            }

            base.Log(context);
        }
    }
}