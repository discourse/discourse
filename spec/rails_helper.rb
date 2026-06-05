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

# In CI, neutralize ActiveRecord query log tags + verbose query logs. Both
# enabled in `config/environments/test.rb`, but their output is unreachable
# under `RAILS_TEST_LOG_LEVEL=error`. The compute cost is not: every AR
# query runs the `request_path` / `Thread.current.object_id` lambdas and
# builds an SQL comment, and `verbose_query_logs` walks the Ruby stack via
# caller_locations on every log emit. Override `QueryLogs.comment` to a
# constant nil so the prepended `call(sql, connection)` exits in one branch
# without iterating handlers or touching the execution context.
if ENV["CI"] && !ENV["DISCOURSE_KEEP_AR_QUERY_LOGS"]
  ActiveRecord.verbose_query_logs = false

  if defined?(ActiveRecord::QueryLogs)
    ActiveRecord::QueryLogs.tags = []
    ActiveRecord::QueryLogs.singleton_class.define_method(:comment) { |_connection| nil }
  end

  # Mirror the production-only optimization from config/initializers/300-perf.rb
  # into CI test runs. Every AR query passes through
  # `ActiveSupport::Notifications.instrument("sql.active_record", payload)`.
  # With AR's LogSubscriber attached, that path allocates a notification
  # `Event`, dispatches start/finish across all subscribers, and ends in
  # `ActiveRecord::LogSubscriber#sql` — which immediately exits because
  # `RAILS_TEST_LOG_LEVEL=error` keeps `logger.level` above the subscriber's
  # `:debug` threshold. With no subscribers, the `instrument` call short-
  # circuits via `@notifier.listening?(name)` and just yields the block,
  # skipping the Event allocation and the per-query subscriber lifecycle.
  # `spec/support/helpers.rb#track_sql_queries` uses
  # `Notifications.subscribed { ... }` to attach a transient subscriber for
  # the duration of a block, so query-counting tests still work unchanged.
  ActiveSupport::Notifications.notifier.unsubscribe("sql.active_record")

  # `UpcomingChanges.clear_caches!` is called per spec via `TestSetup.test_setup`
  # (the `config.before :each` hook). The upstream implementation pays three
  # serial Redis round-trips — two `Discourse.cache.delete` calls plus a
  # `Discourse.redis.del` inside `DiscourseUpdates.clear_latest_new_feature_created_at_cache`.
  # Even on a localhost socket each round-trip costs ~50-100us of syscall +
  # protocol overhead, and the keys are almost always already gone (the global
  # `after :each` calls `Discourse.redis.flushdb` at the end of every spec,
  # so the next spec's `test_setup` is DEL'ing nonexistent keys). Collapse
  # the three DELs into a single multi-key DEL so workers pay one round-trip
  # per spec instead of three, with byte-identical post-condition.
  module UpcomingChangesBatchedClearCaches
    def clear_caches!
      Discourse.redis.del(
        Discourse.cache.normalize_key(current_statuses_cache_key),
        Discourse.cache.normalize_key(permanent_upcoming_changes_cache_key),
        DiscourseUpdates.send(:latest_new_feature_created_at_key),
      )
    end
  end
  UpcomingChanges.singleton_class.prepend(UpcomingChangesBatchedClearCaches)
end

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
  config.include TimeHelpers
  config.include AuthHelpers
  config.include LoggingHelpers

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

    WebMock.disable_net_connect!(
      allow_localhost: true,
      allow: [
        *MinioRunner.config.minio_urls,
        URI(MinioRunner::MinioBinary.platform_binary_url).host,
        ENV["CAPYBARA_REMOTE_DRIVER_URL"],
      ].compact,
    )

    # Registering this from inside before(:suite) makes it run at the end of the
    # before(:each) chain. It must run after the specs' `sign_in`, so the auth
    # cookie is made using the correct (current) time.
    config.before(:each, type: :system) do |example|
      if example.metadata[:time]
        freeze_time(example.metadata[:time])
        BrowserTime.freeze(page, example.metadata[:time])
      end
    end

    # Prevents 500 errors for site setting URLs pointing to test.localhost in system specs.
    SiteIconManager.clear_cache!
  end

  config.after(:suite) { Downloads.clear }

  config.before(:each) { TestSetup.test_setup }

  # Match the request hostname to the value in `database.yml`
  config.before(:each, type: %i[request multisite system]) { host! "test.localhost" }

  config.before(:each, type: :system) do |example|
    SystemDrivers.preload_model_schemas!
    SystemDrivers.register!(color_scheme: example.metadata[:color_scheme])
    driven_by SystemDrivers.driver_for(example)

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

  config.before(:each) do |example|
    if example.metadata[:type] != :system
      EmberCli.stubs(:read_manifest!).returns(nil)
      EmberCli.stubs(:script_chunks).returns({})
    end
  end

  config.before(:each, type: :system) { MessageBusTestSync.start }

  config.before(:each, type: :system) do |example|
    EmberDeprecations.set_raise_on_deprecation!(example)
  end

  config.after(:each) do |example|
    if example.exception && RspecErrorTracker.exceptions.present?
      lines = (example.metadata[:extra_failure_lines] ||= +"")
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

    lines = example.metadata[:extra_failure_lines]

    if example.exception &&
         (backtraces = example.metadata[:_capybara_server_threads_backtraces]).present?
      CapybaraTimeoutExtension.append_server_thread_backtraces(lines, backtraces)
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

  # Registered last so that, running in reverse order, it executes before the
  # teardown hook above. `MessageBusTestSync.stop` must come before the timeout
  # re-raise, otherwise the raise would skip it.
  config.after(:each, type: :system) do |example|
    MessageBusTestSync.stop

    # If test passed, but we had a capybara finder timeout, raise it now
    if example.exception.nil? &&
         (capybara_timeout_error = example.metadata[:_capybara_timeout_exception])
      raise capybara_timeout_error
    end
  end
end
