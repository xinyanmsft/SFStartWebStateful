using Microsoft.Owin;
using Microsoft.ServiceFabric.Services.Communication.Client;
using System;
using System.Fabric;
using System.Fabric.Health;
using System.Linq;
using System.Net.Http;
using System.Threading.Tasks;

namespace Application1.Gateway
{
    /// <summary>
    /// An Owin middleware to dispatch incoming web requests to HTTP stateful backend services.
    /// </summary>
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

            HttpRequestDispatcherProvider provider = new HttpRequestDispatcherProvider(null, new[] { new ExceptionHandler(_serviceContext) }, Guid.NewGuid().ToString());
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
}
