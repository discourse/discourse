# frozen_string_literal: true

module ImageProcessing
  class Instrumentation
    OPERATIONS = %i[
      upload_svg_dimensions
      upload_dominant_color
      upload_quality_probe
      upload_format_conversion
      upload_auto_orient
      upload_animation_probe
      optimized_image_resize
      optimized_image_crop
      optimized_image_downsize
      topic_og_asset_render
      topic_og_render
      letter_avatar_render
      letter_avatar_version
      letter_avatar_font_list
    ].freeze
    private_constant :OPERATIONS

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
      DiscourseEvent.trigger(
        :image_processing_finished,
        {
          operation: operation.to_s,
          duration_seconds:,
          success: error.nil?,
          error_reason: error && classify(error, duration_seconds:, timeout_seconds:),
        },
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
      if !OPERATIONS.include?(operation)
        raise ArgumentError, "unknown image-processing operation: #{operation.inspect}"
      end
    end
    private_class_method :validate_operation!
  end
end
