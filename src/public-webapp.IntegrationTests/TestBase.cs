using OpenQA.Selenium;
using OpenQA.Selenium.Chrome;
using OpenQA.Selenium.Edge;
using OpenQA.Selenium.Firefox;

namespace MX.GeoLocation.PublicWebApp.IntegrationTests
{
    internal class TestBase
    {
        private IWebDriver driver;

        public PageFactory PageFactory { get; }

        public TestBase(string browser)
        {
            switch (browser)
            {
                case "Chrome":
                    var options = new ChromeOptions();
                    options.AddArgument("--headless=new");
                    driver = new ChromeDriver(options);
                    break;
                case "Firefox":
                    driver = new FirefoxDriver();
                    break;
                case "Edge":
                    driver = new EdgeDriver();
                    break;
                default:
                    throw new ArgumentException($"'{browser}': Unknown browser");
            }

            // Wait until the page is fully loaded on every page navigation or page reload.
            driver.Manage().Timeouts().ImplicitWait = TimeSpan.FromSeconds(20);

            PageFactory = new PageFactory(driver);
        }

        [SetUp]
        public void Setup()
        {
            PageFactory.HomePage.GoToPage();
        }

        [OneTimeTearDown]
        public void Cleanup()
        {
            if (driver != null)
            {
                driver.Quit();
            }
            driver?.Dispose();
        }
    }
}
