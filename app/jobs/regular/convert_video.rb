# frozen_string_literal: true
module Jobs
  class ConvertVideo < ::Jobs::Base
    sidekiq_options queue: "low", concurrency: 5
    MAX_RETRIES = 5
    RETRY_DELAY = 30.seconds

    def execute(args)
      return if args[:upload_id].blank?

      upload = Upload.find_by(id: args[:upload_id])
      return if upload.blank?

      return if OptimizedVideo.exists?(upload_id: upload.id)

      if upload.url.blank?
        retry_count = args[:retry_count].to_i
        if retry_count < MAX_RETRIES
          Jobs.enqueue_in(RETRY_DELAY, :convert_video, args.merge(retry_count: retry_count + 1))
          return
        else
          Rails.logger.error(
            "Upload #{upload.id} URL remained blank after #{MAX_RETRIES} retries when optimizing video",
          )
          return
        end
      end

      adapter = VideoConversion::AdapterFactory.get_adapter(upload)

      Rails.logger.error("Video conversion failed for upload #{upload.id}") if !adapter.convert
    end
  end
end
