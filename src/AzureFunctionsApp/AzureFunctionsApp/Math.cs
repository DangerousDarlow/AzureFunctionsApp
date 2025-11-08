using System.Net;
using System.Text.Json;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.WebJobs.Extensions.OpenApi.Core.Attributes;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace AzureFunctionsApp;

public class Math(IOptions<JsonSerializerOptions> jsonSerializerOptions, ILogger<Math> logger)
{
    private readonly JsonSerializerOptions _jsonSerializerOptions = jsonSerializerOptions.Value;
    
    [Function("Double")]
    [OpenApiOperation("Double")]
    [OpenApiRequestBody("application/json", typeof(Body), Required = true)]
    [OpenApiResponseWithBody(HttpStatusCode.OK, "'application/json'", typeof(Body))]
    public async Task<IActionResult> Double([HttpTrigger(AuthorizationLevel.Anonymous, "post")] HttpRequest request)
    {
        var requestBodyString = await new StreamReader(request.Body).ReadToEndAsync();
        var requestBody = JsonSerializer.Deserialize<Body>(requestBodyString, _jsonSerializerOptions);
        logger.LogInformation("Doubling number: {number}", requestBody?.Value);
        return new OkObjectResult(new Body (requestBody?.Value * 2 ?? 0 ));
    }

    public record Body(int Value);
}