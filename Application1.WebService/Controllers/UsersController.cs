using Application1.WebService;
using System.Net;
using System.Threading.Tasks;
using System.Web.Http;

namespace Application1.WebService.Controllers
{
    public class UsersController : ApiController
    {
        private IWebService _service;
         
        public UsersController(IWebService service)
        {
            _service = service;
        }

        public async Task<UserInfo> Get(int id)
        {
            UserInfo value = await _service.GetAsync(id);
            if (value == null)
            {
                throw new HttpResponseException(HttpStatusCode.NotFound);
            }

            return value;
        }

        public async void Post(int id, [FromBody]UserInfo value)
        {
            if (value == null)
            {
                throw new HttpResponseException(HttpStatusCode.BadRequest);
            }

            if (!await _service.CreateAsync(id, value))
            {
                throw new HttpResponseException(HttpStatusCode.Conflict);
            }
        }

        public async void Put(int id, [FromBody]UserInfo value)
        {
            if (value == null)
            {
                throw new HttpResponseException(HttpStatusCode.BadRequest);
            }

            if (!await _service.UpdateAsync(id, value))
            {
                throw new HttpResponseException(HttpStatusCode.NotFound);
            }
        }

        public async void Delete(int id)
        {
            if (!await _service.DeleteAsync(id))
            {
                throw new HttpResponseException(HttpStatusCode.NotFound);
            }
        }
    }
}
