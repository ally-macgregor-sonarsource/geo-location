
using Microsoft.AspNetCore.Mvc;

using MX.GeoLocation.LookupApi.Abstractions.Models;
using MX.GeoLocation.LookupWebApi.Controllers;
using MX.GeoLocation.LookupWebApi.Repositories;

using MxIO.ApiClient.Abstractions;

namespace MX.GeoLocation.LookupWebApi.Tests.Controllers
{
    public class GeoLookupControllerTests
    {
        private GeoLookupController geoLookupController;

        [SetUp]
        public void Setup()
        {
            geoLookupController = new GeoLookupController(A.Fake<ITableStorageGeoLocationRepository>(), A.Fake<IMaxMindGeoLocationRepository>());
        }

        [TestCase("abcdefg")]
        [TestCase("a.b.c.d")]
        public async Task TestGetGeoLocationHandlesInvalidHostname(string invalidHostname)
        {
            // Arrange


            // Act
            var result = await geoLookupController.GetGeoLocation(invalidHostname);

            // Assert
            result.Should().NotBeNull();
            result.Should().BeOfType<ObjectResult>();

            var objectResult = result as ObjectResult;

            objectResult.Should().NotBeNull();
            objectResult?.StatusCode.Should().Be(400);

            objectResult?.Value.Should().BeOfType<ApiResponseDto>();

            var apiResponseDto = objectResult?.Value as ApiResponseDto;
            apiResponseDto.Should().NotBeNull();

            apiResponseDto?.Errors.Should().NotBeNullOrEmpty();
            apiResponseDto?.Errors.First().Should().Be("The address provided is invalid. IP or DNS is acceptable.");
        }

        [TestCase("localhost")]
        [TestCase("127.0.0.1")]
        public async Task TestGetGeoLocationHandlesLocalhost(string localhost)
        {
            // Arrange


            // Act
            var result = await geoLookupController.GetGeoLocation(localhost);

            // Assert
            result.Should().NotBeNull();
            result.Should().BeOfType<ObjectResult>();

            var objectResult = result as ObjectResult;

            objectResult.Should().NotBeNull();
            objectResult?.StatusCode.Should().Be(404);

            objectResult?.Value.Should().BeOfType<ApiResponseDto<GeoLocationDto>>();

            var apiResponseDto = objectResult?.Value as ApiResponseDto<GeoLocationDto>;
            apiResponseDto.Should().NotBeNull();

            apiResponseDto?.Errors.Should().NotBeNullOrEmpty();
            apiResponseDto?.Errors.First().Should().Be("Hostname is a loopback or local address, geo location data is unavailable");
        }

        [TearDown]
        public void Cleanup()
        {
            geoLookupController?.Dispose();
        }
    }
}
