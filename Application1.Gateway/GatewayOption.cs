using Microsoft.Owin;
using Microsoft.ServiceFabric.Services.Client;
using Microsoft.ServiceFabric.Services.Communication.Client;
using System;

namespace Application1.Gateway
{
    public class GatewayOption
    {
        public string Path { get; set; }

        public string ListenerName { get; set; }

        public Uri ServiceUri { get; set; }

        public TargetReplicaSelector TargetReplicaSelector { get; set; }
        
        public Func<IOwinContext, ServicePartitionKey> GetServicePartitionKey { get; set; }
    }
}
