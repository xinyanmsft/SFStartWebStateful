using Microsoft.Owin;
using Microsoft.ServiceFabric.Services.Communication.Client;
using System;
using System.Collections.Generic;
using System.Fabric;
using System.Fabric.Health;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Text;
using System.Threading.Tasks;

namespace Application1.Gateway
{
    internal class GatewayMiddleware : OwinMiddleware
    {
        private ServiceContext _serviceContext;
        private GatewayOption _option;

        public GatewayMiddleware(OwinMiddleware next, ServiceContext serviceContext, GatewayOption option) : base(next)
        {
            _serviceContext = serviceContext;
            _option = option;
        }

        public override async Task Invoke(IOwinContext context)
        {
            if (context == null)
            {
                throw new ArgumentNullException(nameof(context));
            }

            string correlationId = Guid.NewGuid().ToString();
            HttpRequestDispatcherProvider provider = new HttpRequestDispatcherProvider(null, new[] { new ExceptionHandler(_serviceContext) }, correlationId);
            ServicePartitionClient<HttpRequestDispatcher> servicePartitionClient = new ServicePartitionClient<HttpRequestDispatcher>(provider, 
                                                                                                                                     _option.ServiceUri, 
                                                                                                                                     _option.GetServicePartitionKey?.Invoke(context));
            await servicePartitionClient.InvokeWithRetryAsync(async dispatcher =>
            {
                var requestMessage = new HttpRequestMessage();
                requestMessage.Method = new HttpMethod(context.Request.Method);

                if (!StringComparer.OrdinalIgnoreCase.Equals(context.Request.Method, "GET") &&
                    !StringComparer.OrdinalIgnoreCase.Equals(context.Request.Method, "HEAD") &&
                    !StringComparer.OrdinalIgnoreCase.Equals(context.Request.Method, "DELETE") &&
                    !StringComparer.OrdinalIgnoreCase.Equals(context.Request.Method, "TRACE"))
                {
                    requestMessage.Content = new StreamContent(context.Request.Body);
                }

                foreach (var header in context.Request.Headers)
                {
                    if (!requestMessage.Headers.TryAddWithoutValidation(header.Key, header.Value.ToArray()) && requestMessage.Content != null)
                    {
                        requestMessage.Content?.Headers.TryAddWithoutValidation(header.Key, header.Value.ToArray());
                    }
                }

                var baseAddress = dispatcher.BaseAddress;
                var pathAndQuery = PathString.FromUriComponent(baseAddress) + context.Request.Path + context.Request.QueryString;
                requestMessage.RequestUri = new Uri($"{baseAddress.Scheme}://{baseAddress.Host}:{baseAddress.Port}{pathAndQuery}", UriKind.Absolute);
                requestMessage.Headers.Host = baseAddress.Host + ":" + baseAddress.Port;

                using (var responseMessage = await dispatcher.SendAsync(requestMessage, HttpCompletionOption.ResponseHeadersRead))
                {
                    context.Response.StatusCode = (int)responseMessage.StatusCode;
                    foreach (var header in responseMessage.Headers)
                    {
                        context.Response.Headers[header.Key] = String.Join(";", header.Value.ToArray());
                    }

                    foreach (var header in responseMessage.Content.Headers)
                    {
                        context.Response.Headers[header.Key] = String.Join(";", header.Value.ToArray());
                    }
                    context.Response.Headers.Remove("transfer-encoding");
                    await responseMessage.Content.CopyToAsync(context.Response.Body);
                }
            });
        }
    }

    internal class ExceptionHandler : IExceptionHandler
    {
        private ServiceContext _serviceContext;

        public ExceptionHandler(ServiceContext serviceContext)
        {
            _serviceContext = serviceContext;
        }

        public bool TryHandleException(ExceptionInformation exceptionInformation, OperationRetrySettings retrySettings, out ExceptionHandlingResult result)
        {
            FabricClient client = new FabricClient();
            HealthInformation info = new HealthInformation("Gateway", "Exception", HealthState.Error);
            ServiceHealthReport health = new ServiceHealthReport(_serviceContext.ServiceName, info);
            client.HealthManager.ReportHealth(health);

            result = new ExceptionHandlingThrowResult();
            return true;
        }
    }
}
