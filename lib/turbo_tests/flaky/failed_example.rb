# frozen_string_literal: true

module TurboTests
  module Flaky
    class FailedExample
      # @param [TurboTests::FakeExample] failed_example
      def initialize(failed_example)
        @failed_example = failed_example
        @failed_example_notification = failed_example.notification
      end

      # See https://www.rubydoc.info/gems/rspec-core/RSpec%2FCore%2FNotifications%2FFailedExampleNotification:message_lines
      def message_lines
        lines = @failed_example_notification.message_lines.join("\n")

        # Strip ANSI color codes from the message lines as we are likely running in a terminal where `RSpec.color` is enabled
        lines.gsub!(/\e\[[0-9;]*m/, "")
        lines.strip!

        lines
      end

      # See https://www.rubydoc.info/gems/rspec-core/RSpec%2FCore%2FNotifications%2FFailedExampleNotification:description
      def description
        @failed_example_notification.description
      end

      # See https://www.rubydoc.info/gems/rspec-core/RSpec%2FCore%2FNotifications%2FFailedExampleNotification:formatted_backtrace
      def backtrace
        @failed_example_notification.formatted_backtrace
      end

      def location_rerun_argument
        @failed_example.location_rerun_argument
      end

      def exception_name
        @failed_example.execution_result.exception.class.name
      end

      def exception_message
        @failed_example.execution_result.exception.message
      end

      SCREENSHOT_PREFIX = "[Screenshot Image]: "

      # Unfortunately this has to be parsed from the output because `ActionDispatch` is just printing the path instead of
      # properly adding the screenshot to the test metadata.
      def failure_screenshot_path
        @failed_example_notification.message_lines.each do |message_line|
          if message_line.strip.start_with?(SCREENSHOT_PREFIX)
            return message_line.split(SCREENSHOT_PREFIX).last.chomp
          end
        end

        nil
      end

      def rerun_command
        @failed_example.command_string
      end

      def to_h
        {
          message_lines:,
          description:,
          exception_message:,
          exception_name:,
          backtrace:,
          failure_screenshot_path:,
          location_rerun_argument:,
          rerun_command:,
        }
      end
    end
  end
end
