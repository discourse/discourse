# frozen_string_literal: true

module ImageProcessing
  class Instrumentation
    class << self
      def instrument(operation:)
        return yield if !SiteSetting.instrument_image_processing

        validate_operation!(operation)
        started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        success = false

        begin
          result = yield
          success = true
          result
        ensure
          duration_seconds = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
          record(operation:, duration_seconds:, success:)
        end
      end

      def record(operation:, duration_seconds:, success:)
        DiscourseEvent.trigger(
          :image_processing_finished,
          { operation: operation.to_s, duration_seconds:, success: },
          continue_on_error: true,
        )
      end
    end
    private_class_method :record

    class << self
      def validate_operation!(operation)
        raise ArgumentError, "operation must be a Symbol" if !operation.is_a?(Symbol)
      end
    end
    private_class_method :validate_operation!
  end
end
