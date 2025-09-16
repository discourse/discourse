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
require "pry-stack_explorer"
require "fabrication"
require "mocha/api"
require "certified"
require "webmock/rspec"
require "minio_runner"

CHROME_REMOTE_DEBUGGING_PORT = (ENV["CHROME_REMOTE_DEBUGGING_PORT"] || 50_062).to_s
CHROME_REMOTE_DEBUGGING_ADDRESS = ENV["CHROME_REMOTE_DEBUGGING_ADDRESS"] || "127.0.0.1"

class RspecErrorTracker
  def self.exceptions
    @exceptions ||= {}
  end

  def self.clear_exceptions
    @exceptions&.clear
  end

  def self.report_exception(path, exception)
    exceptions[path] = exception
  end

  def initialize(app, config = {})
    @app = app
  end

  def call(env)
    begin
      @app.call(env)

      # This is a little repetitive, but since WebMock::NetConnectNotAllowedError
      # and also Mocha::ExpectationError inherit from Exception instead of StandardError
      # they do not get captured by the rescue => e shorthand :(
    rescue WebMock::NetConnectNotAllowedError, Mocha::ExpectationError, StandardError => e
      RspecErrorTracker.report_exception(env["PATH_INFO"], e)
      raise e
    end
  end
end

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
require File.expand_path("../../config/environment", __FILE__)
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
require_relative "./helpers/redis_snapshot_helper"

# Require plugin helpers at plugin/[plugin]/spec/plugin_helper.rb (includes symlinked plugins).
if ENV["LOAD_PLUGINS"] == "1"
  Dir[Rails.root.join("plugins/*/spec/plugin_helper.rb")].each { |f| require f }

  Dir[Rails.root.join("plugins/*/spec/fabricators/**/*.rb")].each { |f| require f }

  Dir[Rails.root.join("plugins/*/spec/system/page_objects/**/*.rb")].each { |f| require f }
end

# let's not run seed_fu every test
SeedFu.quiet = true if SeedFu.respond_to? :quiet

SiteSetting.automatically_download_gravatars = false

SeedFu.seed

# we need this env var to ensure that we can impersonate in test
# this enable integration_helpers sign_in helper
ENV["DISCOURSE_DEV_ALLOW_ANON_TO_IMPERSONATE"] = "1"

module TestSetup
  # This is run before each test and before each before_all block
  def self.test_setup(x = nil)
    RateLimiter.disable
    PostActionNotifier.disable
    SearchIndexer.disable
    UserActionManager.disable
    NotificationEmailer.disable
    SiteIconManager.disable
    WordWatcher.disable_cache

    SiteSetting.provider.all.each { |setting| SiteSetting.remove_override!(setting.name) }
    SiteSetting.refresh!(refresh_site_settings: false, refresh_theme_site_settings: true)

    # very expensive IO operations
    SiteSetting.automatically_download_gravatars = false

    Discourse.clear_readonly!
    Sidekiq::Worker.clear_all

    I18n.locale = SiteSettings::DefaultsProvider::DEFAULT_LOCALE

    RspecErrorTracker.clear_exceptions

    if $test_cleanup_callbacks
      $test_cleanup_callbacks.reverse_each(&:call)
      $test_cleanup_callbacks = nil
    end

    # in test this is very expensive, we explicitly enable when needed
    Topic.update_featured_topics = false

    # Running jobs are expensive and most of our tests are not concern with
    # code that runs inside jobs. run_later! means they are put on the redis
    # queue and never processed.
    Jobs.run_later!

    # Don't track ApplicationRequests in test mode unless opted in
    ApplicationRequest.disable

    # Don't queue badge grant in test mode
    BadgeGranter.disable_queue

    OmniAuth.config.test_mode = false

    Middleware::AnonymousCache.disable_anon_cache
    BlockRequestsMiddleware.allow_requests!
    BlockRequestsMiddleware.current_example_location = nil
    ApplicationSerializer.fragment_cache.clear
  end
end

if ENV["PREFABRICATION"] == "0"
  module Prefabrication
    def fab!(name, fabricator_name = nil, **opts, &blk)
      blk ||= proc { Fabricate(fabricator_name || name) }
      let!(name, &blk)
    end
  end
