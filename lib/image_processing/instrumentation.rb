# frozen_string_literal: true

module ImageProcessing
  class Instrumentation
    def self.instrument(operation:, timeout_seconds:)
      validate_operation!(operation)
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      error = nil

      begin
        yield
      rescue StandardError => caught_error
        error = caught_error
        raise
      ensure
        duration_seconds = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
        record(operation:, duration_seconds:, error:, timeout_seconds:)
      end
    end

    def self.record(operation:, duration_seconds:, error:, timeout_seconds:)
      result = error ? classify(error, duration_seconds:, timeout_seconds:) : "success"
      DiscourseEvent.trigger(
        :image_processing_finished,
        { operation: operation.to_s, duration_seconds:, result: },
        continue_on_error: true,
      )
    end
    private_class_method :record

    def self.classify(error, duration_seconds:, timeout_seconds:)
      return "exception" if !error.is_a?(Discourse::Utils::CommandError)

      status = error.status
      if status&.signaled?
        return "cpu_limit" if status.termsig == Signal.list["XCPU"]
        return "file_size_limit" if status.termsig == Signal.list["XFSZ"]
      end

      return "wall_timeout" if timeout_seconds && duration_seconds >= timeout_seconds

      return "signal" if status&.signaled?
      return "nonzero_exit" if status&.exited?

      "exception"
    end
    private_class_method :classify

    def self.validate_operation!(operation)
      raise ArgumentError, "operation must be a Symbol" if !operation.is_a?(Symbol)
    end
    private_class_method :validate_operation!
  end
end
