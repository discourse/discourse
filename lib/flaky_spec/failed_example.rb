# frozen_string_literal: true

module FlakySpec
  class FailedExample
    # @param [RSpec::Core::Example] rspec_example
    def initialize(rspec_example)
      # The exception has not been set on the `execution_result` at this point, so we have to set it manually for
      # `RSpec::Core::Notifications::FailedExampleNotification` to work properly.
      rspec_example.execution_result.exception = rspec_example.exception

      @rspec_failed_notification =
        RSpec::Core::Notifications::FailedExampleNotification.new(rspec_example)
    end

    # See https://www.rubydoc.info/gems/rspec-core/RSpec%2FCore%2FNotifications%2FFailedExampleNotification:message_lines
    def message_lines
      lines = @rspec_failed_notification.message_lines.join("\n")

      # Strip ANSI color codes from the message lines as we are likely running in a terminal where `RSpec.color` is enabled
      lines = lines.gsub!(/\e\[[0-9;]*m/, "").strip

      lines
    end

    # See https://www.rubydoc.info/gems/rspec-core/RSpec%2FCore%2FNotifications%2FFailedExampleNotification:description
    def description
      @rspec_failed_notification.description
    end

    # See https://www.rubydoc.info/gems/rspec-core/RSpec%2FCore%2FNotifications%2FFailedExampleNotification:formatted_backtrace
    def backtrace
      @rspec_failed_notification.formatted_backtrace
    end

    SCREENSHOT_PREFIX = "[Screenshot Image]: "

    # Unfortunately this has to be parsed from the output because `ActionDispatch` is just printing the path instead of
    # properly adding the screenshot to the test metadata.
    def failure_screenshot_path
      @rspec_failed_notification.message_lines.each do |message_line|
        if message_line.start_with?(SCREENSHOT_PREFIX)
          return message_line.split(SCREENSHOT_PREFIX).last.chomp
        end
      end

      nil
    end

    def to_h
      { message_lines:, description:, backtrace:, failure_screenshot_path: }
    end
  end
end
