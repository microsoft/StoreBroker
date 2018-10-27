// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

namespace Microsoft.Windows.Source.StoreBroker.RestProxy.Models
{
    using System;
    using System.Threading;
    using System.Threading.Tasks;

    /// <summary>
    /// Provides an implementation of a lock that can be safely used in combination
    /// with awaited async methods, as well as within a using statement.
    /// </summary>
    /// <remarks>
    /// Based on the initial Async Primitives work done by <c>Stephen Toub</c>:
    /// <c>https://blogs.msdn.microsoft.com/pfxteam/2012/02/12/building-async-coordination-primitives-part-6-asynclock/</c>
    /// </remarks>
    public sealed class AsyncLock
    {
        /// <summary>
        /// This semaphore is what provides the real locking functionality
        /// </summary>
        private readonly SemaphoreSlim semaphore = new SemaphoreSlim(1, 1);

        /// <summary>
        /// The task provided to the client when they have successfully gained
        /// the lock via the semaphore.  This allows the lock to be used within
        /// the context of a "using" statement.
        /// </summary>
        /// <remarks>
        /// To avoid unnecessary memory allocations, we cache this and always return
        /// the same instance.
        /// </remarks>
        private readonly Task<IDisposable> releaser;

        /// <summary>
        /// Initializes a new instance of the <see cref="AsyncLock"/> class.
        /// </summary>
        public AsyncLock()
        {
            this.releaser = Task.FromResult((IDisposable)new AsyncLockReleaser(this));
        }

        /// <summary>
        /// Gets the semaphore that is used to orchestrate the locking mechanic.
        /// </summary>
        private SemaphoreSlim Semaphore
        {
            get
            {
                return this.semaphore;
            }
        }

        /// <summary>
        /// Asynchronously wait for the lock to be acquired.
        /// </summary>
        /// <returns>
        /// An object whose <see cref="Dispose"/> method should be called to properly release the lock.
        /// </returns>
        public Task<IDisposable> LockAsync()
        {
            Task waitTask = this.semaphore.WaitAsync();
            if (waitTask.IsCompleted)
            {
                return this.releaser;
            }
            else
            {
                return waitTask.ContinueWith(
                    continuationFunction: (_, state) => (IDisposable)state,
                    state: this.releaser.Result,
                    cancellationToken: CancellationToken.None,
                    continuationOptions: TaskContinuationOptions.ExecuteSynchronously,
                    scheduler: TaskScheduler.Default);
            }
        }

        /// <summary>
        /// A helper class created for the sole purpose of enabling
        /// the <see cref="AsyncLock"/> to be used within the context of
        /// a "using" statement.
        /// </summary>
        private sealed class AsyncLockReleaser : IDisposable
        {
            /// <summary>
            /// A reference to the <see cref="AsyncLock"/> that the user
            /// currently has a lock with.
            /// </summary>
            private readonly AsyncLock toRelease;

            /// <summary>
            /// Initializes a new instance of the <see cref="AsyncLockReleaser"/> class.
            /// </summary>
            /// <param name="toRelease">
            /// The <see cref="AsyncLock"/> which has recently been acquired and will need
            /// to be properly released.
            /// </param>
            internal AsyncLockReleaser(AsyncLock toRelease)
            {
                this.toRelease = toRelease;
            }

            /// <summary>
            /// Releases the lock.
            /// </summary>
            public void Dispose()
            {
                this.toRelease.Semaphore.Release();
            }
        }
    }
}