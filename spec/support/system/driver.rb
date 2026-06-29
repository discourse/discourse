# frozen_string_literal: true

# Playwright/Chrome driver setup for system specs: the remote-debugging endpoint,
# the Chrome launch args, and driver registration.
CHROME_REMOTE_DEBUGGING_PORT = (ENV["CHROME_REMOTE_DEBUGGING_PORT"] || 50_062).to_s
CHROME_REMOTE_DEBUGGING_ADDRESS = ENV["CHROME_REMOTE_DEBUGGING_ADDRESS"] || "127.0.0.1"

module SystemDrivers
  # On Rails 7, we have seen instances of deadlocks between the lock in [ActiveRecord::ConnectionAdapters::AbstractAdapter](https://github.com/rails/rails/blob/9d1673853f13cd6f756315ac333b20d512db4d58/activerecord/lib/active_record/connection_adapters/abstract_adapter.rb#L86)
  # and the lock in [ActiveRecord::ModelSchema](https://github.com/rails/rails/blob/9d1673853f13cd6f756315ac333b20d512db4d58/activerecord/lib/active_record/model_schema.rb#L550).
  # To work around this problem, we are going to preload all the model schemas before running any system tests so that
  # the lock in ActiveRecord::ModelSchema is not acquired at runtime. This is a temporary workaround while we report
  # the issue to the Rails.
  def self.preload_model_schemas!
    return if @schemas_preloaded

    ActiveRecord::Base.connection.data_sources.each do |table|
      ActiveRecord::Base.connection.schema_cache.add(table)
    end

    @schemas_preloaded = true
  end

  MOBILE_USER_AGENT =
    "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.4 Mobile/15E148 Safari/604.1"

  def self.allow_network_hosts(example)
    Array(example.metadata[:allow_network]).map(&:to_s).map(&:strip).reject(&:empty?).uniq.sort
  end

  # Builds the registered driver name for the example. Mobile vs desktop, plus a
  # suffix for the `allow_network:` host set so each set gets its own browser
  # (host-resolver-rules are a launch arg and can't be changed per-test).
  def self.driver_for(example)
    driver = [:playwright]
    driver << :mobile if example.metadata[:mobile]
    driver << :chrome

    hosts = allow_network_hosts(example)
    driver << "net#{Digest::SHA1.hexdigest(hosts.join(","))[0, 10]}" if hosts.any?

    driver.join("_").to_sym
  end

  # Playwright runs headless browsers on its purpose-built
  # chromium-headless-shell by default; pinning `channel: :chromium` opts into
  # full Chromium's heavier "new headless" mode instead (two extra crashpad
  # processes per browser and ~8% more browser CPU / ~2% more wall per spec
  # file in interleaved A/B runs, same Chromium build revision). Prefer the
  # shell wherever its binary is installed - CI installs it alongside the
  # image's full build, while dev installs (`playwright install --no-shell`)
  # don't have it and keep today's behavior. Headful runs
  # (PLAYWRIGHT_HEADLESS=0) always use the full build; Playwright only
  # substitutes the shell when launching headless. Set
  # PLAYWRIGHT_FULL_CHROMIUM=1 to force the full build back for headless runs.
  def self.headless_shell_available?
    return false if ENV["PLAYWRIGHT_FULL_CHROMIUM"] == "1"

    browsers_path = ENV["PLAYWRIGHT_BROWSERS_PATH"].presence
    return false if browsers_path == "0"
    browsers_path ||= File.join(Dir.home, ".cache", "ms-playwright")

    Dir.glob(
      File.join(browsers_path, "chromium_headless_shell-*", "chrome-linux", "headless_shell"),
    ).any?
  end

  def self.register!(example)
    base_options = {
      browser_type: :chromium,
      **(headless_shell_available? ? {} : { channel: :chromium }),
      headless: (ENV["PLAYWRIGHT_HEADLESS"].presence || ENV["SELENIUM_HEADLESS"].presence) != "0",
      acceptDownloads: true,
      downloadsPath: Downloads::FOLDER,
      slowMo: ENV["PLAYWRIGHT_SLOW_MO_MS"].to_i, # https://playwright.dev/docs/api/class-browsertype#browser-type-launch-option-slow-mo
      playwright_cli_executable_path: "./node_modules/.bin/playwright",
      logger: Logger.new(IO::NULL),
      # NOTE: timezoneId is NOT set here because the driver is cached and reused,
      # so only the first test's timezone would be applied. Instead, we use CDP
      # to override the timezone per-test in the system before(:each) hook.
      colorScheme: example.metadata[:color_scheme],
    }

    if ENV["CAPYBARA_REMOTE_DRIVER_URL"].present?
      base_options[:browser] = :remote
      base_options[:url] = ENV["CAPYBARA_REMOTE_DRIVER_URL"]
    end

    register_chrome(
      :playwright_mobile_chrome,
      **base_options,
      args: apply_base_chrome_args,
      mobile: true,
    )
    register_chrome(:playwright_chrome, **base_options, args: apply_base_chrome_args, mobile: false)

    # Specs that need a specific external host register their own browser, with
    # those hosts excluded from the request block (see apply_base_chrome_args).
    hosts = allow_network_hosts(example)
    if hosts.any?
      register_chrome(
        driver_for(example),
        **base_options,
        args: apply_base_chrome_args(allow_network: hosts),
        mobile: !!example.metadata[:mobile],
      )
    end

    Capybara.default_driver = :playwright_chrome
  end

  def self.register_chrome(name, mobile:, **options)
    mobile_options =
      if mobile
        {
          deviceScaleFactor: 3,
          isMobile: true,
          hasTouch: true,
          userAgent: MOBILE_USER_AGENT,
          defaultBrowserType: "webkit",
          viewport: ENV["PLAYWRIGHT_NO_VIEWPORT"] == "1" ? nil : { width: 390, height: 664 },
        }
      else
        { viewport: ENV["PLAYWRIGHT_NO_VIEWPORT"] == "1" ? nil : { width: 1400, height: 1400 } }
      end

    Capybara.register_driver(name) do |app|
      Capybara::Playwright::Driver.new(app, **options, **mobile_options)
    end
  end

  def self.apply_base_chrome_args(args = [], allow_network: [])
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

    # Block external network access from the browser by resolving any host that
    # isn't explicitly excluded to NXDOMAIN. System specs should never reach out
    # to the real internet; this fails fast instead of hanging or leaking
    # requests. Unlike Playwright request interception it leaves the HTTP cache
    # enabled. Rules are first-match-wins, so the excludes and the MAPs above
    # take precedence.
    minio_domain = ENV["MINIO_RUNNER_MINIO_DOMAIN"].presence || "minio.local"
    resolver_rules.push(
      "EXCLUDE localhost",
      "EXCLUDE *.localhost",
      "EXCLUDE #{Capybara.server_host}",
      "EXCLUDE #{minio_domain}",
      "EXCLUDE *.#{minio_domain}",
    )
    # Hosts a spec opted into via `allow_network:` resolve normally; everything
    # else falls through to NXDOMAIN.
    allow_network.each { |host| resolver_rules.push("EXCLUDE #{host}") }
    resolver_rules.push("MAP * ~NOTFOUND")

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
  private_class_method :apply_base_chrome_args, :register_chrome, :allow_network_hosts
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
