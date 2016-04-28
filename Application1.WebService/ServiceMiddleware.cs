using Microsoft.Owin;
using System.Diagnostics;
using System.Fabric;
using System.Threading.Tasks;

namespace Application1.WebService
{
    internal class ServiceMiddleware : OwinMiddleware
    {
        private ServiceContext _serviceContext;

        public ServiceMiddleware(OwinMiddleware next, ServiceContext serviceContext) : base(next)
        {
            _serviceContext = serviceContext;
        }

        public override async Task Invoke(IOwinContext context)
        {
            if (this.Next == null)
                return;

            Stopwatch s = new Stopwatch();
            s.Start();

            try
            {
                ServiceEventSource.Current.ServiceRequestStart(context.Request.Path.ToString());

                context.Response.OnSendingHeaders(state =>
                {
                    context.Response.Headers["Cache-Control"] = "no-cache";
#if DEBUG
                    context.Response.Headers["X-Served-By"] = _serviceContext.ServiceName.ToString();
#endif
                }, context);

                await this.Next.Invoke(context);
            }
            finally
            {
                s.Stop();
                ServiceEventSource.Current.ServiceRequestStop(context.Request.Path.ToString(), s.ElapsedMilliseconds);
            }
        }
    }
}
