# frozen_string_literal: true

# Browser driver registration and Chrome launch arguments for system specs.

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
    driver = [:discourse]
    driver << :mobile if example.metadata[:mobile]
    driver << (ENV["DISCOURSE_SYSTEM_BROWSER"] == "firefox" ? :firefox : :chrome)

    hosts = allow_network_hosts(example)
    driver << "net#{Digest::SHA1.hexdigest(hosts.join(","))[0, 10]}" if hosts.any?

    driver.join("_").to_sym
  end

  def self.register!(example)
    name = driver_for(example)
    mobile = !!example.metadata[:mobile]
    Capybara.register_driver(name) do |app|
      if ENV["DISCOURSE_SYSTEM_BROWSER"] == "firefox"
        FirefoxBidiDriver.new(app, mobile: mobile, allow_network: allow_network_hosts(example))
      else
        args = apply_base_chrome_args(allow_network: allow_network_hosts(example))
        DiscourseSystemDriver.new(app, args: args, mobile: mobile)
      end
    end
    Capybara.default_driver = name
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

    if ENV["PLAYWRIGHT_DEVTOOLS"].presence == "1" || ENV["SELENIUM_DEVTOOLS"].presence == "1"
      base_args << "--auto-open-devtools-for-tabs"
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
    resolver_rules.push(
      "EXCLUDE localhost",
      "EXCLUDE *.localhost",
      "EXCLUDE #{Capybara.server_host}",
    )
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
      base_args << "--force-device-scale-factor=1"
    end

    base_args + args
  end
  private_class_method :apply_base_chrome_args, :allow_network_hosts
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
