using System.Net;

using MaxMind.GeoIP2.Exceptions;

using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

using MX.GeoLocation.LookupApi.Abstractions.Interfaces;
using MX.GeoLocation.LookupApi.Abstractions.Models;
using MX.GeoLocation.LookupWebApi.Repositories;

using MxIO.ApiClient.Abstractions;
using MxIO.ApiClient.WebExtensions;

using Newtonsoft.Json;

namespace MX.GeoLocation.LookupWebApi.Controllers
{
    [ApiController]
    [Authorize(Roles = "LookupApiUser")]
    public class GeoLookupController : Controller, IGeoLookupApi
    {
        private readonly ITableStorageGeoLocationRepository tableStorageGeoLocationRepository;
        private readonly IMaxMindGeoLocationRepository maxMindGeoLocationRepository;

        private readonly string[] localOverrides = { "localhost", "127.0.0.1" };

        public GeoLookupController(
            ITableStorageGeoLocationRepository tableStorageGeoLocationRepository,
            IMaxMindGeoLocationRepository maxMindGeoLocationRepository)
        {
            this.tableStorageGeoLocationRepository = tableStorageGeoLocationRepository;
            this.maxMindGeoLocationRepository = maxMindGeoLocationRepository ?? throw new ArgumentNullException(nameof(maxMindGeoLocationRepository));
        }

        [HttpGet]
        [Route("lookup/{hostname}")]
        public async Task<IActionResult> GetGeoLocation(string hostname)
        {
            if (!ValidateHostname(hostname))
            {
                return new ApiResponseDto(HttpStatusCode.BadRequest, "The address provided is invalid. IP or DNS is acceptable.").ToHttpResult();
            }

            var response = await ((IGeoLookupApi)this).GetGeoLocation(hostname);

            return response.ToHttpResult();
        }

        async Task<ApiResponseDto<GeoLocationDto>> IGeoLookupApi.GetGeoLocation(string hostname)
        {
            try
            {
                if (ConvertHostname(hostname, out var validatedAddress) && validatedAddress != null)
                {
                    if (localOverrides.Contains(hostname))
                    {
                        return new ApiResponseDto<GeoLocationDto>(HttpStatusCode.NotFound, "Hostname is a loopback or local address, geo location data is unavailable");
                    }

                    var geoLocationDto = await tableStorageGeoLocationRepository.GetGeoLocation(validatedAddress);

                    if (geoLocationDto != null)
                        return new ApiResponseDto<GeoLocationDto>(HttpStatusCode.OK, geoLocationDto);

                    geoLocationDto = await maxMindGeoLocationRepository.GetGeoLocation(validatedAddress);
                    geoLocationDto.Address = hostname; // Set the address to be the original hostname query

                    await tableStorageGeoLocationRepository.StoreGeoLocation(geoLocationDto);

                    return new ApiResponseDto<GeoLocationDto>(HttpStatusCode.OK, geoLocationDto);
                }
                else
                {
                    return new ApiResponseDto<GeoLocationDto>(HttpStatusCode.InternalServerError);
                }
            }
            catch (AddressNotFoundException ex)
            {
                return new ApiResponseDto<GeoLocationDto>(HttpStatusCode.NotFound, ex.Message);
            }
            catch (GeoIP2Exception ex)
            {
                return new ApiResponseDto<GeoLocationDto>(HttpStatusCode.BadRequest, ex.Message);
            }
        }

        [HttpPost]
        [Route("lookup")]
        public async Task<IActionResult> GetGeoLocations()
        {
            var requestBody = await new StreamReader(Request.Body).ReadToEndAsync();

            List<string>? hostnames;
            try
            {
                hostnames = JsonConvert.DeserializeObject<List<string>>(requestBody);
            }
            catch
            {
                return new ApiResponseDto(HttpStatusCode.BadRequest, "Could not deserialize request body").ToHttpResult();
            }

            if (hostnames == null)
                return new ApiResponseDto(HttpStatusCode.BadRequest, "Request body was null").ToHttpResult();

            var response = await ((IGeoLookupApi)this).GetGeoLocations(hostnames);

            return response.ToHttpResult();
        }

        async Task<ApiResponseDto<GeoLocationCollectionDto>> IGeoLookupApi.GetGeoLocations(List<string> hostnames)
        {
            var entries = new List<GeoLocationDto>();
            var errors = new List<string>();

            foreach (var hostname in hostnames)
            {
                try
                {
                    if (ConvertHostname(hostname, out var validatedAddress) && validatedAddress != null)
                    {
                        if (localOverrides.Contains(hostname))
                        {
                            errors.Add("Hostname is a loopback or local address, geo location data is unavailable");
                            continue;
                        }

                        var geoLocationDto = await tableStorageGeoLocationRepository.GetGeoLocation(validatedAddress);

                        if (geoLocationDto != null)
                            entries.Add(geoLocationDto);
                        else
                        {
                            geoLocationDto = await maxMindGeoLocationRepository.GetGeoLocation(validatedAddress);
                            geoLocationDto.Address = hostname; // Set the address to be the original hostname query

                            entries.Add(geoLocationDto);

                            await tableStorageGeoLocationRepository.StoreGeoLocation(geoLocationDto);
                        }
                    }
                    else
                    {
                        errors.Add($"The hostname provided '{hostname} is invalid'");
                    }
                }
                catch (AddressNotFoundException ex)
                {
                    errors.Add(ex.Message);
                }
                catch (GeoIP2Exception ex)
                {
                    errors.Add(ex.Message);
                }
            }

            var result = new GeoLocationCollectionDto
            {
                Entries = entries,
                TotalRecords = entries.Count,
                FilteredRecords = entries.Count
            };

            return new ApiResponseDto<GeoLocationCollectionDto>(HttpStatusCode.OK, result, errors);
        }

        [HttpDelete]
        [Route("lookup/{hostname}")]
        public async Task<IActionResult> DeleteMetadata(string hostname)
        {
            var response = await ((IGeoLookupApi)this).DeleteMetadata(hostname);

            return response.ToHttpResult();
        }

        Task<ApiResponseDto> IGeoLookupApi.DeleteMetadata(string hostname)
        {
            throw new NotImplementedException();
        }

        private bool ValidateHostname(string address)
        {
            if (IPAddress.TryParse(address, out var ipAddress))
            {
                return true;
            }

            try
            {
                var hostEntry = Dns.GetHostEntry(address);

                if (hostEntry.AddressList.FirstOrDefault() != null)
                {
                    return true;
                }
            }
            catch
            {
                return false;
            }

            return false;
        }

        private bool ConvertHostname(string address, out string? validatedAddress)
        {
            if (IPAddress.TryParse(address, out var ipAddress))
            {
                validatedAddress = ipAddress.ToString();
                return true;
            }

            try
            {
                var hostEntry = Dns.GetHostEntry(address);

                if (hostEntry.AddressList.FirstOrDefault() != null)
                {
                    validatedAddress = hostEntry.AddressList.First().ToString();
                    return true;
                }
            }
            catch
            {
                validatedAddress = null;
                return false;
            }

            validatedAddress = null;
            return false;
        }
    }
}
