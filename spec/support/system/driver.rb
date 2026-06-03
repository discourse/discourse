# frozen_string_literal: true

# Playwright/Chrome driver setup for system specs: the remote-debugging endpoint,
# the Chrome launch args, and driver registration.
CHROME_REMOTE_DEBUGGING_PORT = (ENV["CHROME_REMOTE_DEBUGGING_PORT"] || 50_062).to_s
CHROME_REMOTE_DEBUGGING_ADDRESS = ENV["CHROME_REMOTE_DEBUGGING_ADDRESS"] || "127.0.0.1"

module SystemDrivers
  def self.register!(color_scheme:)
    driver_options = {
      browser_type: :chromium,
      channel: :chromium,
      headless: (ENV["PLAYWRIGHT_HEADLESS"].presence || ENV["SELENIUM_HEADLESS"].presence) != "0",
      args: apply_base_chrome_args,
      acceptDownloads: true,
      downloadsPath: Downloads::FOLDER,
      slowMo: ENV["PLAYWRIGHT_SLOW_MO_MS"].to_i, # https://playwright.dev/docs/api/class-browsertype#browser-type-launch-option-slow-mo
      playwright_cli_executable_path: "./node_modules/.bin/playwright",
      logger: Logger.new(IO::NULL),
      # NOTE: timezoneId is NOT set here because the driver is cached and reused,
      # so only the first test's timezone would be applied. Instead, we use CDP
      # to override the timezone per-test in the system before(:each) hook.
      colorScheme: color_scheme,
    }

    if ENV["CAPYBARA_REMOTE_DRIVER_URL"].present?
      driver_options[:browser] = :remote
      driver_options[:url] = ENV["CAPYBARA_REMOTE_DRIVER_URL"]
    end

    Capybara.register_driver(:playwright_mobile_chrome) do |app|
      Capybara::Playwright::Driver.new(
        app,
        **driver_options,
        deviceScaleFactor: 3,
        isMobile: true,
        hasTouch: true,
        userAgent:
          "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.4 Mobile/15E148 Safari/604.1",
        defaultBrowserType: "webkit",
        viewport: ENV["PLAYWRIGHT_NO_VIEWPORT"] == "1" ? nil : { width: 390, height: 664 },
      )
    end

    Capybara.register_driver(:playwright_chrome) do |app|
      Capybara::Playwright::Driver.new(
        app,
        **driver_options,
        viewport: ENV["PLAYWRIGHT_NO_VIEWPORT"] == "1" ? nil : { width: 1400, height: 1400 },
      )
    end

    Capybara.default_driver = :playwright_chrome
  end

  def self.apply_base_chrome_args(args = [])
    base_args = %w[
      --disable-search-engine-choice-screen
      --no-sandbox
      --disable-dev-shm-usage
      --mute-audio
      --remote-allow-origins=*
      --disable-smooth-scrolling
    ]

    if !ENV["CI"]
      base_args << "--remote-debugging-port=" + CHROME_REMOTE_DEBUGGING_PORT
      base_args << "--remote-debugging-address=" + CHROME_REMOTE_DEBUGGING_ADDRESS
    end

    resolver_rules = ["MAP test.localhost:80 127.0.0.1:#{Capybara.server_port}"]
    if ENV["CI"]
      # Bypass the OS resolver for localhost lookups inside the browser.
      resolver_rules.push("MAP localhost [::1]", "MAP *.localhost [::1]")
    end
    base_args << "--host-resolver-rules=#{resolver_rules.join(",")}"

    # A file that contains just a list of paths like so:
    #
    # /home/me/.config/google-chrome/Default/Extensions/bmdblncegkenkacieihfhpjfppoconhi/4.9.1_0
    #
    # These paths can be found for each individual extension via the
    # chrome://extensions/ page.
    if ENV["CHROME_LOAD_EXTENSIONS_MANIFEST"].present?
      File
        .readlines(ENV["CHROME_LOAD_EXTENSIONS_MANIFEST"])
        .each { |path| base_args << "--load-extension=#{path}" }
    end

    if ENV["CHROME_DISABLE_FORCE_DEVICE_SCALE_FACTOR"].blank?
      base_args << "--force-device-scale-factor=1"
    end

    base_args + args
  end
  private_class_method :apply_base_chrome_args
end

RSpec.configure do |config|
  config.before(:suite) do
    if ENV["CAPYBARA_DEFAULT_MAX_WAIT_TIME"].present?
      Capybara.default_max_wait_time = ENV["CAPYBARA_DEFAULT_MAX_WAIT_TIME"].to_i
    else
      Capybara.default_max_wait_time = 4
    end

    Capybara.threadsafe = true
    Capybara.disable_animation = true

    # Click offsets is calculated from top left of element
    Capybara.w3c_click_offset = false

    Capybara.configure do |capybara_config|
      capybara_config.server_host = ENV["CAPYBARA_SERVER_HOST"].presence || "localhost"

      capybara_config.server_port =
        (ENV["CAPYBARA_SERVER_PORT"].presence || "31_337").to_i + ENV["TEST_ENV_NUMBER"].to_i
    end
  end
end
