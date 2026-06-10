# frozen_string_literal: true

require "bundler/setup"

require "open3"
require "fileutils"
require "json"
require "rspec"

require "parallel_tests"
require "parallel_tests/rspec/runner"

# Used by the formatter / flaky-test paths in lieu of `Rails.root` so the
# parent process can format reporter output without booting the Rails app.
TURBO_TESTS_REPO_ROOT = File.expand_path("..", __dir__)

module TurboTests
  # Boot the Discourse Rails application from inside the parent process.
  # Only the parent's migration check actually needs Rails; everything else
  # in `bin/turbo_rspec`'s code path runs on stdlib + rspec + parallel_tests
  # alone. Calling this is a no-op once Rails has been loaded.
  def self.load_rails_app!
    return if @rails_app_loaded
    require "rails"
    require File.expand_path("../config/environment", __dir__)
    @rails_app_loaded = true
  end
end

# Explicit requires for files that were previously picked up via Rails'
# `lib/` autoload. The parent does not load Rails by default, so autoload
# is unavailable; in workers Rails is loaded later and autoload is a no-op
# for already-defined constants.
require "./lib/turbo_tests/base_formatter"
require "./lib/turbo_tests/reporter"
require "./lib/turbo_tests/runner"
require "./lib/turbo_tests/json_example"
require "./lib/turbo_tests/json_rows_formatter"
require "./lib/turbo_tests/documentation_formatter"
require "./lib/turbo_tests/progress_formatter"
require "./lib/turbo_tests/flaky/failed_example"
require "./lib/turbo_tests/flaky/manager"
require "./lib/turbo_tests/flaky/failures_logger_formatter"
require "./lib/turbo_tests/flaky/flaky_detector_formatter"

RSpec.configure do |config|
  # this is an unusual config option because it is used by the formatter, not just the runner
  config.full_cause_backtrace = true
end

module TurboTests
  class FakeException < Exception
    attr_reader :backtrace, :message, :cause

    def initialize(backtrace, message, cause)
      @backtrace = backtrace
      @message = message
      @cause = cause
    end

    def self.from_obj(obj)
      if obj
        obj = obj.transform_keys(&:to_sym)

        klass = Class.new(FakeException) { define_singleton_method(:name) { obj[:class_name] } }

        klass.new(obj[:backtrace], obj[:message], FakeException.from_obj(obj[:cause]))
      end
    end
  end

  FakeExecutionResult =
    Struct.new(
      :example_skipped?,
      :pending_message,
      :status,
      :pending_fixed?,
      :exception,
      :pending_exception,
    )
  class FakeExecutionResult
    def self.from_obj(obj)
      obj = obj.transform_keys(&:to_sym)
      new(
        obj[:example_skipped?],
        obj[:pending_message],
        obj[:status].to_sym,
        obj[:pending_fixed?],
        FakeException.from_obj(obj[:exception]),
        FakeException.from_obj(obj[:pending_exception]),
      )
    end
  end

  FakeExample =
    Struct.new(
      :execution_result,
      :location,
      :description,
      :full_description,
      :metadata,
      :location_rerun_argument,
      :process_id,
      :command_string,
    )

  class FakeExample
    def self.from_obj(obj, process_id:, command_string:)
      obj = obj.transform_keys(&:to_sym)
      metadata = obj[:metadata].transform_keys(&:to_sym)

      metadata[:shared_group_inclusion_backtrace].map! do |frame|
        frame = frame.transform_keys(&:to_sym)
        RSpec::Core::SharedExampleGroupInclusionStackFrame.new(
          frame[:shared_group_name],
          frame[:inclusion_location],
        )
      end

      new(
        FakeExecutionResult.from_obj(obj[:execution_result]),
        obj[:location],
        obj[:description],
        obj[:full_description],
        metadata,
        obj[:location_rerun_argument],
        process_id,
        command_string,
      )
    end

    def notification
      RSpec::Core::Notifications::ExampleNotification.for(self)
    end
  end
end
