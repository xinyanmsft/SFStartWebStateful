using System.Fabric;
using System.Fabric.Health;
using System.Web.Http.Filters;

namespace Application1.WebService
{
    /// <summary>
    /// Exceptions are sent to Service Fabric health system.
    /// </summary>
    internal class ServiceExceptionFilterAttribute : ExceptionFilterAttribute
    {
        private ServiceContext _serviceContext;

        public ServiceExceptionFilterAttribute(ServiceContext context)
        {
            _serviceContext = context;
        }

        public override void OnException(HttpActionExecutedContext actionExecutedContext)
        {
            ServiceEventSource.Current.ReportServiceHealth(_serviceContext, HealthState.Error, "Exception");
        }
    }
}
