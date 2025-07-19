using Xunit;
using HelloWorld.Api.Controllers;
using Microsoft.AspNetCore.Mvc;

public class GreetingControllerTests
{
    [Fact]
    public void Get_ReturnsOkObjectResult_WithCorrectMessage()
    {
        // Arrange
        var controller = new GreetingController();

        // Act
        var result = controller.Get();

        // Assert
        var okResult = Assert.IsType<OkObjectResult>(result);
        var value = okResult.Value;
        Assert.NotNull(value);

        var messageProperty = value.GetType().GetProperty("message");
        Assert.NotNull(messageProperty);

        var message = messageProperty.GetValue(value, null) as string;
        Assert.Equal("Hello, World from an automated pipeline!", message);
    }
}
// This file contains unit tests for the GreetingController