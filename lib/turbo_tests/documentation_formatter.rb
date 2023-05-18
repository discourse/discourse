# frozen_string_literal: true

RSpec::Support.require_rspec_core "formatters/base_text_formatter"

module TurboTests
  # An RSpec formatter that prepends the process id to all messages
  class DocumentationFormatter < RSpec::Core::Formatters::BaseTextFormatter
    RSpec::Core::Formatters.register(self, :example_failed, :example_passed, :example_pending)

    def example_passed(notification)
      output.puts RSpec::Core::Formatters::ConsoleCodes.wrap(
                    "[#{notification.example.process_id}] #{notification.example.full_description}",
                    :success,
                  )
      output.flush
    end

    def example_pending(notification)
      message = notification.example.execution_result.pending_message
      output.puts RSpec::Core::Formatters::ConsoleCodes.wrap(
                    "[#{notification.example.process_id}] #{notification.example.full_description}" \
                      " (PENDING: #{message})",
                    :pending,
                  )
      output.flush
    end

    def example_failed(notification)
      output.puts RSpec::Core::Formatters::ConsoleCodes.wrap(
                    "[#{notification.example.process_id}] #{notification.example.full_description}" \
                      " (FAILED - #{next_failure_index})",
                    :failure,
                  )
      output.flush
    end

    private

    def next_failure_index
      @next_failure_index ||= 0
      @next_failure_index += 1
    end
  end
end
