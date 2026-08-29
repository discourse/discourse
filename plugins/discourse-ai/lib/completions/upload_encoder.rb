# frozen_string_literal: true

module DiscourseAi
  module Completions
    class UploadEncoder
      extend UploadEncoding

      JPEG_EXTENSIONS = %w[jpg jpeg].freeze
      SUPPORTED_IMAGE_EXTENSIONS = (JPEG_EXTENSIONS + %w[png gif webp avif]).freeze

      def self.supported_image_upload?(upload)
        image_extension?(upload.extension&.downcase)
      end

      def self.image?(upload)
        extension = upload.extension.to_s.delete_prefix(".").downcase
        return true if FileHelper.supported_images.include?(extension)

        filename = upload.original_filename.to_s
        filename = "upload.#{extension}" if File.extname(filename).blank? && extension.present?

        MiniMime.lookup_by_filename(filename)&.content_type.to_s.start_with?("image/")
      end

      def self.encode(
        upload_ids:,
        max_pixels:,
        allowed_kinds: [:image],
        allowed_attachment_types: nil,
        skips: nil
      )
        allowed_attachment_types = normalize_attachment_types(allowed_attachment_types)
        skips ||= []
        uploads_by_id = Upload.where(id: upload_ids).index_by(&:id)

        upload_ids.filter_map do |upload_id|
          upload = uploads_by_id[upload_id]
          next if upload.blank?

          extension = upload.extension&.downcase
          kind = image_extension?(extension) ? :image : :document

          if kind == :document && image?(upload)
            log_image_upload_skip(
              skips,
              upload,
              "unsupported image format, supported formats are: #{SUPPORTED_IMAGE_EXTENSIONS.join(", ")}",
            )
            next
          end

          next if allowed_kinds.exclude?(kind)

          if kind == :document
            mime_type =
              MiniMime.lookup_by_filename(upload.original_filename)&.content_type ||
                "application/octet-stream"

            attachment_type = DocumentEncoder.attachment_type_for(upload.extension, mime_type)
            next if allowed_attachment_types&.exclude?(attachment_type)

            next DocumentEncoder.encode(upload, mime_type, attachment_type, skips)
          end

          if upload.width.to_i == 0 || upload.height.to_i == 0
            log_image_upload_skip(skips, upload, "image dimensions are unknown")
            next
          end

          encode_image(upload, transcode_format(extension), max_pixels, skips)
        end
      end

      class << self
        private

        def normalize_attachment_types(types)
          return nil if types.nil?

          LlmModel.normalize_attachment_types(types)
        end

        def image_extension?(ext)
          SUPPORTED_IMAGE_EXTENSIONS.include?(ext)
        end

        def transcode_format(extension)
          JPEG_EXTENSIONS.include?(extension) ? "jpeg" : "png"
        end

        def log_image_upload_skip(skips, upload, message)
          record_skip(skips, upload, message)

          Rails.logger.warn(
            "Discourse AI: Skipping image upload " \
              "(upload_id=#{upload.id}, filename=#{upload.original_filename.inspect}): #{message}",
          )
        end

        def encode_image(upload, desired_extension, max_pixels, skips)
          original_pixels = upload.width * upload.height

          image = upload

          if original_pixels > max_pixels
            ratio = Math.sqrt(max_pixels.to_f / original_pixels)

            new_width = (ratio * upload.width).to_i
            new_height = (ratio * upload.height).to_i

            image = upload.get_optimized_image(new_width, new_height, format: desired_extension)
          elsif upload.extension&.downcase != desired_extension
            image =
              upload.get_optimized_image(upload.width, upload.height, format: desired_extension)
          end

          if !image
            log_image_upload_skip(skips, upload, "could not be converted to #{desired_extension}")
            return
          end

          mime_type = MiniMime.lookup_by_filename("test.#{desired_extension}").content_type

          path = fetch_path(image)

          if path.blank?
            log_image_upload_skip(skips, upload, "file is not available in the store")
            return
          end

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
