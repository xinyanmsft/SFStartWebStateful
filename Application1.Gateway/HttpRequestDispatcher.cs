using Microsoft.ServiceFabric.Services.Communication.Client;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Net.Http;
using System.Text;
using System.Threading.Tasks;
using System.Fabric;
using System.Threading;
using Microsoft.ServiceFabric.Services.Client;

namespace Application1.Gateway
{
    public class HttpRequestDispatcher : HttpClient, ICommunicationClient
    {
        public HttpRequestDispatcher() : base()
        {
        }

        public HttpRequestDispatcher(HttpMessageHandler handler) : base(handler)
        {
        }

        public HttpRequestDispatcher(HttpMessageHandler handler, bool disposeHandler) : base(handler, disposeHandler)
        {
        }

        #region ICommunicationClient
        ResolvedServiceEndpoint ICommunicationClient.Endpoint { get; set; }
        string ICommunicationClient.ListenerName { get; set; }
        ResolvedServicePartition ICommunicationClient.ResolvedServicePartition { get; set; }
        #endregion ICommunicationClient
    }

    public class HttpRequestDispatcherProvider : CommunicationClientFactoryBase<HttpRequestDispatcher>
    {
        private readonly Func<HttpRequestDispatcher> _innerDispatcherProvider;

        public HttpRequestDispatcherProvider(IServicePartitionResolver servicePartitionResolver = null, IEnumerable<IExceptionHandler> exceptionHandlers = null, string traceId = null)
            : this(() => new HttpRequestDispatcher(), servicePartitionResolver, exceptionHandlers, traceId)
        {
        }

        public HttpRequestDispatcherProvider(Func<HttpRequestDispatcher> innerDispatcherProvider, IServicePartitionResolver servicePartitionResolver = null, IEnumerable<IExceptionHandler> exceptionHandlers = null, string traceId = null)
            : base(servicePartitionResolver, exceptionHandlers, traceId)
        {
            if (innerDispatcherProvider == null)
            {
                throw new ArgumentNullException(nameof(innerDispatcherProvider));
            }

            _innerDispatcherProvider = innerDispatcherProvider;
        }

        protected override void AbortClient(HttpRequestDispatcher client)
        {
            if (client != null)
            {
                client.Dispose();
            }
        }

        protected override Task<HttpRequestDispatcher> CreateClientAsync(string endpoint, CancellationToken cancellationToken)
        {
            var dispatcher = _innerDispatcherProvider.Invoke();
            dispatcher.BaseAddress = new Uri(endpoint, UriKind.Absolute);

            return Task.FromResult(dispatcher);
        }

        protected override bool ValidateClient(HttpRequestDispatcher client)
        {
            return client != null && client.BaseAddress != null;
        }

        protected override bool ValidateClient(string endpoint, HttpRequestDispatcher client)
        {
            return client != null && client.BaseAddress == new Uri(endpoint, UriKind.Absolute);
        }
    }
}
