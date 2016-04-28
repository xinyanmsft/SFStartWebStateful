using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Application1.WebService
{
    public interface IWebService
    {
        Task<UserInfo> GetAsync(int id);

        Task<bool> UpdateAsync(int id, UserInfo user);

        Task<bool> CreateAsync(int id, UserInfo user);

        Task<bool> DeleteAsync(int id);
    }

    public class UserInfo
    {
        public int Id { get; set; }
        public string FirstName { get; set; }
        public string LastName { get; set; }
    }
}
