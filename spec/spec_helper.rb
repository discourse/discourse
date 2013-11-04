if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start
end

require 'rubygems'
require 'spork'
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
  require 'rspec/autorun'
  require 'shoulda'

  # Requires supporting ruby files with custom matchers and macros, etc,
  # in spec/support/ and its subdirectories.
  Dir[Rails.root.join("spec/support/**/*.rb")].each {|f| require f}

  # let's not run seed_fu every test
  SeedFu.quiet = true if SeedFu.respond_to? :quiet
  SeedFu.seed

  RSpec.configure do |config|
    config.fail_fast = ENV['RSPEC_FAIL_FAST'] == "1"
    config.include Helpers
    config.include MessageBus
    config.mock_framework = :mocha
    config.order = 'random'

    # If you're not using ActiveRecord, or you'd prefer not to run each of your
    # examples within a transaction, remove the following line or assign false
    # instead of true.
    config.use_transactional_fixtures = true

    # If true, the base class of anonymous controllers will be inferred
    # automatically. This will be the default behavior in future versions of
    # rspec-rails.
    config.infer_base_class_for_anonymous_controllers = true

    # if we need stuff post fork, pre tests run here
    # config.before(:suite) do
    # end

    config.before do
      # disable all observers, enable as needed during specs
      ActiveRecord::Base.observers.disable :all
      SiteSetting.provider.all.each do |setting|
        SiteSetting.remove_override!(setting.name)
      end
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

    config.before(:all) do
      DiscoursePluginRegistry.clear
      Discourse.current_user_provider = TestCurrentUserProvider

      # a bit odd, but this setting is actually preloaded
      SiteSetting.defaults[:uncategorized_category_id] = SiteSetting.uncategorized_category_id

      require_dependency 'site_settings/local_process_provider'
      SiteSetting.provider = SiteSettings::LocalProcessProvider.new
    end

  end

  def freeze_time(now=Time.now)
    DateTime.stubs(:now).returns(DateTime.parse(now.to_s))
    Time.stubs(:now).returns(Time.parse(now.to_s))
  end

end

Spork.each_run do
  # This code will be run each time you run your specs.
  $redis.client.reconnect
  Rails.cache.reconnect
  MessageBus.after_fork
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
