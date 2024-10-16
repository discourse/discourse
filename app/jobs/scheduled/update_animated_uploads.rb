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
          uri = Discourse.store.path_for(upload) || upload.url
          upload.animated = FastImage.animated?(uri)
          upload.save(validate: false)
          upload.optimized_images.destroy_all if upload.animated
        end

      nil
    end
  end
end
