# frozen_string_literal: true

module TurboTests
  class JsonExample
    def initialize(rspec_example)
      @rspec_example = rspec_example
    end

    def to_json
      {
        execution_result: execution_result_to_json(@rspec_example.execution_result),
        location: @rspec_example.location,
        full_description: @rspec_example.full_description,
        metadata: {
          shared_group_inclusion_backtrace:
            @rspec_example.metadata[:shared_group_inclusion_backtrace].map(
              &method(:stack_frame_to_json)
            ),
          extra_failure_lines: @rspec_example.metadata[:extra_failure_lines],
          run_duration_ms: @rspec_example.metadata[:run_duration_ms],
          process_pid: Process.pid,
          js_deprecations: @rspec_example.metadata[:js_deprecations],
          active_record_debug_logs: @rspec_example.metadata[:active_record_debug_logs],
        },
        location_rerun_argument: @rspec_example.location_rerun_argument,
      }
    end

    private

    def stack_frame_to_json(frame)
      { shared_group_name: frame.shared_group_name, inclusion_location: frame.inclusion_location }
    end

    def exception_to_json(exception)
      if exception
        {
          class_name: exception.class.name.to_s,
          backtrace: exception.backtrace,
          message: exception.message,
          cause: exception_to_json(exception.cause),
        }
      end
    end

    def execution_result_to_json(result)
      {
        example_skipped?: result.example_skipped?,
        pending_message: result.pending_message,
        status: result.status,
        pending_fixed?: result.pending_fixed?,
        exception: exception_to_json(result.exception),
        pending_exception: exception_to_json(result.pending_exception),
      }
    end
  end
end