else
  require "test_prof/recipes/rspec/let_it_be"
  require "test_prof/before_all/adapters/active_record"

  TestProf::BeforeAll.configure do |config|
    config.after(:begin) do
      DB.test_transaction = ActiveRecord::Base.connection.current_transaction
      TestSetup.test_setup
    end
  end

  module Prefabrication
    def fab!(name, fabricator_name = nil, **opts, &blk)
      blk ||= proc { Fabricate(fabricator_name || name) }
      let_it_be(name, refind: true, **opts, &blk)
    end
  end
end

PER_SPEC_TIMEOUT_SECONDS = 45
BROWSER_READ_TIMEOUT = 30

# To avoid erasing `any_instance` from Mocha
require "rspec/mocks/syntax"
RSpec::Mocks::Syntax.singleton_class.define_method(:enable_should) { |*| nil }
RSpec::Mocks::Syntax.singleton_class.define_method(:disable_should) { |*| nil }

RSpec::Mocks::ArgumentMatchers.remove_method(:hash_including) # We’re currently relying on the version from Webmock

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.fail_fast = ENV["RSPEC_FAIL_FAST"] == "1"
  config.silence_filter_announcements = ENV["RSPEC_SILENCE_FILTER_ANNOUNCEMENTS"] == "1"
  config.extend RedisSnapshotHelper
  config.extend Prefabrication
  config.include Helpers
  config.include MessageBus
  config.include RSpecHtmlMatchers
  config.include IntegrationHelpers, type: :request
  config.include SystemHelpers, type: :system
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

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
    mocks.verify_doubled_constant_names = true
    mocks.syntax = :expect
  end
  config.mock_with MultiMock::Adapter.for(:mocha, :rspec)

  config.include Mocha::API

  if ENV["GITHUB_ACTIONS"]
    # Enable color output in GitHub Actions
    # This eventually will be `config.color_mode = :on` in RSpec 4?
    config.tty = true
    config.color = true
  end

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
    CachedCounting.disable

    begin
      ActiveRecord::Migration.check_all_pending!
    rescue ActiveRecord::PendingMigrationError
      raise "There are pending migrations, run RAILS_ENV=test bin/rake db:migrate"
    end

    Sidekiq.default_configuration.error_handlers.clear

    # Ugly, but needed until we have a user creator
    User.skip_callback(:create, :after, :ensure_in_trust_level_group)

    DiscoursePluginRegistry.reset! if ENV["LOAD_PLUGINS"] != "1"
    Discourse.current_user_provider = TestCurrentUserProvider
    Discourse::Application.load_tasks

    SystemThemesManager.clear_system_theme_user_history!
    ThemeField.delete_all
    JavascriptCache.delete_all
    ThemeSiteSetting.delete_all
    SiteSetting.refresh!

    # Rebase defaults
    #
    # We nuke the DB storage provider from site settings, so need to yank out the existing settings
    #  and pretend they are default.
    # There are a bunch of settings that are seeded, they must be loaded as defaults
    SiteSetting.current.each do |k, v|
      # skip setting defaults for settings that are in unloaded plugins
      SiteSetting.defaults.set_regardless_of_locale(k, v) if SiteSetting.respond_to? k
    end

    SiteSetting.provider = TestLocalProcessProvider.new

    # Used for S3 system specs, see also setup_s3_system_test.
    MinioRunner.config do |minio_runner_config|
      minio_runner_config.minio_domain = ENV["MINIO_RUNNER_MINIO_DOMAIN"] || "minio.local"
      minio_runner_config.buckets =
        (
          if ENV["MINIO_RUNNER_BUCKETS"]
            ENV["MINIO_RUNNER_BUCKETS"].split(",")
          else
            ["discoursetest"]
          end
        )
      minio_runner_config.public_buckets =
        (
          if ENV["MINIO_RUNNER_PUBLIC_BUCKETS"]
            ENV["MINIO_RUNNER_PUBLIC_BUCKETS"].split(",")
          else
            ["discoursetest"]
          end
        )

      test_i = ENV["TEST_ENV_NUMBER"].to_i

      data_dir = "#{Rails.root}/tmp/test_data_#{test_i}/minio"
      FileUtils.rm_rf(data_dir)
      FileUtils.mkdir_p(data_dir)
      minio_runner_config.minio_data_directory = data_dir

      minio_runner_config.minio_port = 9_000 + 2 * test_i
      minio_runner_config.minio_console_port = 9_001 + 2 * test_i
    end

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

    module IgnoreUnicornCapturedErrors
      def raise_server_error!
        super
      rescue EOFError, Errno::ECONNRESET, Errno::EPIPE, Errno::ENOTCONN => e
        # Ignore these exceptions - caused by client. Handled by unicorn in dev/prod
        # https://github.com/defunkt/unicorn/blob/d947cb91cf/lib/unicorn/http_server.rb#L570-L573
      end
    end

    Capybara::Session.class_eval { prepend IgnoreUnicornCapturedErrors }

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
        begin
          super
        rescue StandardError => e
          seconds = session_options.default_max_wait_time if [nil, true].include? seconds
          if catch_error?(e, errors) && seconds != 0
            # This error will only have been raised if the timer expired
            timeout_error = CapybaraTimedOut.new(seconds, e)
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
          else
            raise
          end
        end
      end
    end

    Capybara::Node::Base.prepend(CapybaraTimeoutExtension)

    config.before(:each, type: :system) do |example|
      if example.metadata[:time]
        freeze_time(example.metadata[:time])
        page.driver.with_playwright_page do |pw_page|
          pw_page.clock.set_fixed_time(example.metadata[:time])
        end
      end
    end

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

  class TestLocalProcessProvider < SiteSettings::LocalProcessProvider
    attr_accessor :current_site

    def initialize
      super
      self.current_site = "test"
    end
  end

  config.after(:suite) do
    FileUtils.remove_dir(concurrency_safe_tmp_dir, true) if SpecSecureRandom.value
    Downloads.clear
    MinioRunner.stop
  end

  config.around :each do |example|
    before_event_count = DiscourseEvent.events.values.sum(&:count)
    example.run
    after_event_count = DiscourseEvent.events.values.sum(&:count)
    expect(before_event_count).to eq(after_event_count),
    "DiscourseEvent registrations were not cleaned up"
  end

  if ENV["CI"]
    class SpecTimeoutError < StandardError
    end

    mutex = Mutex.new
    condition_variable = ConditionVariable.new
    test_running = false
    is_waiting = false

    backtrace_logger =
      Thread.new do
        loop do
          mutex.synchronize do
            is_waiting = true
            condition_variable.wait(mutex)
            is_waiting = false
          end

          sleep PER_SPEC_TIMEOUT_SECONDS - 1

          if mutex.synchronize { test_running }
            puts "::group::[#{Process.pid}] Threads backtraces 1 second before timeout"

            Thread.list.each do |thread|
              puts "\n"
              thread.backtrace.each { |line| puts line }
              puts "\n"
            end

            puts "::endgroup::"
          end
        rescue StandardError => e
          puts "Error in backtrace logger: #{e}"
        end
      end

    config.around do |example_procsy|
      Timeout.timeout(
        PER_SPEC_TIMEOUT_SECONDS,
        SpecTimeoutError,
        "Spec timed out after #{PER_SPEC_TIMEOUT_SECONDS} seconds",
      ) do
        mutex.synchronize do
          test_running = true
          condition_variable.signal
        end

        example_procsy.run
      rescue SpecTimeoutError
        puts "--- Potential timeout example ---"
        puts example_procsy.example.metadata
        puts "---"
      ensure
        mutex.synchronize { test_running = false }
        backtrace_logger.wakeup
        sleep 0.01 while !mutex.synchronize { is_waiting }
      end
    end

    # This is a monkey patch for the `Capybara.using_session` method in `capybara`. For some
    # unknown reasons on Github Actions, we are seeing system tests failing intermittently with the error
    # `Socket::ResolutionError: getaddrinfo: Temporary failure in name resolution` when the app tries to resolve
    # `localhost` from within a `Capybara#using_session` block.
    #
    # Too much time has been spent trying to debug this issue and the root cause is still unknown so we are just dropping
    # this workaround for now where we will retry the block once before raising the error.
    #
    # Potentially related: https://bugs.ruby-lang.org/issues/20172
    module Capybara
      class << self
        def using_session_with_localhost_resolution(name, &block)
          attempts = 0
          self._using_session(name, &block)
        rescue Socket::ResolutionError
          puts "Socket::ResolutionError error encountered... Current thread count: #{Thread.list.size}"
          attempts += 1
          attempts <= 1 ? retry : raise
        end
      end
    end

    Capybara.singleton_class.class_eval do
      alias_method :_using_session, :using_session
      alias_method :using_session, :using_session_with_localhost_resolution
    end
  end

  if ENV["DISCOURSE_RSPEC_PROFILE_EACH_EXAMPLE"]
    config.around :each do |example|
      measurement = Benchmark.measure { example.run }
      RSpec.current_example.metadata[:run_duration_ms] = (measurement.real * 1000).round(2)
    end
  end

  if ENV["GITHUB_ACTIONS"]
    config.around :each, capture_log: true do |example|
      original_logger = ActiveRecord::Base.logger
      io = StringIO.new
      io_logger = Logger.new(io)
      io_logger.level = Logger::DEBUG
      ActiveRecord::Base.logger = io_logger

      example.run

      RSpec.current_example.metadata[:active_record_debug_logs] = io.string
    ensure
      ActiveRecord::Base.logger = original_logger
    end
  end

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
      # On Rails 7, we have seen instances of deadlocks between the lock in [ActiveRecord::ConnectionAdapaters::AbstractAdapter](https://github.com/rails/rails/blob/9d1673853f13cd6f756315ac333b20d512db4d58/activerecord/lib/active_record/connection_adapters/abstract_adapter.rb#L86)
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
      timezoneId: example.metadata[:timezone],
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
    end
  end

  config.after :each do |example|
    if example.exception && RspecErrorTracker.exceptions.present?
      lines = (RSpec.current_example.metadata[:extra_failure_lines] ||= +"")

      lines << "\n"
      lines << "~~~~~~~ SERVER EXCEPTIONS ~~~~~~~"
      lines << "\n"

      RspecErrorTracker.exceptions.each_with_index do |(path, ex), index|
        lines << "\n"
        lines << "Error encountered while processing #{path}.\n"
        lines << "  #{ex.class}: #{ex.message}\n"
        framework_lines_excluded = 0

        ex.backtrace.each_with_index do |line, backtrace_index|
          # This behaviour is enabled by default, to include gems in
          # the backtrace set DISCOURSE_INCLUDE_GEMS_IN_RSPEC_BACKTRACE=1
          if ENV["DISCOURSE_INCLUDE_GEMS_IN_RSPEC_BACKTRACE"] != "1"
            if line.match?(%r{/gems/})
              framework_lines_excluded += 1
              next
            else
              if framework_lines_excluded.positive?
                lines << "    ...(#{framework_lines_excluded} framework line(s) excluded)\n"
                framework_lines_excluded = 0
              end
            end
          end
          lines << "    #{line}\n"
        end
      end

      lines << "\n"
      lines << "~~~~~~~ END SERVER EXCEPTIONS ~~~~~~~"
      lines << "\n"
    end

    unfreeze_time
    ActionMailer::Base.deliveries.clear
    Discourse.redis.flushdb
    Scheduler::Defer.do_all_work
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

    $playwright_logger.logs.each do |log|
      next if log[:level] != "WARNING"
      deprecation_id = log[:message][/\[deprecation id: ([^\]]+)\]/, 1]
      next if deprecation_id.nil?

      deprecations = RSpec.current_example.metadata[:js_deprecations] ||= {}
      deprecations[deprecation_id] ||= 0
      deprecations[deprecation_id] += 1
    end

    page.execute_script("if (typeof MessageBus !== 'undefined') { MessageBus.stop(); }")

    # Block all incoming requests before resetting Capybara session which will wait for all requests to finish
    BlockRequestsMiddleware.block_requests!

    Capybara.reset_session!
    MessageBus.backend_instance.reset! # Clears all existing backlog from memory backend
  end

  config.before(:each, type: :multisite) do
    Rails.configuration.multisite = true # rubocop:disable Discourse/NoDirectMultisiteManipulation

    RailsMultisite::ConnectionManagement.config_filename = "spec/fixtures/multisite/two_dbs.yml"

    RailsMultisite::ConnectionManagement.establish_connection(db: "default")
  end

  config.after(:each, type: :multisite) do
    ActiveRecord::Base.connection_handler.clear_all_connections!
    Rails.configuration.multisite = false # rubocop:disable Discourse/NoDirectMultisiteManipulation
    RailsMultisite::ConnectionManagement.clear_settings!
    ActiveRecord::Base.establish_connection
  end

  class TestCurrentUserProvider < Auth::DefaultCurrentUserProvider
    def log_on_user(user, session, cookies, opts = {})
      session[:current_user_id] = user.id
      super
    end

    def log_off_user(session, cookies)
      session[:current_user_id] = nil
      super
    end
  end

  # Normally we `use_transactional_fixtures` to clear out a database after a test
  # runs. However, this does not apply to tests done for multisite. The second time
  # a test runs you can end up with stale data that breaks things. This method will
  # force a rollback after using a multisite connection.
  def test_multisite_connection(name)
    RailsMultisite::ConnectionManagement.with_connection(name) do
      ActiveRecord::Base.transaction(joinable: false) do
        yield
        raise ActiveRecord::Rollback
      end
    end
  end
