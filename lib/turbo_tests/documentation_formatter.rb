# frozen_string_literal: true

module TurboTests
  # An RSpec formatter that prepends the process id to all messages
  class DocumentationFormatter < ::TurboTests::BaseFormatter
    RSpec::Core::Formatters.register(
      self,
      :example_failed,
      :example_passed,
      :example_pending,
      :start,
      :stop,
    )

    def start(*args)
      super(*args)
      output.puts "::group:: Verbose turbo_spec output" if ENV["GITHUB_ACTIONS"]
    end

    def stop(*args)
      output.puts "::endgroup::" if ENV["GITHUB_ACTIONS"]
    end

    def example_passed(notification)
      output.puts RSpec::Core::Formatters::ConsoleCodes.wrap(
                    output_example(notification.example),
                    :success,
                  )

      output_activerecord_debug_logs(output, notification.example)

      output.flush
    end

    def example_pending(notification)
      message = notification.example.execution_result.pending_message

      output.puts RSpec::Core::Formatters::ConsoleCodes.wrap(
                    "#{output_example(notification.example)} (PENDING: #{message})",
                    :pending,
                  )

      output.flush
    end

    def example_failed(notification)
      output.puts RSpec::Core::Formatters::ConsoleCodes.wrap(
                    "#{output_example(notification.example)} (FAILED - #{next_failure_index})",
                    :failure,
                  )

      output_activerecord_debug_logs(output, notification.example)

      output.flush
    end

    private

    def output_activerecord_debug_logs(output, example)
      if ENV["GITHUB_ACTIONS"] &&
           active_record_debug_logs = example.metadata[:active_record_debug_logs]
        output.puts "::group::ActiveRecord Debug Logs"
        output.puts active_record_debug_logs
        output.puts "::endgroup::"
      end
    end

    def output_example(example)
      output =
        +"[#{example.process_id}] (##{example.metadata[:process_pid]}) #{example.full_description}"

      if run_duration_ms = example.metadata[:run_duration_ms]
        output << " (#{run_duration_ms}ms)"
      end

      output
    end

    def next_failure_index
      @next_failure_index ||= 0
      @next_failure_index += 1
    end
  end
end
