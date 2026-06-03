# frozen_string_literal: true

if ENV["COVERAGE"]
  require "simplecov"
  if ENV["TEST_ENV_NUMBER"]
    SimpleCov.command_name "#{SimpleCov.command_name} #{ENV["TEST_ENV_NUMBER"]}"
  end
  SimpleCov.start "rails" do
    add_group "Libraries", %r{^/lib/(?!tasks).*$}
    add_group "Scripts", "script"
    add_group "Serializers", "app/serializers"
    add_group "Services", "app/services"
    add_group "Tasks", "lib/tasks"
  end
end

require "rubygems"
require "rbtrace" if RUBY_ENGINE == "ruby"
require "pry"
require "pry-rails"
require "fabrication"
require "mocha/api"
require "certified"
require "webmock/rspec"

CHROME_REMOTE_DEBUGGING_PORT = (ENV["CHROME_REMOTE_DEBUGGING_PORT"] || 50_062).to_s
CHROME_REMOTE_DEBUGGING_ADDRESS = ENV["CHROME_REMOTE_DEBUGGING_ADDRESS"] || "127.0.0.1"

require_relative "support/server_error_tracking"

class PlaywrightLogger
  attr_reader :logs

  def initialize(page)
    @logs = []

    page.on(
      "console",
      ->(msg) do
        @logs << {
          level: msg.type,
          message: msg.text,
          timestamp: Time.now.to_i * 1000,
          source: "console-api",
        }
      end,
    )

    page.on(
      "pageerror",
      ->(error) do
        @logs << {
          level: "error",
          message: error.message,
          timestamp: Time.now.to_i * 1000,
          source: "pageerror-api",
        }
      end,
    )
  end
end

ENV["RAILS_ENV"] ||= "test"
ENV["ENABLE_LOGSTASH_LOGGER"] ||= "1"
require File.expand_path("../../config/environment", __FILE__)
Discourse.singleton_class.prepend(RspecWarnExceptionCapture)
require "rspec/rails"
require "shoulda-matchers"
require "sidekiq/testing"
require "capybara/rails"

# The shoulda-matchers gem no longer detects the test framework
# you're using or mixes itself into that framework automatically.
Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :active_record
    with.library :active_model
  end
end

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[Rails.root.join("spec/support/**/*.rb")].each { |f| require f }
Dir[Rails.root.join("spec/requests/examples/*.rb")].each { |f| require f }

Dir[Rails.root.join("spec/system/helpers/**/*.rb")].each { |f| require f }
Dir[Rails.root.join("spec/system/page_objects/**/base.rb")].each { |f| require f }
Dir[Rails.root.join("spec/system/page_objects/**/*_base.rb")].each { |f| require f }
Dir[Rails.root.join("spec/system/page_objects/**/*.rb")].each { |f| require f }

Dir[Rails.root.join("spec/fabricators/*.rb")].each { |f| require f }
require_relative "helpers/redis_snapshot_helper"

# Require plugin helpers at plugin/[plugin]/spec/plugin_helper.rb (includes symlinked plugins).
if ENV["LOAD_PLUGINS"] == "1"
  Dir[Rails.root.join("plugins/*/spec/plugin_helper.rb")].each { |f| require f }

  Dir[Rails.root.join("plugins/*/spec/fabricators/**/*.rb")].each { |f| require f }

  Dir[Rails.root.join("plugins/*/spec/system/page_objects/**/*.rb")].each { |f| require f }
end

SiteSetting.automatically_download_gravatars = false

