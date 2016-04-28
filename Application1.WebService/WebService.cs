using System;
using System.Collections.Generic;
using System.Fabric;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.ServiceFabric.Data.Collections;
using Microsoft.ServiceFabric.Services.Communication.Runtime;
using Microsoft.ServiceFabric.Services.Runtime;

namespace Application1.WebService
{
    /// <summary>
    /// An instance of this class is created for each service replica by the Service Fabric runtime.
    /// </summary>
    internal sealed class WebService : StatefulService, IWebService
    {
        public WebService(StatefulServiceContext context)
            : base(context)
        { }

        public async Task<UserInfo> GetAsync(int id)
        {
            UserInfo result = null;

            var users = await this.StateManager.GetOrAddAsync<IReliableDictionary<string, UserInfo>>("users");
            using (var tx = this.StateManager.CreateTransaction())
            {
                string key = id.ToString();
                var info = await users.TryGetValueAsync(tx, key);
                if (info.HasValue)
                {
                    result = info.Value;
                }

                await tx.CommitAsync();
            }

            return result;
        }

        public async Task<bool> UpdateAsync(int id, UserInfo user)
        {
            bool result;

            var users = await this.StateManager.GetOrAddAsync<IReliableDictionary<string, UserInfo>>("users");
            using (var tx = this.StateManager.CreateTransaction())
            {
                string key = id.ToString();
                var info = await users.TryGetValueAsync(tx, key);
                if (info.HasValue)
                {
                    user.Id = id;
                    await users.SetAsync(tx, key, user);
                    result = true;
                }
                else
                {
                    result = false;
                }
                
                await tx.CommitAsync();
            }

            return result;
        }

        public async Task<bool> CreateAsync(int id, UserInfo user)
        {
            bool result;

            var users = await this.StateManager.GetOrAddAsync<IReliableDictionary<string, UserInfo>>("users");
            using (var tx = this.StateManager.CreateTransaction())
            {
                string key = id.ToString();
                var info = await users.TryGetValueAsync(tx, key);
                if (!info.HasValue)
                {
                    user.Id = id;
                    await users.SetAsync(tx, key, user);
                    result = true;
                }
                else
                {
                    result = false;
                }

                await tx.CommitAsync();
            }

            return result;
        }

        public async Task<bool> DeleteAsync(int id)
        {
            bool result;

            var users = await this.StateManager.GetOrAddAsync<IReliableDictionary<string, UserInfo>>("users");
            using (var tx = this.StateManager.CreateTransaction())
            {
                string key = id.ToString();
                var info = await users.TryRemoveAsync(tx, key);
                result = info.HasValue;
                await tx.CommitAsync();
            }

            return result;
        }

        /// <summary>
        /// Optional override to create listeners (e.g., HTTP, Service Remoting, WCF, etc.) for this service replica to handle client or user requests.
        /// </summary>
        /// <remarks>
        /// For more information on service communication, see http://aka.ms/servicefabricservicecommunication
        /// </remarks>
        /// <returns>A collection of listeners.</returns>
        protected override IEnumerable<ServiceReplicaListener> CreateServiceReplicaListeners()
        {
            return new ServiceReplicaListener[]
            {
                new ServiceReplicaListener(serviceContext => new OwinCommunicationListener((appBuilder) =>
                {
                    appBuilder.Use(typeof(ServiceMiddleware), this.Context);
                    Startup.ConfigureApp(appBuilder, this.Context, this);
                }, serviceContext, ServiceEventSource.Current, "ServiceEndpoint"))
            };
        }
    }
}