end

class TrackTimeStub
  def self.stubbed
    false
  end
end

def before_next_spec(&callback)
  ($test_cleanup_callbacks ||= []) << callback
end

def global_setting(name, value)
  GlobalSetting.reset_s3_cache!

  GlobalSetting.stubs(name).returns(value)

  before_next_spec { GlobalSetting.reset_s3_cache! }
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

# Time.now can cause flaky tests, especially in cases like
# leap days. This method freezes time at a "safe" specific
# time (the Discourse 1.1 release date), so it will not be
# affected by further temporal disruptions.
def freeze_time_safe
  freeze_time(DateTime.parse("2014-08-26 12:00:00"))
end

def freeze_time(now = Time.now)
  time = now
  datetime = now

  if Time === now
    datetime = now.to_datetime
  elsif DateTime === now
    time = now.to_time
  else
    datetime = DateTime.parse(now.to_s)
    time = Time.parse(now.to_s)
  end

  if block_given?
    raise "nested freeze time not supported" if TrackTimeStub.stubbed
  end

  DateTime.stubs(:now).returns(datetime)
  Time.stubs(:now).returns(time)
  Date.stubs(:today).returns(datetime.to_date)
  TrackTimeStub.stubs(:stubbed).returns(true)

  if block_given?
    begin
      yield
    ensure
      unfreeze_time
    end
  else
    time
  end
