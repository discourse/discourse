# frozen_string_literal: true

module DiscourseAi
  module Completions
    class UploadEncoder
      extend UploadEncoding

      def self.image_upload?(upload)
        mime_type = MiniMime.lookup_by_filename(upload.original_filename)&.content_type
        mime_type&.start_with?("image/") == true
      end

      def self.supported_image_upload?(upload)
        image_upload?(upload) && %w[jpg jpeg png gif webp].include?(upload.extension&.downcase)
      end

      def self.encode(
        upload_ids:,
        max_pixels:,
        allowed_kinds: [:image],
        allowed_attachment_types: nil
      )
        allowed_attachment_types = normalize_attachment_types(allowed_attachment_types)
        uploads_by_id = Upload.where(id: upload_ids).index_by(&:id)

        upload_ids.filter_map do |upload_id|
          upload = uploads_by_id[upload_id]
          next if upload.blank?

          extension = upload.extension&.downcase
          kind = image_extension?(extension) ? :image : :document

          next if allowed_kinds.exclude?(kind)

          if kind == :document
            mime_type =
              MiniMime.lookup_by_filename(upload.original_filename)&.content_type ||
                "application/octet-stream"

            attachment_type = DocumentEncoder.attachment_type_for(upload.extension, mime_type)
            next if allowed_attachment_types&.exclude?(attachment_type)

            next DocumentEncoder.encode(upload, mime_type, attachment_type)
          end

          next if upload.width.to_i == 0 || upload.height.to_i == 0

          desired_extension = upload.extension
          desired_extension = "png" if upload.extension == "gif"
          desired_extension = "png" if upload.extension == "webp"
          desired_extension = "jpeg" if upload.extension == "jpg"

          # this keeps it very simple format wise given everyone supports png and jpg
          next if !%w[jpeg png].include?(desired_extension)

          encode_image(upload, desired_extension, max_pixels)
        end
      end

      class << self
        private

        def normalize_attachment_types(types)
          return nil if types.nil?

          LlmModel.normalize_attachment_types(types)
        end

        def image_extension?(ext)
          %w[jpg jpeg png gif webp].include?(ext)
        end

        def encode_image(upload, desired_extension, max_pixels)
          original_pixels = upload.width * upload.height

          image = upload

          if original_pixels > max_pixels
            ratio = Math.sqrt(max_pixels.to_f / original_pixels)

            new_width = (ratio * upload.width).to_i
            new_height = (ratio * upload.height).to_i

            image = upload.get_optimized_image(new_width, new_height, format: desired_extension)
          elsif upload.extension != desired_extension
            image =
              upload.get_optimized_image(upload.width, upload.height, format: desired_extension)
          end

          return if !image

          mime_type = MiniMime.lookup_by_filename("test.#{desired_extension}").content_type

          path = fetch_path(image)
          return if path.blank?

          encoded = Base64.strict_encode64(File.binread(path))

          {
            base64: encoded,
            mime_type: mime_type,
            kind: :image,
            filename: upload.original_filename,
          }
        end
      end
    end
  end
end
