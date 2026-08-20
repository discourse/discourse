# frozen_string_literal: true

module ImageProcessing
  class Instrumentation
    def self.record(operation:, result:)
      success, error_reason = classify(result)
      resource_usage = result.resource_usage

      DiscourseEvent.trigger(
        :image_processing_finished,
        {
          operation: operation.to_s,
          success:,
          error_reason:,
          duration_seconds: result.elapsed_seconds,
          cpu_seconds: resource_usage.cpu_seconds,
          max_rss_bytes: resource_usage.max_rss_bytes,
        },
        continue_on_error: true,
      )
    end

    def self.classify(result)
      return false, "wall_timeout" if result.timed_out?
      return false, "output_limit" if result.output_truncated?

      status = result.status
      if status.signaled?
        return false, "cpu_limit" if status.termsig == Signal.list["XCPU"]
        return false, "file_size_limit" if status.termsig == Signal.list["XFSZ"]

        return false, "signal"
      end

      return true, "none" if status.exited? && status.exitstatus.zero?

      [false, "nonzero_exit"]
    end
    private_class_method :classify
  end
end