end

def unfreeze_time
  DateTime.unstub(:now)
  Time.unstub(:now)
  Date.unstub(:today)
  TrackTimeStub.unstub(:stubbed)
end

def file_from_fixtures(filename, directory = "images", root_path = "#{Rails.root}/spec/fixtures")
  tmp_file_path = File.join(concurrency_safe_tmp_dir, SecureRandom.hex << filename)
  FileUtils.cp("#{root_path}/#{directory}/#{filename}", tmp_file_path)
  File.new(tmp_file_path)
end

def plugin_file_from_fixtures(filename, directory = "images")
  # We [1] here instead of [0] because the first caller is the current method.
  #
  # /home/mb/repos/discourse-ai/spec/lib/modules/ai_bot/tools/discourse_meta_search_spec.rb:17:in `block (2 levels) in <main>'
  first_non_gem_caller = caller_locations.select { |loc| !loc.to_s.match?(/gems/) }[1]&.path
  raise StandardError.new("Could not find caller for fixture #{filename}") if !first_non_gem_caller

  # This is the full path of the plugin spec file that needs a fixture.
  # realpath makes sure we follow symlinks.
  #
  # #<Pathname:/home/mb/repos/discourse-ai/spec/lib/modules/ai_bot/tools/discourse_meta_search_spec.rb>
  plugin_caller_path = Pathname.new(first_non_gem_caller).realpath

  plugin_match =
    Discourse.plugins.find do |plugin|
      # realpath makes sure we follow symlinks
      plugin_caller_path.to_s.starts_with?(Pathname.new(plugin.root_dir).realpath.to_s)
    end

  if !plugin_match
    raise StandardError.new(
            "Could not find matching plugin for #{plugin_caller_path} and fixture #{filename}",
          )
  end

  file_from_fixtures(filename, directory, "#{plugin_match.root_dir}/spec/fixtures")
