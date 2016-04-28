using Microsoft.ServiceFabric.Services.Communication.Client;
using System.Fabric;
using System.Fabric.Health;

namespace Application1.Gateway
{
    /// <summary>
    /// Exceptions are sent to Service Fabric health system.
    /// </summary>
    internal class ExceptionHandler : IExceptionHandler
    {
        private ServiceContext _serviceContext;

        public ExceptionHandler(ServiceContext serviceContext)
        {
            _serviceContext = serviceContext;
        }

        public bool TryHandleException(ExceptionInformation exceptionInformation, OperationRetrySettings retrySettings, out ExceptionHandlingResult result)
        {
            ServiceEventSource.Current.ReportServiceHealth(_serviceContext, HealthState.Error, "Exception");

            result = new ExceptionHandlingThrowResult();
            return true;
        }
    }
}