BROWSER_READ_TIMEOUT = 30

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Default is :fork, but this causes problems if any miniracer context have started
  config.bisect_runner = :shell

  config.fail_fast = ENV["RSPEC_FAIL_FAST"] == "1"
  config.silence_filter_announcements = ENV["RSPEC_SILENCE_FILTER_ANNOUNCEMENTS"] == "1"
  config.extend RedisSnapshotHelper
  config.include Helpers
  config.include MessageBus
  config.include RSpecHtmlMatchers
  config.include IntegrationHelpers, type: :request
  config.include SystemHelpers, type: :system
  config.include ThemeScreenshotMarker, type: :system
  config.include DiscourseWebauthnIntegrationHelpers
  config.include SiteSettingsHelpers
  config.include SidekiqHelpers
  config.include UploadsHelpers
  config.include BackupsHelpers
  config.include OneboxHelpers
  config.include FastImageHelpers
  config.include ServiceMatchers
  config.include I18nHelpers

  config.order = "random"
  config.infer_spec_type_from_file_location!

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = true

  # Sometimes you may have a large string or object that you are comparing
  # with some expectation, and you want to see the full diff between actual
  # and expected without rspec truncating 90% of the diff. Setting the
  # max_formatted_output_length to nil disables this truncation completely.
  #
  # c.f. https://www.rubydoc.info/gems/rspec-expectations/RSpec/Expectations/Configuration#max_formatted_output_length=-instance_method
  if ENV["RSPEC_DISABLE_DIFF_TRUNCATION"]
    config.expect_with :rspec do |expectation|
      expectation.max_formatted_output_length = nil
    end
  end

  # If true, the base class of anonymous controllers will be inferred
  # automatically. This will be the default behavior in future versions of
  # rspec-rails.
  config.infer_base_class_for_anonymous_controllers = true

  # Shows more than one line of backtrace in case of an error or spec failure.
  config.full_cause_backtrace = false

  # Sometimes the backtrace is quite big for failing specs, this will
  # remove rspec/gem paths from the backtrace so it's easier to see the
  # actual application code that caused the failure.
  #
  # This behaviour is enabled by default, to include gems in
  # the backtrace set DISCOURSE_INCLUDE_GEMS_IN_RSPEC_BACKTRACE=1
  if ENV["DISCOURSE_INCLUDE_GEMS_IN_RSPEC_BACKTRACE"] != "1"
    config.backtrace_exclusion_patterns = [
      %r{/lib\d*/ruby/},
      %r{bin/},
      /gems/,
      %r{spec/spec_helper\.rb},
      %r{spec/rails_helper\.rb},
      %r{lib/rspec/(core|expectations|matchers|mocks)},
    ]
  end

  config.before(:suite) do
    # Rebase the seeded DB settings as defaults, then swap in the in-memory provider.
    TestLocalProcessProvider.install!

    DiscourseConnectHelpers.provider_port = 9100 + ENV["TEST_ENV_NUMBER"].to_i

    WebMock.disable_net_connect!(
      allow_localhost: true,
      allow: [
        *MinioRunner.config.minio_urls,
        URI(MinioRunner::MinioBinary.platform_binary_url).host,
        ENV["CAPYBARA_REMOTE_DRIVER_URL"],
      ].compact,
    )

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

    module IgnoreServerCapturedErrors
      def raise_server_error!
        super
      rescue EOFError, Errno::ECONNRESET, Errno::EPIPE, Errno::ENOTCONN
        # Ignore these exceptions - caused by client. Handled by the app server in dev/prod
      end
    end

    Capybara::Session.class_eval { prepend IgnoreServerCapturedErrors }

    module CapybaraTimeoutExtension
      class CapybaraTimedOut < StandardError
        attr_reader :cause

        def initialize(wait_time, cause)
          @cause = cause
          super "This spec passed, but capybara waited for the full wait duration (#{wait_time}s) at least once. " +
                  "This will slow down the test suite. " +
                  "Beware of negating the result of RSpec matchers."
        end
      end

      def synchronize(seconds = nil, errors: nil)
        return super if session.synchronized # Nested synchronize. We only want our logic on the outermost call.

        mb_behind = nil

        begin
          super
        rescue StandardError => e
          raise unless catch_error?(e, errors) && seconds != 0

          # On timeout, give a pending MessageBus publish one chance to land,
          # then retry the matcher once. Cap the retry's wait so the original
          # wait + flush + retry can't blow PER_SPEC_TIMEOUT_SECONDS.
          if mb_behind.nil? && MessageBusTestSync.pending?
            mb_behind = MessageBusTestSync.flush!(session, timeout: 2)
            seconds = 5
            retry
          end

          if mb_behind&.any?
            warn "[MessageBusTestSync] client never caught up on: #{mb_behind.inspect}"
          end

          # This error will only have been raised if the timer expired
          effective_seconds =
            [nil, true].include?(seconds) ? session_options.default_max_wait_time : seconds
          timeout_error = CapybaraTimedOut.new(effective_seconds, e)
          if RSpec.current_example
            # Store timeout for later, we'll only raise it if the test otherwise passes
            RSpec.current_example.metadata[:_capybara_timeout_exception] ||= timeout_error

            if RSpec.current_example.metadata[:dump_threads_on_failure]
              RSpec.current_example.metadata[:_capybara_server_threads_backtraces] = Thread
                .list
                .reduce([]) { |array, thread| array << thread.backtrace }
                .uniq
            end

            raise # re-raise original error
          else
            # Outside an example... maybe a `before(:all)` hook?
            raise timeout_error
          end
        end
      end
    end

    Capybara::Node::Base.prepend(CapybaraTimeoutExtension)

    config.before(:each) do |example|
      if example.metadata[:type] != :system
        EmberCli.stubs(:read_manifest!).returns(nil)
        EmberCli.stubs(:script_chunks).returns({})
      end
    end

    config.before(:each, type: :system) { MessageBusTestSync.start }
    config.after(:each, type: :system) { MessageBusTestSync.stop }

    config.before(:each, type: :system) do |example|
      # Only set ENV["EMBER_RAISE_ON_DEPRECATION"] if not already set
      if ENV["EMBER_RAISE_ON_DEPRECATION"].nil?
        example_file_path = example.metadata[:rerun_file_path]

        if example_file_path
          match =
            example_file_path.to_s.match(
              %r{^#{Regexp.escape(Rails.root.to_s)}/(plugins|themes|spec)/([^/]+)/},
            )

          if match
            should_set_raise_on_deprecation =
              begin
                type_dir, extension_name = match.captures

                case type_dir
                when "spec"
                  true
                when "plugins"
                  Discourse.preinstalled_plugins.any? { |p| p.directory_name == extension_name }
                when "themes"
                  # Preinstalled themes don't have a .git directory
                  !Rails.root.join(type_dir, extension_name, ".git").exist?
                end
              end

            ENV["EMBER_RAISE_ON_DEPRECATION"] = "1" if should_set_raise_on_deprecation
          end
        end
      end

      if example.metadata[:time]
        freeze_time(example.metadata[:time])
        BrowserTime.freeze(page, example.metadata[:time])
      end
    end

    module CapybaraPlaywrightBasePatch
      private

      def execute_async_client_settled_script(session)
        result = session.evaluate_async_script(<<~JS)
            const done = arguments[0];

            if (window.clientSettled) {
              window.clientSettled(#{Capybara.default_max_wait_time * 1000})
                .then(done)
                .catch((error) => { done(error.message) });
            } else {
              done();
            }
          JS

        raise result if result.is_a? String
      end

      def wait_for_client_settled(method_name)
        session = @driver.send(:session)

        if ENV["CAPYBARA_PLAYWRIGHT_DEBUG_CLIENT_SETTLED"].present?
          now = Time.now.to_f
          puts "[#{now}] #{method_name}: START"
          execute_async_client_settled_script(session)
          puts "[#{Time.now.to_f}] #{method_name}: END IN #{Time.now.to_f - now}"
        else
          execute_async_client_settled_script(session)
        end
      end
    end

    module CapybaraPlaywrightNodePatch
      include CapybaraPlaywrightBasePatch

      NODE_METHODS_TO_PATCH = %i[
        click
        right_click
        double_click
        send_keys
        hover
        drag_to
        scroll_by
        scroll_to
        trigger
        set
        select_option
        unselect_option
      ]

      NODE_METHODS_TO_PATCH.each do |method_name|
        define_method(method_name) do |*args, **options|
          result = super(*args, **options)
          wait_for_client_settled(method_name)
          result
        end
      end
    end

    module CapybaraPlaywrightBrowserPatch
      include CapybaraPlaywrightBasePatch

      METHODS_TO_PATCH = %i[visit go_back go_forward refresh resize_window_to]

      METHODS_TO_PATCH.each do |method_name|
        define_method(method_name) do |*args, **options|
          result = super(*args, **options)
          wait_for_ember_boot
          wait_for_client_settled(method_name)
          result
        end
      end

      private

      # `<discourse-assets>` is only present on Ember pages; `ember-application`
      # is added to the root element (`#main`) once Ember mounts.
      def wait_for_ember_boot
        session = @driver.send(:session)
        return if session.has_no_css?("discourse-assets", wait: 0, visible: :all)
        session.assert_selector("#main.ember-application", visible: :all)
      end
    end

    Capybara::Playwright::Node.prepend(CapybaraPlaywrightNodePatch)
    Capybara::Playwright::Browser.prepend(CapybaraPlaywrightBrowserPatch)

    module PlaywrightErrorPatch
      def message
        msg = super
        if msg.include?("Please run the following command to download new browsers:")
          replacement = "pnpm playwright-install"
          msg.sub("playwright install".ljust(replacement.size), replacement)
        else
          msg
        end
      end
    end
    Playwright::Error.prepend(PlaywrightErrorPatch)

    config.after(:each, type: :system) do |example|
      # If test passed, but we had a capybara finder timeout, raise it now
      if example.exception.nil? &&
           (capybara_timeout_error = example.metadata[:_capybara_timeout_exception])
        raise capybara_timeout_error
      end
    end

    if ENV["CI"].present?
      [
        [PostAction, :post_action_type_id],
        [Reviewable, :target_id],
        [ReviewableHistory, :reviewable_id],
        [ReviewableScore, :reviewable_id],
        [ReviewableScore, :reviewable_score_type],
        [SidebarSectionLink, :linkable_id],
        [SidebarSectionLink, :sidebar_section_id],
        [User, :last_seen_reviewable_id],
        [User, :required_fields_version],
      ].each do |model, column|
        DB.exec("ALTER TABLE #{model.table_name} ALTER #{column} TYPE bigint")
        model.reset_column_information
      end

      # Sets sequence's value to be greater than the max value that an INT column can hold. This is done to prevent
      # type mismatches for foreign keys that references a column of type BIGINT. We set the value to 10_000_000_000
      # instead of 2**31-1 so that the values are easier to read.
      DB
        .query("SELECT sequence_name FROM information_schema.sequences WHERE data_type = 'bigint'")
        .each do |row|
          DB.exec "SELECT setval('#{row.sequence_name}', GREATEST((SELECT last_value FROM #{row.sequence_name}), 10000000000))"
        end
    end

    # Prevents 500 errors for site setting URLs pointing to test.localhost in system specs.
    SiteIconManager.clear_cache!
  end

  config.after(:suite) { Downloads.clear }

  config.before :each do
    # This allows DB.transaction_open? to work in tests. See lib/mini_sql_multisite_connection.rb
    DB.test_transaction = ActiveRecord::Base.connection.current_transaction
    TestSetup.test_setup
  end

  # Match the request hostname to the value in `database.yml`
  config.before(:each, type: %i[request multisite system]) { host! "test.localhost" }

  system_tests_initialized = false

  config.before(:each, type: :system) do |example|
    if !system_tests_initialized
      # On Rails 7, we have seen instances of deadlocks between the lock in [ActiveRecord::ConnectionAdapters::AbstractAdapter](https://github.com/rails/rails/blob/9d1673853f13cd6f756315ac333b20d512db4d58/activerecord/lib/active_record/connection_adapters/abstract_adapter.rb#L86)
      # and the lock in [ActiveRecord::ModelSchema](https://github.com/rails/rails/blob/9d1673853f13cd6f756315ac333b20d512db4d58/activerecord/lib/active_record/model_schema.rb#L550).
      # To work around this problem, we are going to preload all the model schemas before running any system tests so that
      # the lock in ActiveRecord::ModelSchema is not acquired at runtime. This is a temporary workaround while we report
      # the issue to the Rails.
      ActiveRecord::Base.connection.data_sources.map do |table|
        ActiveRecord::Base.connection.schema_cache.add(table)
      end

      system_tests_initialized = true
    end

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
      # to override the timezone per-test in the before(:each) hook below.
      colorScheme: example.metadata[:color_scheme],
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

    driver = [:playwright]
    driver << :mobile if example.metadata[:mobile]
    driver << :chrome

    driven_by driver.join("_").to_sym

    setup_system_test

    BlockRequestsMiddleware.current_example_location = example.location

    # Suppress the "Before you post, please select a category or tag" education
    # popup — it intercepts pointer events and makes system specs flaky when
    # they click things in the composer.
    SiteSetting.educate_until_posts = 0

    if example.metadata[:video]
      Capybara.current_session.driver.on_save_screenrecord do |video|
        saved_path =
          File.join(
            Capybara.save_path,
            "#{example.metadata[:full_description].parameterize}-screenrecord.webm",
          )

        FileUtils.mv(video, saved_path)

        if !ENV["CI"]
          puts "\n🎥 Recorded video for: #{example.metadata[:full_description]}\n"
          puts "#{saved_path}\n"
        end
      end
    end

    if example.metadata[:trace]
      page.driver.start_tracing(screenshots: true, snapshots: true, sources: true)
    end

    page.driver.with_playwright_page do |pw_page|
      $playwright_logger = PlaywrightLogger.new(pw_page)

      if (tz = example.metadata[:timezone])
        BrowserTime.override_timezone(pw_page, tz)
      end
    end
  end

  config.after :each do |example|
    if example.exception && RspecErrorTracker.exceptions.present?
      lines = (RSpec.current_example.metadata[:extra_failure_lines] ||= +"")
      RspecErrorTracker.append_failure_dump(lines)
    end

    unfreeze_time
    ActionMailer::Base.deliveries.clear
    Discourse.redis.flushdb
    Scheduler::Defer.do_all_work
    clear_mocked_upcoming_change_metadata
    clear_mocked_upcoming_change_default_overrides
  end

  config.after(:each, type: :system) do |example|
    if example.metadata[:trace]
      path =
        File.join(
          Capybara.save_path,
          "#{example.metadata[:full_description].parameterize}-trace.zip",
        )
      page.driver.stop_tracing(path:)

      if !ENV["CI"]
        puts "\n🧭 Recorded trace for: #{example.metadata[:full_description]}\n"
        puts "Open with `pnpm playwright show-trace #{path}`\n"
      end
    end

    lines = RSpec.current_example.metadata[:extra_failure_lines]

    if example.exception &&
         (
           backtraces = RSpec.current_example.metadata[:_capybara_server_threads_backtraces]
         ).present?
      lines << "~~~~~~~ SERVER THREADS BACKTRACES ~~~~~~~"

      backtraces.each_with_index do |backtrace, index|
        lines << "\n" if index != 0
        backtrace.each { |line| lines << line }
      end

      lines << "~~~~~~~ END SERVER THREADS BACKTRACES ~~~~~~~"
      lines << "\n"
    end

    # Recommended that this is not disabled, since it makes debugging
    # failed system tests a lot trickier.
    if ENV["PLAYWRIGHT_DISABLE_VERBOSE_JS_LOGS"].blank? && $playwright_logger
      if example.exception
        lines << "~~~~~~~ JS LOGS ~~~~~~~"

        if $playwright_logger.logs.empty?
          lines << "(no logs)"
        else
          $playwright_logger.logs.each do |log|
            # System specs are full of image load errors that are just noise, no need
            # to log this.
            if (
                 log[:message].include?("Failed to load resource: net::ERR_CONNECTION_REFUSED") &&
                   (log[:message].include?("uploads") || log[:message].include?("images"))
               ) || log[:message].include?("favicon.ico")
              next
            end

            lines << log[:message]
          end
        end

        lines << "~~~~~ END JS LOGS ~~~~~"
      end
    end

    deprecation_error =
      $playwright_logger
        &.logs
        &.filter_map do |log|
          if log[:level] == "trace"
            error = JSON.parse(log[:message][/^fatal_deprecation:(.+)$/, 1])
            "~~~~~~~ JS ERROR ~~~~~~~\n#{error}\n~~~~~ END JS ERROR ~~~~~"
          end
        end
        &.first

    expect(deprecation_error).to be_nil, deprecation_error

    expected_deprecations = RSpec.current_example.metadata[:expected_js_deprecations] || []

    $playwright_logger&.logs&.each do |log|
      next if log[:level] != "count"
      deprecation_id = log[:message][/^deprecation_id:(.+?):\s*\d+$/, 1]
      next if deprecation_id.nil?
      next if expected_deprecations.include?(deprecation_id)

      deprecations = RSpec.current_example.metadata[:js_deprecations] ||= Hash.new(0)
      deprecations[deprecation_id] += 1
    end

    page.execute_script("if (typeof MessageBus !== 'undefined') { MessageBus.stop(); }")

    # Block all incoming requests before resetting Capybara session which will wait for all requests to finish
    BlockRequestsMiddleware.block_requests!

    Capybara.reset_session!
    MessageBus.backend_instance.reset! # Clears all existing backlog from memory backend
  end
end

def global_setting(name, value)
  SiteSetting.hidden_settings_provider.remove_hidden(name)
  SiteSetting.shadowed_settings.delete(name)
  GlobalSetting.reset_s3_cache!

  GlobalSetting.stubs(name).returns(value)

  before_next_spec do
    SiteSetting.hidden_settings_provider.remove_hidden(name)
    SiteSetting.shadowed_settings.delete(name)
    GlobalSetting.reset_s3_cache!
  end
end

def set_cdn_url(cdn_url)
  global_setting :cdn_url, cdn_url
  Rails.configuration.action_controller.asset_host = cdn_url
  ActionController::Base.asset_host = cdn_url

  before_next_spec do
    Rails.configuration.action_controller.asset_host = nil
    ActionController::Base.asset_host = nil
  end
end

def has_trigger?(trigger_name)
  DB.exec(<<~SQL) != 0
    SELECT 1
    FROM INFORMATION_SCHEMA.TRIGGERS
    WHERE trigger_name = '#{trigger_name}'
  SQL
end

def stub_deprecated_settings!(override:)
  SiteSetting.load_settings("#{Rails.root.join("spec/fixtures/site_settings/deprecated_test.yml")}")

  stub_const(
    SiteSettings::DeprecatedSettings,
    "SETTINGS",
    [["old_one", "new_one", override, "0.0.1"]],
  ) do
    SiteSetting.setup_deprecated_methods
    yield
  end

  defaults = SiteSetting.defaults.instance_variable_get(:@defaults)
  defaults.each { |_, hash| hash.delete(:old_one) }
  defaults.each { |_, hash| hash.delete(:new_one) }
end

def apply_base_chrome_args(args = [])
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