end

def file_from_contents(contents, filename, directory = "images")
  tmp_file_path = File.join(concurrency_safe_tmp_dir, SecureRandom.hex << filename)
  File.write(tmp_file_path, contents)
  File.new(tmp_file_path)
end

def plugin_from_fixtures(plugin_name)
  tmp_plugins_dir = File.join(concurrency_safe_tmp_dir, "plugins")

  FileUtils.mkdir(tmp_plugins_dir) if !Dir.exist?(tmp_plugins_dir)
  FileUtils.cp_r("#{Rails.root}/spec/fixtures/plugins/#{plugin_name}", tmp_plugins_dir)

  plugin = Plugin::Instance.new
  plugin.path = File.join(tmp_plugins_dir, plugin_name, "plugin.rb")
  plugin
end

def concurrency_safe_tmp_dir
  SpecSecureRandom.value ||= SecureRandom.hex
  dir_path = File.join(Dir.tmpdir, "rspec_#{Process.pid}_#{SpecSecureRandom.value}")
  FileUtils.mkdir_p(dir_path) unless Dir.exist?(dir_path)
  dir_path
end

def has_trigger?(trigger_name)
  DB.exec(<<~SQL) != 0
    SELECT 1
    FROM INFORMATION_SCHEMA.TRIGGERS
    WHERE trigger_name = '#{trigger_name}'
  SQL
