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

module Helpers
  def log_in(fabricator=nil)
    user = Fabricate(fabricator || :user)
    log_in_user(user)
    user
  end

  def log_in_user(user)
    session[:current_user_id] = user.id
  end

  def fixture_file(filename)
    return '' if filename == ''
    file_path = File.expand_path(File.dirname(__FILE__) + '/fixtures/' + filename)
    File.read(file_path)
  end
end

Spork.prefork do
  # Loading more in this block will cause your tests to run faster. However,
  # if you change any configuration or code from libraries loaded here, you'll
  # need to restart spork for it take effect.
  ENV["RAILS_ENV"] ||= 'test'
  require File.expand_path("../../config/environment", __FILE__)
  require 'rspec/rails'
  require 'rspec/autorun'

  # Requires supporting ruby files with custom matchers and macros, etc,
  # in spec/support/ and its subdirectories.
  Dir[Rails.root.join("spec/support/**/*.rb")].each {|f| require f}

  # let's not run seed_fu every test
  SeedFu.seed

  RSpec.configure do |config|

    config.fail_fast = ENV['RSPEC_FAIL_FAST'] == "1"
    config.include Helpers
    config.mock_framework = :mocha

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

    config.before(:all) do
      DiscoursePluginRegistry.clear
    end

  end

  class DateTime
    class << self
      alias_method :old_now, :now
      def now
        @now || old_now
      end
      def now=(v)
        @now = v
      end
    end
  end

  def freeze_time(d=nil)
    begin
      d ||= DateTime.now
      DateTime.now = d
      yield
    ensure
      DateTime.now = nil
    end
  end

end

Spork.each_run do
  # This code will be run each time you run your specs.
  $redis.client.reconnect
  MessageBus.reliable_pub_sub.pub_redis.client.reconnect
  Rails.cache.reconnect
end

def build(*args)
  Fabricate.build(*args)
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


