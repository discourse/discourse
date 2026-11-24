# frozen_string_literal: true

require "capybara"
require "open3"

require_relative "capybara_patches"
require_relative "bidi_browser"
require_relative "bidi_connection"
require_relative "bidi_driver"
require_relative "bidi_node"
require_relative "cdp_driver"
require_relative "safari_driver"
require_relative "webkit_driver"

# The Chrome inspection endpoint used by the debugger prompt.
CHROME_REMOTE_DEBUGGING_PORT =
  ((ENV["CHROME_REMOTE_DEBUGGING_PORT"] || 50_062).to_i + ENV["TEST_ENV_NUMBER"].to_i).to_s
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

  CLASSIC_WEBDRIVER_LIMITS = {
    mobile: "mobile device emulation",
    color_scheme: "color scheme emulation",
    time: "browser clock overrides",
    timezone: "browser timezone overrides",
  }.freeze
  CHROMIUM_BROWSERS = %i[chromium edge].freeze
  BROWSER_FEATURES = {
    clipboard: ["system clipboard access", %i[chromium edge firefox]],
    image_clipboard: ["native image clipboard access", %i[chromium edge firefox]],
    browser_clock: ["browser clock overrides", %i[chromium edge firefox]],
    virtual_authenticator: ["a virtual WebAuthn authenticator", CHROMIUM_BROWSERS],
    native_drag: ["native HTML drag interception", CHROMIUM_BROWSERS],
    network_interception: ["network request interception", %i[chromium edge firefox]],
    offline_emulation: ["offline emulation", %i[chromium edge firefox]],
    simultaneous_browser_sessions: [
      "simultaneous browser sessions",
      %i[chromium edge firefox webkit],
    ],
    document_preload: ["document preload scripts", %i[chromium edge firefox]],
    request_events: ["browser request events", %i[chromium edge firefox]],
    navigation_status: ["navigation response status", %i[chromium edge firefox]],
    browser_permissions: ["browser permission overrides", CHROMIUM_BROWSERS],
    document_start_diagnostics: ["document start diagnostics", %i[chromium edge firefox]],
    completed_downloads: ["completed downloads", %i[chromium edge firefox safari]],
  }.freeze
  private_constant :CLASSIC_WEBDRIVER_LIMITS, :CHROMIUM_BROWSERS, :BROWSER_FEATURES

  def self.feature_skip_reason(feature)
    description, browsers = BROWSER_FEATURES.fetch(feature)
    browser = browser_type
    if browsers.exclude?(browser)
      return "Requires #{description}, unavailable in the #{browser} driver"
    end
    if feature == :simultaneous_browser_sessions && browser == :webkit &&
         ENV["WEBKIT_WEBDRIVER_URL"].present?
      return "A remote WebKitWebDriver endpoint serves one session at a time"
    end
    if feature == :completed_downloads && browser == :safari &&
         ENV["SAFARI_DOWNLOAD_DIRECTORY"].blank?
      return "Safari download examples require SAFARI_DOWNLOAD_DIRECTORY"
    end
    return unless browser == :firefox && %i[clipboard image_clipboard].include?(feature)

    if !headless? || ENV["BIDI_BROWSER_URL"].present?
      return "Firefox clipboard tests require a locally launched headless browser"
    end
    if feature == :image_clipboard && (version = firefox_major_version) && version < 158
      "Native image clipboard requires Firefox 158 or later in headless mode"
    end
  end

  def self.skip_reason(metadata)
    browser = browser_type
    reason = metadata[:browser_skip]&.[](browser)
    return reason if reason

    Array(metadata[:browser_features]).each do |feature|
      return reason if (reason = feature_skip_reason(feature))
    end
    return if %i[safari webkit].exclude?(browser)

    _, capability = CLASSIC_WEBDRIVER_LIMITS.find { |key, _| metadata[key] }
    "Requires #{capability}, unavailable through #{browser} WebDriver" if capability
  end

  def self.allow_network_hosts(example)
    Array(example.metadata[:allow_network]).map(&:to_s).map(&:strip).reject(&:empty?).uniq.sort
  end

  # Builds the registered driver name for the example. Mobile vs desktop, plus a
  # suffix for the `allow_network:` host set so each set gets its own browser
  # (host-resolver-rules are a launch arg and can't be changed per-test).
  def self.driver_for(example)
    driver = [browser_type]
    driver << :mobile if example.metadata[:mobile]
    driver << example.metadata[:color_scheme] if example.metadata[:color_scheme]

    hosts = allow_network_hosts(example)
    driver << "net#{Digest::SHA1.hexdigest(hosts.join(","))[0, 10]}" if hosts.any?

    driver.join("_").to_sym
  end

  def self.register!(example)
    name = driver_for(example)
    browser = browser_type
    hosts = allow_network_hosts(example)
    options = {
      mobile: !!example.metadata[:mobile],
      color_scheme: example.metadata[:color_scheme],
      headless: headless?,
    }
    Capybara.register_driver(name) do |app|
      case browser
      when :chromium, :edge
        DiscourseSystemDriver.new(
          app,
          executable: browser == :edge ? edge_executable : chromium_executable,
          args: apply_base_chrome_args(allow_network: hosts),
          fresh_context_on_reset: browser == :edge,
          **options,
        )
      when :firefox
        DiscourseBiDiDriver.new(app, allowed_hosts: hosts, **options)
      when :safari
        DiscourseSafariDriver.new(app, allowed_hosts: hosts, **options)
      when :webkit
        DiscourseWebKitDriver.new(app, allowed_hosts: hosts, **options)
      end
    end
    Capybara.default_driver = name
  end

  def self.browser_type
    browser = ENV.fetch("DISCOURSE_SYSTEM_BROWSER", "chromium").to_sym
    if %i[chromium edge firefox safari webkit].exclude?(browser)
      raise ArgumentError,
            "DISCOURSE_SYSTEM_BROWSER must be chromium, edge, firefox, safari, or webkit"
    end
    browser
  end

  def self.server_host
    # Firefox uses the app connection's address family to discover its default ICE route.
    default_host = browser_type == :firefox ? "127.0.0.1" : "localhost"
    ENV["CAPYBARA_SERVER_HOST"].presence || default_host
  end

  def self.headless?
    (ENV["SYSTEM_TEST_HEADLESS"].presence || ENV["SELENIUM_HEADLESS"].presence) != "0"
  end
  private_class_method :headless?

  def self.firefox_major_version
    @firefox_versions ||= {}
    executable = DiscourseBiDiBrowser.executable
    @firefox_versions.fetch(executable) do
      output, _stderr, status = Open3.capture3(executable, "--version")
      @firefox_versions[executable] = status.success? ? output[/\bFirefox (\d+)/, 1]&.to_i : nil
    rescue Errno::ENOENT
      @firefox_versions[executable] = nil
    end
  end
  private_class_method :firefox_major_version

  def self.chromium_executable
    @chromium_executable ||=
      begin
        executable, status = Open3.capture2e(Rails.root.join("script/test-chromium").to_s)
        raise executable.strip unless status.success?
        executable.strip
      end
  end

  def self.edge_executable
    default_path =
      if RUBY_PLATFORM.include?("darwin")
        "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge"
      else
        "/usr/bin/microsoft-edge"
      end
    executable = ENV["EDGE_PATH"].presence || default_path
    unless File.executable?(executable)
      raise ArgumentError, "Microsoft Edge is unavailable. Set EDGE_PATH to its executable."
    end
    executable
  end

  def self.device_scale_factor
    [ENV["CHROME_DEVICE_SCALE_FACTOR"].to_i, 1].max
  end

  def self.apply_base_chrome_args(allow_network: [])
    # A custom --disable-features replaces the generated list. Keep the browser
    # safeguards relevant to Chromium in our Linux test image alongside our flags.
    disabled_features = [
      # Avoid Google AI Mode eligibility requests during browser startup.
      "AimEnabled",
      # Avoid headed about:blank navigation hangs.
      "AvoidUnnecessaryBeforeUnloadCheckSync",
      # Keep the profile alive when examples close and replace the last browser window.
      "DestroyProfileOnBrowserClose",
      # Keep HTTP test URLs on HTTP instead of attempting automatic HTTPS upgrades.
      "HttpsUpgrades",
      # Avoid casting device discovery and its local network traffic in the test container.
      "MediaRouter",
      # Avoid startup requests to Google network time servers.
      "NetworkTimeServiceQuerying",
      # Avoid downloading remote navigation optimization hints during startup.
      "OptimizationHints",
      # Avoid lost iframe clicks and file chooser events while painting is deferred.
      "PaintHolding",
      # Preserve browser context storage state when an origin is loaded in an iframe.
      "ThirdPartyStoragePartitioning",
      # Prevent browser translation prompts from interrupting tests in other locales.
      "Translate",
      # Avoid creating the internal address bar popup page when tests replace pages.
      "WebUIOmniboxPopup",
      # Avoid creating the companion AI Mode popup page when tests replace pages.
      "WebUIOmniboxAimPopup",
    ]

    base_args = %W[
      --disable-search-engine-choice-screen
      --disable-features=#{disabled_features.join(",")}
      --no-sandbox
      --disable-dev-shm-usage
      --mute-audio
      --remote-allow-origins=*
      --disable-smooth-scrolling
      --js-flags=--no-enable-lazy-source-positions
    ]

    if ENV["CHROME_DEVTOOLS"].presence == "1" || ENV["SELENIUM_DEVTOOLS"].presence == "1"
      base_args << "--auto-open-devtools-for-tabs"
    end

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
    # requests and preserves the HTTP cache. Rules are first-match-wins,
    # so the excludes and the MAPs above
    # take precedence.
    resolver_rules.push(
      "EXCLUDE localhost",
      "EXCLUDE *.localhost",
      "EXCLUDE #{Capybara.server_host}",
    )
    resolver_rules << "EXCLUDE #{URI(Capybara.app_host).host}" if Capybara.app_host
    if ENV["S3_SYSTEM_TEST_ENDPOINT"].present?
      s3_system_test_domain = URI(ENV.fetch("S3_SYSTEM_TEST_ENDPOINT")).host
      resolver_rules.push("EXCLUDE #{s3_system_test_domain}", "EXCLUDE *.#{s3_system_test_domain}")
    end
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
      base_args << "--force-device-scale-factor=#{device_scale_factor}"
    end

    base_args
  end
  private_class_method :apply_base_chrome_args,
                       :browser_type,
                       :chromium_executable,
                       :edge_executable,
                       :allow_network_hosts
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
      capybara_config.app_host = ENV["CAPYBARA_APP_HOST"].presence
      capybara_config.server_host = SystemDrivers.server_host

      capybara_config.server_port =
        (ENV["CAPYBARA_SERVER_PORT"].presence || "31_337").to_i + ENV["TEST_ENV_NUMBER"].to_i
    end
  end
end