end

def stub_deprecated_settings!(override:)
  SiteSetting.load_settings("#{Rails.root}/spec/fixtures/site_settings/deprecated_test.yml")

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

def silence_stdout
  STDOUT.stubs(:write)
  yield
ensure
  STDOUT.unstub(:write)
end

def Rails.logger=(logger)
  raise "Setting Rails.logger is not allowed as it can lead to unexpected behavior in tests. Use `fake_logger = track_log_messages { ... }` instead."
end

def track_log_messages
  logger = FakeLogger.new
  Rails.logger.broadcast_to(logger)
  yield logger
  logger
ensure
  Rails.logger.stop_broadcasting_to(logger)
end

# this takes a string and returns a copy where 2 different
# characters are swapped.
# e.g.
#   swap_2_different_characters("abc") => "bac"
#   swap_2_different_characters("aac") => "caa"
def swap_2_different_characters(str)
  swap1 = 0
  swap2 = str.split("").find_index { |c| c != str[swap1] }
  # if the string is made up of 1 character
  return str if !swap2
  str = str.dup
  str[swap1], str[swap2] = str[swap2], str[swap1]
  str
end

def create_request_env(path: nil)
  env = Rails.application.env_config.dup
  env.merge!(Rack::MockRequest.env_for(path)) if path
  env
end

def create_auth_cookie(token:, user_id: nil, trust_level: nil, issued_at: Time.current)
  data = { token: token, user_id: user_id, trust_level: trust_level, issued_at: issued_at.to_i }
  jar = ActionDispatch::Cookies::CookieJar.build(ActionDispatch::TestRequest.create, {})
  jar.encrypted[:_t] = { value: data }
  CGI.escape(jar[:_t])
end

def decrypt_auth_cookie(cookie)
  ActionDispatch::Cookies::CookieJar.build(
    ActionDispatch::TestRequest.create,
    { _t: cookie },
  ).encrypted[
    :_t
  ].with_indifferent_access
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

class SpecSecureRandom
  class << self
    attr_accessor :value
  end
end
