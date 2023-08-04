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
require "pry-byebug"
require "pry-rails"
require "fabrication"
require "mocha/api"
require "certified"
require "webmock/rspec"
require "minio_runner"

class RspecErrorTracker
  def self.last_exception=(ex)
    @ex = ex
  end

  def self.last_exception
    @ex
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
      RspecErrorTracker.last_exception = e
      raise e
    end
  ensure
  end
end

ENV["RAILS_ENV"] ||= "test"
require File.expand_path("../../config/environment", __FILE__)
require "rspec/rails"
require "shoulda-matchers"
require "sidekiq/testing"
require "test_prof/recipes/rspec/let_it_be"
require "test_prof/before_all/adapters/active_record"
require "webdrivers"
require "selenium-webdriver"
require "capybara/rails"

Webdrivers::Chromedriver.required_version = "114.0.5735.90"

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

    # very expensive IO operations
    SiteSetting.automatically_download_gravatars = false

    Discourse.clear_readonly!
    Sidekiq::Worker.clear_all

    I18n.locale = SiteSettings::DefaultsProvider::DEFAULT_LOCALE

    RspecErrorTracker.last_exception = nil

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
  end
end

TestProf::BeforeAll.configure do |config|
  config.after(:begin) do
    DB.test_transaction = ActiveRecord::Base.connection.current_transaction
    TestSetup.test_setup
  end
end

if ENV["PREFABRICATION"] == "0"
  module Prefabrication
    def fab!(name, &blk)
      let!(name, &blk)
    end
  end

  RSpec.configure { |config| config.extend Prefabrication }
else
  TestProf::LetItBe.configure { |config| config.alias_to :fab!, refind: true }
end

PER_SPEC_TIMEOUT_SECONDS = 30

