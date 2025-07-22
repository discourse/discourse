# frozen_string_literal: true

module DiscourseAi
  module Completions
    class UploadEncoder
      def self.encode(upload_ids:, max_pixels:)
        uploads = []
        upload_ids.each do |upload_id|
          upload = Upload.find(upload_id)
          next if upload.blank?
          next if upload.width.to_i == 0 || upload.height.to_i == 0

          desired_extension = upload.extension
          desired_extension = "png" if upload.extension == "gif"
          desired_extension = "png" if upload.extension == "webp"
          desired_extension = "jpeg" if upload.extension == "jpg"

          # this keeps it very simple format wise given everyone supports png and jpg
          next if !%w[jpeg png].include?(desired_extension)

          original_pixels = upload.width * upload.height

          image = upload

          if original_pixels > max_pixels
            ratio = max_pixels.to_f / original_pixels

            new_width = (ratio * upload.width).to_i
            new_height = (ratio * upload.height).to_i

            image = upload.get_optimized_image(new_width, new_height, format: desired_extension)
          elsif upload.extension != desired_extension
            image =
              upload.get_optimized_image(upload.width, upload.height, format: desired_extension)
          end

          next if !image

          mime_type = MiniMime.lookup_by_filename("test.#{desired_extension}").content_type

          path = Discourse.store.path_for(image)
          if path.blank?
            # download is protected with a DistributedMutex
            external_copy = Discourse.store.download_safe(image)
            path = external_copy&.path
          end

          encoded = Base64.strict_encode64(File.read(path))

          uploads << { base64: encoded, mime_type: mime_type }
        end
        uploads
      end
    end
  end
end
