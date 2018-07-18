if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start
end

require 'rubygems'
require 'rbtrace'

# Loading more in this block will cause your tests to run faster. However,
# if you change any configuration or code from libraries loaded here, you'll
# need to restart spork for it take effect.
require 'fabrication'
require 'mocha/api'
require 'certified'
require 'webmock/rspec'

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
    rescue => e
      RspecErrorTracker.last_exception = e
      raise e
    end
  ensure
  end
end

ENV["RAILS_ENV"] ||= 'test'
require File.expand_path("../../config/environment", __FILE__)
require 'rspec/rails'
require 'shoulda'
require 'sidekiq/testing'

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[Rails.root.join("spec/support/**/*.rb")].each { |f| require f }
Dir[Rails.root.join("spec/fabricators/*.rb")].each { |f| require f }

# Require plugin helpers at plugin/[plugin]/spec/plugin_helper.rb (includes symlinked plugins).
if ENV['LOAD_PLUGINS'] == "1"
  Dir[Rails.root.join("plugins/*/spec/plugin_helper.rb")].each do |f|
    require f
  end
end

# let's not run seed_fu every test
SeedFu.quiet = true if SeedFu.respond_to? :quiet

SiteSetting.automatically_download_gravatars = false

SeedFu.seed

RSpec.configure do |config|
  config.fail_fast = ENV['RSPEC_FAIL_FAST'] == "1"
  config.include Helpers
  config.include MessageBus
  config.include RSpecHtmlMatchers
  config.include IntegrationHelpers, type: :request
  config.mock_framework = :mocha
  config.order = 'random'
  config.infer_spec_type_from_file_location!

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = true

  # If true, the base class of anonymous controllers will be inferred
  # automatically. This will be the default behavior in future versions of
  # rspec-rails.
  config.infer_base_class_for_anonymous_controllers = true

  config.before(:suite) do
    Sidekiq.error_handlers.clear

    # Ugly, but needed until we have a user creator
    User.skip_callback(:create, :after, :ensure_in_trust_level_group)

    DiscoursePluginRegistry.clear if ENV['LOAD_PLUGINS'] != "1"
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

    require_dependency 'site_settings/local_process_provider'
    SiteSetting.provider = SiteSettings::LocalProcessProvider.new

    WebMock.disable_net_connect!
  end

  class DiscourseMockRedis < MockRedis
    def without_namespace
      self
    end

    def delete_prefixed(prefix)
      keys("#{prefix}*").each { |k| del(k) }
    end
  end

  config.after :each do |x|
    if x.exception && ex = RspecErrorTracker.last_exception
      # magic in a cause if we have none
      unless x.exception.cause
        class << x.exception
          attr_accessor :cause
        end
        x.exception.cause = ex
      end
    end

    unfreeze_time
  end

  config.before :each do |x|
    # TODO not sure about this, we could use a mock redis implementation here:
    #   this gives us really clean "flush" semantics, howere the side-effect is that
    #   we are no longer using a clean redis implementation, a preferable solution may
    #   be simply flushing before tests, trouble is that redis may be reused with dev
    #   so that would mean the dev would act weird
    #
    #   perf benefit seems low (shaves 20 secs off a 4 minute test suite)
    #
    # $redis = DiscourseMockRedis.new

    RateLimiter.disable
    PostActionNotifier.disable
    SearchIndexer.disable
    UserActionCreator.disable
    NotificationEmailer.disable

    SiteSetting.provider.all.each do |setting|
      SiteSetting.remove_override!(setting.name)
    end

    # very expensive IO operations
    SiteSetting.automatically_download_gravatars = false

    Discourse.clear_readonly!
    Sidekiq::Worker.clear_all

    I18n.locale = :en

    RspecErrorTracker.last_exception = nil

    if $test_cleanup_callbacks
      $test_cleanup_callbacks.reverse_each(&:call)
      $test_cleanup_callbacks = nil
    end
  end

  class TestCurrentUserProvider < Auth::DefaultCurrentUserProvider
    def log_on_user(user, session, cookies)
      session[:current_user_id] = user.id
      super
    end

    def log_off_user(session, cookies)
      session[:current_user_id] = nil
      super
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

  before_next_spec do
    GlobalSetting.reset_s3_cache!
  end
end

def set_env(var, value)
  old = ENV.fetch var, :missing

  ENV[var] = value

  before_next_spec do
    if old == :missing
      ENV.delete var
    else
      ENV[var] = old
    end
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

def freeze_time(now = Time.now)
  datetime = DateTime.parse(now.to_s)
  time = Time.parse(now.to_s)

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
  end
end

def unfreeze_time
  DateTime.unstub(:now)
  Time.unstub(:now)
  Date.unstub(:today)
  TrackTimeStub.unstub(:stubbed)
end

def file_from_fixtures(filename, directory = "images")
  FileUtils.mkdir_p("#{Rails.root}/tmp/spec") unless Dir.exists?("#{Rails.root}/tmp/spec")
  FileUtils.cp("#{Rails.root}/spec/fixtures/#{directory}/#{filename}", "#{Rails.root}/tmp/spec/#{filename}")
  File.new("#{Rails.root}/tmp/spec/#{filename}")
end