RSpec.configure do |config|
  config.fail_fast = ENV["RSPEC_FAIL_FAST"] == "1"
  config.silence_filter_announcements = ENV["RSPEC_SILENCE_FILTER_ANNOUNCEMENTS"] == "1"
  config.extend RedisSnapshotHelper
  config.include Helpers
  config.include MessageBus
  config.include RSpecHtmlMatchers
  config.include IntegrationHelpers, type: :request
  config.include SystemHelpers, type: :system
  config.include WebauthnIntegrationHelpers
  config.include SiteSettingsHelpers
  config.include SidekiqHelpers
  config.include UploadsHelpers
  config.include OneboxHelpers
  config.include FastImageHelpers
  config.mock_framework = :mocha
  config.order = "random"
  config.infer_spec_type_from_file_location!

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

  config.before(:suite) do
    CachedCounting.disable

    begin
      ActiveRecord::Migration.check_pending!
    rescue ActiveRecord::PendingMigrationError
      raise "There are pending migrations, run RAILS_ENV=test bin/rake db:migrate"
    end

    Sidekiq.error_handlers.clear

    # Ugly, but needed until we have a user creator
    User.skip_callback(:create, :after, :ensure_in_trust_level_group)

    DiscoursePluginRegistry.reset! if ENV["LOAD_PLUGINS"] != "1"
    Discourse.current_user_provider = TestCurrentUserProvider

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

    MinioRunner.config do |minio_runner_config|
      minio_runner_config.minio_domain = ENV["MINIO_RUNNER_MINIO_DOMAIN"] || "minio.local"
      minio_runner_config.buckets =
        (
          if ENV["MINIO_RUNNER_BUCKETS"].present?
            ENV["MINIO_RUNNER_BUCKETS"]&.split(",")
          else
            ["discoursetest"]
          end
        )
      minio_runner_config.public_buckets =
        (
          if ENV["MINIO_RUNNER_PUBLIC_BUCKETS"].present?
            ENV["MINIO_RUNNER_PUBLIC_BUCKETS"]&.split(",")
          else
            ["discoursetest"]
          end
        )
    end

    WebMock.disable_net_connect!(
      allow_localhost: true,
      allow: [
        Webdrivers::Chromedriver.base_url,
        *MinioRunner.config.minio_urls,
        URI(MinioRunner::MinioBinary.platform_binary_url).host,
      ],
    )

    if ENV["CAPYBARA_DEFAULT_MAX_WAIT_TIME"].present?
      Capybara.default_max_wait_time = ENV["CAPYBARA_DEFAULT_MAX_WAIT_TIME"].to_i
    end

    Capybara.threadsafe = true
    Capybara.disable_animation = true

    # Click offsets is calculated from top left of element
    Capybara.w3c_click_offset = false

    Capybara.configure do |capybara_config|
      capybara_config.server_host = "localhost"
      capybara_config.server_port = 31_337 + ENV["TEST_ENV_NUMBER"].to_i
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

    # possible values: OFF, SEVERE, WARNING, INFO, DEBUG, ALL
    browser_log_level = ENV["SELENIUM_BROWSER_LOG_LEVEL"] || "SEVERE"

    chrome_browser_options =
      Selenium::WebDriver::Chrome::Options
        .new(logging_prefs: { "browser" => browser_log_level, "driver" => "ALL" })
        .tap do |options|
          apply_base_chrome_options(options)
          options.add_argument("--window-size=1400,1400")
          options.add_preference("download.default_directory", Downloads::FOLDER)
        end

    Capybara.register_driver :selenium_chrome do |app|
      Capybara::Selenium::Driver.new(app, browser: :chrome, options: chrome_browser_options)
    end

    Capybara.register_driver :selenium_chrome_headless do |app|
      chrome_browser_options.add_argument("--headless=new")

      Capybara::Selenium::Driver.new(app, browser: :chrome, options: chrome_browser_options)
    end

    mobile_chrome_browser_options =
      Selenium::WebDriver::Chrome::Options
        .new(logging_prefs: { "browser" => browser_log_level, "driver" => "ALL" })
        .tap do |options|
          options.add_emulation(device_name: "iPhone 12 Pro")
          apply_base_chrome_options(options)
        end

    Capybara.register_driver :selenium_mobile_chrome do |app|
      Capybara::Selenium::Driver.new(app, browser: :chrome, options: mobile_chrome_browser_options)
    end

    Capybara.register_driver :selenium_mobile_chrome_headless do |app|
      mobile_chrome_browser_options.add_argument("--headless=new")
      Capybara::Selenium::Driver.new(app, browser: :chrome, options: mobile_chrome_browser_options)
    end

    if ENV["ELEVATED_UPLOADS_ID"]
      DB.exec "SELECT setval('uploads_id_seq', 10000)"
    else
      DB.exec "SELECT setval('uploads_id_seq', 1)"
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

  config.after :each do |example|
    if example.exception && ex = RspecErrorTracker.last_exception
      # magic in a cause if we have none
      unless example.exception.cause
        class << example.exception
          attr_accessor :cause
        end
        example.exception.cause = ex
      end
    end

    unfreeze_time
    ActionMailer::Base.deliveries.clear
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

    config.around do |example|
      Timeout.timeout(
        PER_SPEC_TIMEOUT_SECONDS,
        SpecTimeoutError,
        "Spec timed out after #{PER_SPEC_TIMEOUT_SECONDS} seconds",
      ) do
        example.run
      rescue SpecTimeoutError
      end
    end
  end

  if ENV["DISCOURSE_RSPEC_PROFILE_EACH_EXAMPLE"]
    config.around :each do |example|
      measurement = Benchmark.measure { example.run }
      RSpec.current_example.metadata[:run_duration_ms] = (measurement.real * 1000).round(2)
    end
  end

  config.before :each do
    # This allows DB.transaction_open? to work in tests. See lib/mini_sql_multisite_connection.rb
    DB.test_transaction = ActiveRecord::Base.connection.current_transaction
    TestSetup.test_setup
  end

  # Match the request hostname to the value in `database.yml`
  config.before(:each, type: %i[request multisite system]) { host! "test.localhost" }

  last_driven_by = nil
  config.before(:each, type: :system) do |example|
    driver = [:selenium]
    driver << :mobile if example.metadata[:mobile]
    driver << :chrome
    driver << :headless unless ENV["SELENIUM_HEADLESS"] == "0"
    driven_by driver.join("_").to_sym

    setup_system_test
  end

  config.after(:each, type: :system) do |example|
    lines = RSpec.current_example.metadata[:extra_failure_lines]

    # This is disabled by default because it is super verbose,
    # if you really need to dig into how selenium is communicating
    # for system tests then enable it.
    if ENV["SELENIUM_VERBOSE_DRIVER_LOGS"]
      lines << "~~~~~~~ DRIVER LOGS ~~~~~~~"
      page.driver.browser.logs.get(:driver).each { |log| lines << log.message }
      lines << "~~~~~ END DRIVER LOGS ~~~~~"
    end

    # Recommended that this is not disabled, since it makes debugging
    # failed system tests a lot trickier.
    if ENV["SELENIUM_DISABLE_VERBOSE_JS_LOGS"].blank?
      if example.exception
        skip_js_errors = false

        if example.exception.kind_of?(RSpec::Core::MultipleExceptionError)
          lines << "~~~~~~~ SYSTEM TEST ERRORS ~~~~~~~"
          example.exception.all_exceptions.each { |ex| lines << ex.message }
          lines << "~~~~~ END SYSTEM TEST ERRORS ~~~~~"

          skip_js_errors = true
        end

        if !skip_js_errors
          lines << "~~~~~~~ JS LOGS ~~~~~~~"
          logs = page.driver.browser.logs.get(:browser)
          if logs.empty?
            lines << "(no logs)"
          else
            logs.each do |log|
              # System specs are full of image load errors that are just noise, no need
              # to log this.
              if (
                   log.message.include?("Failed to load resource: net::ERR_CONNECTION_REFUSED") &&
                     (log.message.include?("uploads") || log.message.include?("images"))
                 ) || log.message.include?("favicon.ico")
                next
              end

              lines << log.message
            end
          end
          lines << "~~~~~ END JS LOGS ~~~~~"
        end
      end
    end

    page.execute_script("if (typeof MessageBus !== 'undefined') { MessageBus.stop(); }")
    Capybara.reset_sessions!
    Capybara.use_default_driver
    Discourse.redis.flushdb
  end

  config.before(:each, type: :multisite) do
    Rails.configuration.multisite = true # rubocop:disable Discourse/NoDirectMultisiteManipulation

    RailsMultisite::ConnectionManagement.config_filename = "spec/fixtures/multisite/two_dbs.yml"

    RailsMultisite::ConnectionManagement.establish_connection(db: "default")
  end

  config.after(:each, type: :multisite) do
    ActiveRecord::Base.clear_all_connections!
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

