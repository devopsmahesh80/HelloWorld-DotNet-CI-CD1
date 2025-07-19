using Microsoft.AspNetCore.Mvc;

namespace HelloWorld.Api.Controllers;

[ApiController]
[Route("[controller]")]
public class GreetingController : ControllerBase
{
    [HttpGet]
    public IActionResult Get()
    {
        return Ok(new { message = "Hello, World from an automated pipeline!" });
    }
}
