# frozen_string_literal: true

require 'bundler/setup'

require 'open3'
require 'fileutils'
require 'json'
require 'rspec'
require 'rails'
require File.expand_path('../../config/environment', __FILE__)

require 'parallel_tests'
require 'parallel_tests/rspec/runner'

require './lib/turbo_tests/reporter'
require './lib/turbo_tests/runner'
require './lib/turbo_tests/json_rows_formatter'

module TurboTests
  FakeException = Struct.new(:backtrace, :message, :cause)
  class FakeException
    def self.from_obj(obj)
      if obj
        obj = obj.symbolize_keys

        klass =
          Class.new(FakeException) do
            define_singleton_method(:name) do
              obj[:class_name]
            end
          end

        klass.new(
          obj[:backtrace],
          obj[:message],
          FakeException.from_obj(obj[:cause])
        )
      end
    end
  end

  FakeExecutionResult = Struct.new(:example_skipped?, :pending_message, :status, :pending_fixed?, :exception, :pending_exception)
  class FakeExecutionResult
    def self.from_obj(obj)
      obj = obj.symbolize_keys
      new(
        obj[:example_skipped?],
        obj[:pending_message],
        obj[:status].to_sym,
        obj[:pending_fixed?],
        FakeException.from_obj(obj[:exception]),
        FakeException.from_obj(obj[:pending_exception])
      )
    end
  end

  FakeExample = Struct.new(:execution_result, :location, :full_description, :metadata, :location_rerun_argument)
  class FakeExample
    def self.from_obj(obj)
      obj = obj.symbolize_keys
      metadata =
        obj[:metadata].symbolize_keys

      metadata[:shared_group_inclusion_backtrace]
        .map! { |frame|
          frame = frame.symbolize_keys
          RSpec::Core::SharedExampleGroupInclusionStackFrame.new(
            frame[:shared_group_name],
            frame[:inclusion_location]
          )
        }

      new(
        FakeExecutionResult.from_obj(obj[:execution_result]),
        obj[:location],
        obj[:full_description],
        metadata,
        obj[:location_rerun_argument],
      )
    end

    def notification
      RSpec::Core::Notifications::ExampleNotification.for(
        self
      )
    end
  end
end