def file_from_fixtures(filename, directory = "images")
  tmp_file_path = File.join(concurrency_safe_tmp_dir, SecureRandom.hex << filename)
  FileUtils.cp("#{Rails.root}/spec/fixtures/#{directory}/#{filename}", tmp_file_path)
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

def silence_stdout
  STDOUT.stubs(:write)
  yield
ensure
  STDOUT.unstub(:write)
end

def track_log_messages
  old_logger = Rails.logger
  logger = Rails.logger = FakeLogger.new
  yield logger
  logger
ensure
  Rails.logger = old_logger
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

def apply_base_chrome_options(options)
  # possible values: undocked, bottom, right, left
  chrome_dev_tools = ENV["CHROME_DEV_TOOLS"]

  if chrome_dev_tools
    options.add_argument("--auto-open-devtools-for-tabs")
    options.add_preference(
      "devtools",
      "preferences" => {
        "currentDockState" => "\"#{chrome_dev_tools}\"",
        "panel-selectedTab" => '"console"',
      },
    )
  end

  options.add_argument("--no-sandbox")
  options.add_argument("--disable-dev-shm-usage")
  options.add_argument("--mute-audio")

  # A file that contains just a list of paths like so:
  #
  # /home/me/.config/google-chrome/Default/Extensions/bmdblncegkenkacieihfhpjfppoconhi/4.9.1_0
  #
  # These paths can be found for each individual extension via the
  # chrome://extensions/ page.
  if ENV["CHROME_LOAD_EXTENSIONS_MANIFEST"].present?
    File
      .readlines(ENV["CHROME_LOAD_EXTENSIONS_MANIFEST"])
      .each { |path| options.add_argument("--load-extension=#{path}") }
  end

  if ENV["CHROME_DISABLE_FORCE_DEVICE_SCALE_FACTOR"].blank?
    options.add_argument("--force-device-scale-factor=1")
  end
end

class SpecSecureRandom
  class << self
    attr_accessor :value
  end
end
