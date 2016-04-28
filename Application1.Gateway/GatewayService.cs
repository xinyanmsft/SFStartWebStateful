using System;
using System.Collections.Generic;
using System.Fabric;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.ServiceFabric.Services.Communication.Runtime;
using Microsoft.ServiceFabric.Services.Runtime;
using Owin;
using Microsoft.Owin;
using Microsoft.Owin.StaticFiles;
using Microsoft.Owin.FileSystems;
using Microsoft.ServiceFabric.Services.Client;

namespace Application1.Gateway
{
    /// <summary>
    /// The FabricRuntime creates an instance of this class for each service type instance. 
    /// </summary>
    internal sealed class GatewayService : StatelessService
    {
        public GatewayService(StatelessServiceContext context)
            : base(context)
        { }

        /// <summary>
        /// Optional override to create listeners (like tcp, http) for this service instance.
        /// </summary>
        /// <returns>The collection of listeners.</returns>
        protected override IEnumerable<ServiceInstanceListener> CreateServiceInstanceListeners()
        {
            List<ServiceInstanceListener> listeners = new List<ServiceInstanceListener>();

            List<GatewayOption> options = new List<GatewayOption>();
            GatewayOption option1 = new GatewayOption()
            {
                Path = "/api/webservice",
                ServiceUri = new Uri("fabric:/Application1.FabricApplication/WebService"),
                GetServicePartitionKey = context =>
                {
                    var pathSegments = context.Request.Path.Value.Split(new[] { '/' }, StringSplitOptions.RemoveEmptyEntries);
                    string id = pathSegments[pathSegments.Length - 1];
                    return new ServicePartitionKey(Fnv1aHashCode.Get64bitHashCode(id));
                }
            };
            options.Add(option1);
            
            return new ServiceInstanceListener[] { new ServiceInstanceListener(serviceContext => new OwinCommunicationListener((appBuilder) =>
            {
                foreach(GatewayOption option in options)
                {
                    appBuilder.Map(option.Path, subApp =>
                    {
                        subApp.Use(typeof(GatewayMiddleware), serviceContext, option);
                    });
                }

                appBuilder.UseFileServer(new FileServerOptions()
                {
                    RequestPath = PathString.Empty,
                    FileSystem = new PhysicalFileSystem(@".\Contents")
                });

            }, serviceContext, ServiceEventSource.Current, "GatewayServiceEndpoint"))};
        }
    }
}
