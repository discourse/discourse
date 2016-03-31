if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start
end

require 'rubygems'
require 'spork'
require 'rbtrace'
#uncomment the following line to use spork with the debugger
#require 'spork/ext/ruby-debug'

require 'fakeweb'
FakeWeb.allow_net_connect = false

Spork.prefork do
  # Loading more in this block will cause your tests to run faster. However,
  # if you change any configuration or code from libraries loaded here, you'll
  # need to restart spork for it take effect.
  require 'fabrication'
  require 'mocha/api'
  require 'fakeweb'
  require 'certified'

  ENV["RAILS_ENV"] ||= 'test'
  require File.expand_path("../../config/environment", __FILE__)
  require 'rspec/rails'
  require 'shoulda'

  # Requires supporting ruby files with custom matchers and macros, etc,
  # in spec/support/ and its subdirectories.
  Dir[Rails.root.join("spec/support/**/*.rb")].each {|f| require f}
  Dir[Rails.root.join("spec/fabricators/*.rb")].each {|f| require f}

  # let's not run seed_fu every test
  SeedFu.quiet = true if SeedFu.respond_to? :quiet

  SiteSetting.automatically_download_gravatars = false

  SeedFu.seed

  RSpec.configure do |config|
    config.fail_fast = ENV['RSPEC_FAIL_FAST'] == "1"
    config.include Helpers
    config.include MessageBus
    config.include RSpecHtmlMatchers
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
      SiteSetting.current.each do |k,v|
        SiteSetting.defaults[k] = v
      end

      require_dependency 'site_settings/local_process_provider'
      SiteSetting.provider = SiteSettings::LocalProcessProvider.new
    end

    class DiscourseMockRedis < MockRedis
      def without_namespace
        self
      end

      def delete_prefixed(prefix)
        keys("#{prefix}*").each { |k| del(k) }
      end
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
      #
      # disable all observers, enable as needed during specs
      #
      ActiveRecord::Base.observers.disable :all
      SiteSetting.provider.all.each do |setting|
        SiteSetting.remove_override!(setting.name)
      end

      # very expensive IO operations
      SiteSetting.automatically_download_gravatars = false

      Discourse.clear_readonly!

      I18n.locale = :en
    end

    class TestCurrentUserProvider < Auth::DefaultCurrentUserProvider
      def log_on_user(user,session,cookies)
        session[:current_user_id] = user.id
        super
      end

      def log_off_user(session,cookies)
        session[:current_user_id] = nil
        super
      end
    end

  end

  def freeze_time(now=Time.now)
    datetime = DateTime.parse(now.to_s)
    time = Time.parse(now.to_s)

    DateTime.stubs(:now).returns(datetime)
    Time.stubs(:now).returns(time)
  end

  def file_from_fixtures(filename)
    FileUtils.mkdir_p("#{Rails.root}/tmp/spec") unless Dir.exists?("#{Rails.root}/tmp/spec")
    FileUtils.cp("#{Rails.root}/spec/fixtures/images/#{filename}", "#{Rails.root}/tmp/spec/#{filename}")
    File.new("#{Rails.root}/tmp/spec/#{filename}")
  end
end

Spork.each_run do
  # This code will be run each time you run your specs.
  Discourse.after_fork
end

# --- Instructions ---
# Sort the contents of this file into a Spork.prefork and a Spork.each_run
# block.
#
# The Spork.prefork block is run only once when the spork server is started.
# You typically want to place most of your (slow) initializer code in here, in
# particular, require'ing any 3rd-party gems that you don't normally modify
# during development.
#
# The Spork.each_run block is run each time you run your specs.  In case you
# need to load files that tend to change during development, require them here.
# With Rails, your application modules are loaded automatically, so sometimes
# this block can remain empty.
#
# Note: You can modify files loaded *from* the Spork.each_run block without
# restarting the spork server.  However, this file itself will not be reloaded,
# so if you change any of the code inside the each_run block, you still need to
# restart the server.  In general, if you have non-trivial code in this file,
# it's advisable to move it into a separate file so you can easily edit it
# without restarting spork.  (For example, with RSpec, you could move
# non-trivial code into a file spec/support/my_helper.rb, making sure that the
# spec/support/* files are require'd from inside the each_run block.)
#
# Any code that is left outside the two blocks will be run during preforking
# *and* during each_run -- that's probably not what you want.
#
# These instructions should self-destruct in 10 seconds.  If they don't, feel
# free to delete them.
