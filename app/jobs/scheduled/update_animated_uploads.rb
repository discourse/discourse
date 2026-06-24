# frozen_string_literal: true

module Jobs
  class UpdateAnimatedUploads < ::Jobs::Scheduled
    every 1.hour

    MAX_PROCESSED_GIF_IMAGES = 200

    def execute(args)
      Upload
        .where("extension = 'gif' OR (extension IS NULL AND original_filename LIKE '%.gif')")
        .where(animated: nil)
        .limit(MAX_PROCESSED_GIF_IMAGES)
        .each do |upload|
          path = Discourse.store.path_for(upload)
          upload.animated =
            begin
              if path
                DiscourseImage.animated?(path, filename: upload.original_filename || "image.gif")
              else
                url = upload.url
                url = "#{SiteSetting.scheme}:#{url}" if url&.start_with?("//")
                SafeImage.remote_animated?(
                  url,
                  max_bytes: SiteSetting.max_image_size_kb.kilobytes,
                  total_timeout: 30,
                  max_pixels: nil,
                )
              end
            rescue SafeImage::Error, ArgumentError, URI::Error
              false
            end
          upload.save(validate: false)
          upload.optimized_images.destroy_all if upload.animated
        end

      nil
    end
  end
end
