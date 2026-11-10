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
          path = upload.local? ? Discourse.store.path_for(upload) : Discourse.store.download(upload)
          upload.animated = path && FastImage.animated?(path)
          upload.save(validate: false)
          upload.optimized_images.destroy_all if upload.animated
        end

      nil
    end
  end
end
