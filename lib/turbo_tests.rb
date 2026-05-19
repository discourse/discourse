# frozen_string_literal: true

require "bundler/setup"

require "open3"
require "fileutils"
require "json"
require "rspec"

# Without booting the full Rails app, Zeitwerk autoloading is unavailable in
# the master process, so each `TurboTests` file must be required explicitly.
# A handful of `ActiveSupport` core extensions (`blank?`, `present?`,
# `symbolize_keys`) used by the formatters and runner are pulled in directly
# rather than via the full `active_support/all` require.
require "active_support"
require "active_support/core_ext/object/blank"
require "active_support/core_ext/hash/keys"

require "parallel_tests"
require "parallel_tests/rspec/runner"

require "./lib/turbo_tests/reporter"
require "./lib/turbo_tests/json_example"
require "./lib/turbo_tests/base_formatter"
require "./lib/turbo_tests/progress_formatter"
require "./lib/turbo_tests/documentation_formatter"
require "./lib/turbo_tests/json_rows_formatter"
require "./lib/turbo_tests/flaky/manager"
require "./lib/turbo_tests/flaky/failed_example"
require "./lib/turbo_tests/flaky/failures_logger_formatter"
require "./lib/turbo_tests/flaky/flaky_detector_formatter"
require "./lib/turbo_tests/runner"

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
        obj = obj.symbolize_keys

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
      obj = obj.symbolize_keys
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
      obj = obj.symbolize_keys
      metadata = obj[:metadata].symbolize_keys

      metadata[:shared_group_inclusion_backtrace].map! do |frame|
        frame = frame.symbolize_keys
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
