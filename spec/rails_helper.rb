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

require_relative "support/server_error_tracking"

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

    config.before(:each) do |example|
      if example.metadata[:type] != :system
        EmberCli.stubs(:read_manifest!).returns(nil)
        EmberCli.stubs(:script_chunks).returns({})
      end
    end

    config.before(:each, type: :system) { MessageBusTestSync.start }
    config.after(:each, type: :system) { MessageBusTestSync.stop }

    config.before(:each, type: :system) do |example|
      EmberDeprecations.set_raise_on_deprecation!(example)

      if example.metadata[:time]
        freeze_time(example.metadata[:time])
        BrowserTime.freeze(page, example.metadata[:time])
      end
    end

    config.after(:each, type: :system) do |example|
      # If test passed, but we had a capybara finder timeout, raise it now
      if example.exception.nil? &&
           (capybara_timeout_error = example.metadata[:_capybara_timeout_exception])
        raise capybara_timeout_error
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

    SystemDrivers.register!(color_scheme: example.metadata[:color_scheme])

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

    SystemArtifacts.record_video(example)
    SystemArtifacts.start_trace(page, example)

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
    SystemArtifacts.stop_trace(page, example)

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
    if ENV["PLAYWRIGHT_DISABLE_VERBOSE_JS_LOGS"].blank? && $playwright_logger && example.exception
      $playwright_logger.append_failure_logs(lines)
    end

    deprecation_error = EmberDeprecations.fatal_error($playwright_logger&.logs)
    expect(deprecation_error).to be_nil, deprecation_error

    EmberDeprecations.record_counts($playwright_logger&.logs, example.metadata)

    page.execute_script("if (typeof MessageBus !== 'undefined') { MessageBus.stop(); }")

    # Block all incoming requests before resetting Capybara session which will wait for all requests to finish
    BlockRequestsMiddleware.block_requests!

    Capybara.reset_session!
    MessageBus.backend_instance.reset! # Clears all existing backlog from memory backend
  end
end

def has_trigger?(trigger_name)
  DB.exec(<<~SQL) != 0
    SELECT 1
    FROM INFORMATION_SCHEMA.TRIGGERS
    WHERE trigger_name = '#{trigger_name}'
  SQL
end
