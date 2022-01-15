# frozen_string_literal: true

module TurboTests
  # An RSpec formatter used for each subprocess during parallel test execution
  class JsonRowsFormatter
    RSpec::Core::Formatters.register(
      self,
      :close,
      :example_failed,
      :example_passed,
      :example_pending,
      :message,
      :seed
    )

    attr_reader :output

    def initialize(output)
      @output = output
    end

    def exception_to_json(exception)
      if exception
        {
          class_name: exception.class.name.to_s,
          backtrace: exception.backtrace,
          message: exception.message,
          cause: exception_to_json(exception.cause)
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

    def stack_frame_to_json(frame)
      {
        shared_group_name: frame.shared_group_name,
        inclusion_location: frame.inclusion_location
      }
    end

    def example_to_json(example)
      {
        execution_result: execution_result_to_json(example.execution_result),
        location: example.location,
        full_description: example.full_description,
        metadata: {
          shared_group_inclusion_backtrace:
            example
              .metadata[:shared_group_inclusion_backtrace]
              .map(&method(:stack_frame_to_json))
        },
        location_rerun_argument: example.location_rerun_argument
      }
    end

    def example_passed(notification)
      output_row(
        type: :example_passed,
        example: example_to_json(notification.example)
      )
    end

    def example_pending(notification)
      output_row(
        type: :example_pending,
        example: example_to_json(notification.example)
      )
    end

    def example_failed(notification)
      output_row(
        type: :example_failed,
        example: example_to_json(notification.example)
      )
    end

    def seed(notification)
      output_row(
        type: :seed,
        seed: notification.seed,
      )
    end

    def close(notification)
      output_row(
        type: :close,
      )
    end

    def message(notification)
      output_row(
        type: :message,
        message: notification.message
      )
    end

    private

    def output_row(obj)
      output.puts(obj.to_json)
      output.flush
    end
  end
end
