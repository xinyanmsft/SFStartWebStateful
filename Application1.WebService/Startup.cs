using Application1.WebService.Controllers;
using Owin;
using System;
using System.Collections.Generic;
using System.Fabric;
using System.Fabric.Health;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Web.Http;
using System.Web.Http.Dependencies;
using System.Web.Http.Filters;

namespace Application1.WebService
{
    public static class Startup
    {
        // This code configures Web API. The Startup class is specified as a type
        // parameter in the WebApp.Start method.
        public static void ConfigureApp(IAppBuilder appBuilder, ServiceContext context, IWebService service)
        {
            // Configure Web API for self-host. 
            HttpConfiguration config = new HttpConfiguration();
            config.DependencyResolver = new ServiceDependencyResolver(config.DependencyResolver, service);
            config.Filters.Add(new ServiceExceptionFilterAttribute(context));

            config.Routes.MapHttpRoute(
                name: "DefaultApi",
                routeTemplate: "{controller}/{id}",
                defaults: new { id = RouteParameter.Optional }
            );

            
            appBuilder.UseWebApi(config);
        }
    }

    internal class ServiceDependencyResolver : IDependencyResolver
    {
        private IWebService _service;
        private IDependencyResolver _baseResolver;

        public ServiceDependencyResolver(IDependencyResolver baseResolver, IWebService service)
        {
            _baseResolver = baseResolver;
            _service = service;
        }

        public IDependencyScope BeginScope()
        {
            return new ServiceDependencyScope(_baseResolver.BeginScope(), _service);
        }

        public object GetService(Type serviceType)
        {
            return _baseResolver.GetService(serviceType);
        }

        public IEnumerable<object> GetServices(Type serviceType)
        {
            return _baseResolver.GetServices(serviceType);
        }

        public void Dispose()
        {
            _baseResolver.Dispose();
        }

        public class ServiceDependencyScope : IDependencyScope
        {
            private IDependencyScope _baseScope;
            private IWebService _service;

            public ServiceDependencyScope(IDependencyScope baseScope, IWebService service)
            {
                _baseScope = baseScope;
                _service = service;
            }

            public void Dispose()
            {
                _baseScope.Dispose();
            }

            public object GetService(Type serviceType)
            {
                if (serviceType == typeof(UsersController))
                {
                    return new UsersController(_service);
                }

                return _baseScope.GetService(serviceType);
            }

            public IEnumerable<object> GetServices(Type serviceType)
            {
                return _baseScope.GetServices(serviceType);
            }
        }
    }
}
