# frozen_string_literal: true
module Jobs
  class CheckVideoConversionStatus < ::Jobs::Base
    sidekiq_options queue: "low", concurrency: 5

    def execute(args)
      return if args[:upload_id].blank? || args[:job_id].blank? || args[:adapter_type].blank?

      upload = Upload.find_by(id: args[:upload_id])
      return unless upload

      adapter =
        VideoConversion::AdapterFactory.get_adapter(upload, adapter_type: args[:adapter_type])

      status = adapter.check_status(args[:job_id])

      case status
      when :complete
        if adapter.handle_completion(args[:job_id], args[:output_path], args[:new_sha1])
          # Successfully completed
          nil
        else
          # Handle completion failed
          Rails.logger.error("Failed to handle video conversion completion")
          nil
        end
      when :error
        Rails.logger.error("Video conversion job failed")
        nil
      when :pending
        # Re-enqueue the job to check again
        Jobs.enqueue_in(30.seconds, :check_video_conversion_status, args)
      end
    end
  end
end
