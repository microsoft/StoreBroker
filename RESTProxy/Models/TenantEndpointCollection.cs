// Copyright (c) Microsoft Corporation. All rights reserved.

namespace Microsoft.Windows.Source.StoreBroker.RestProxy.Models
{
    using System.Collections.Generic;
    using System.Threading;

    /// <summary>
    /// Collects all of the endpoints that can be used for the same Tenant, and provides
    /// a mechanism to load-balance between them, round-robin style.
    /// </summary>
    public class TenantEndpointCollection
    {
        /// <summary>
        /// Gets the semaphore which provides locking functionality to ensure that this collection
        /// can safely and reliably alternate, round-robin style, between different Endpoints.
        /// </summary>
        private readonly SemaphoreSlim semaphore = new SemaphoreSlim(1, 1);

        /// <summary>
        /// Initializes a new instance of the <see cref="TenantEndpointCollection"/> class.
        /// </summary>
        /// <param name="tenantId">
        /// The tenantId that should be used for requests by this endpoint.
        /// </param>
        /// <param name="tenantFriendlyName">The friendly name for this endpoint.</param>
        public TenantEndpointCollection(string tenantId, string tenantFriendlyName)
        {
            this.TenantId = tenantId;
            this.TenantFriendlyName = tenantFriendlyName;
            this.EndpointsByType = new Dictionary<EndpointType, List<Endpoint>>();
            this.NextEndpointIndex = new Dictionary<EndpointType, int>();
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
        /// Gets or sets the actual collection of endpoints for this TenantId/TenantFriendlyName.
        /// </summary>
        private Dictionary<EndpointType, List<Endpoint>> EndpointsByType { get; set; }

        /// <summary>
        /// Gets or sets the index of the next Endpoint to use for a given EndpointType.
        /// </summary>
        private Dictionary<EndpointType, int> NextEndpointIndex { get; set; }

        /// <summary>
        /// Adds a new endpoint to this endpoint collection.
        /// </summary>
        /// <param name="endpoint">
        /// The endpoint that should be part of this collection.
        /// </param>
        /// <remarks>
        /// This endpoint should have the same TenantId as any other Endpoint in this collection.
        /// </remarks>
        public void Add(Endpoint endpoint)
        {
            // To maintain operational integrity, we don't want external entities to have
            // access to the endpoints being used when ProxyManager is running.  Therefore,
            // we will duplicate the endpoint being passed-in during configuration, and that
            // duplicate is what will be shared between our private dictionaries.
            Endpoint duplicatedEndpoint = endpoint.Duplicate();

            this.semaphore.Wait();
            try
            {
                List<Endpoint> typeEndpoints;
                if (this.EndpointsByType.TryGetValue(duplicatedEndpoint.Type, out typeEndpoints))
                {
                    typeEndpoints.Add(duplicatedEndpoint);
                    this.EndpointsByType[duplicatedEndpoint.Type] = typeEndpoints;
                }
                else
                {
                    typeEndpoints = new List<Endpoint>();
                    typeEndpoints.Add(duplicatedEndpoint);
                    this.EndpointsByType.Add(duplicatedEndpoint.Type, typeEndpoints);
                    this.NextEndpointIndex.Add(duplicatedEndpoint.Type, 0);
                }
            }
            finally
            {
                this.semaphore.Release();
            }
        }

        /// <summary>
        /// Rotates through all the <see cref="Endpoint"/>s in this collection, round-robin style,
        /// and retrieves the next available one for the specified <paramref name="endpointType"/>.
        /// </summary>
        /// <param name="endpointType">The type of endpoint that should be used for the request.</param>
        /// <returns>
        /// The next <see cref="Endpoint"/> in the collection that matches the specified type.
        /// </returns>
        /// <exception cref="KeyNotFoundException">
        /// No <see cref="Endpoint"/> is defined for the specified <paramref name="endpointType"/>.
        /// </exception>
        public Endpoint GetNextEndpoint(EndpointType endpointType)
        {
            try
            {
                this.semaphore.Wait();

                List<Endpoint> endpoints;
                if (this.EndpointsByType.TryGetValue(endpointType, out endpoints))
                {
                    int nextIndex = this.NextEndpointIndex[endpointType];
                    Endpoint endpoint = endpoints[nextIndex];

                    // Careful not to do a post-increment here, as the increment would happen _after_ the assignment.
                    // A pre-increment would work, but I'd argue that expliclty adding 1 here is more clear.
                    this.NextEndpointIndex[endpointType] = nextIndex + 1;
                    if (this.NextEndpointIndex[endpointType] >= endpoints.Count)
                    {
                        this.NextEndpointIndex[endpointType] = 0;
                    }

                    return endpoint;
                }
                else
                {
                    throw new KeyNotFoundException(string.Format(
                        "This Proxy is not configured to handle requests for Tenant [{0} ({1})] with the endpoint type of [{2}].",
                        this.TenantId,
                        this.TenantFriendlyName,
                        endpointType.ToString()));
                }
            }
            finally
            {
                this.semaphore.Release();
            }
        }
    }
}