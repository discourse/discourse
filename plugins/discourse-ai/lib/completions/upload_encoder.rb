# frozen_string_literal: true

module DiscourseAi
  module Completions
    class UploadEncoder
      def self.encode(
        upload_ids:,
        max_pixels:,
        allowed_kinds: [:image],
        allowed_attachment_types: nil
      )
        uploads = []
        allowed_attachment_types = normalize_attachment_types(allowed_attachment_types)
        upload_ids.each do |upload_id|
          upload = Upload.find(upload_id)
          next if upload.blank?

          extension = upload.extension&.downcase
          kind = image_extension?(extension) ? :image : :document

          next if allowed_kinds.exclude?(kind)

          if kind == :document
            mime_type =
              MiniMime.lookup_by_filename(upload.original_filename)&.content_type ||
                "application/octet-stream"

            attachment_type = attachment_type_for(upload.extension, mime_type)
            next if disallowed_attachment?(allowed_attachment_types, attachment_type)

            payload = encode_document(upload, mime_type)
            uploads << payload if payload
            next
          end

          next if upload.width.to_i == 0 || upload.height.to_i == 0

          desired_extension = upload.extension
          desired_extension = "png" if upload.extension == "gif"
          desired_extension = "png" if upload.extension == "webp"
          desired_extension = "jpeg" if upload.extension == "jpg"

          # this keeps it very simple format wise given everyone supports png and jpg
          next if !%w[jpeg png].include?(desired_extension)

          payload = encode_image(upload, desired_extension, max_pixels)
          uploads << payload if payload
        end
        uploads
      end

      def self.attachment_type_for(extension, mime_type)
        ext = extension.to_s.delete_prefix(".").downcase
        mime = mime_type.to_s

        return "pdf" if ext == "pdf" || mime.include?("pdf")
        return "docx" if ext == "docx"
        return "doc" if ext == "doc"
        return "txt" if ext == "txt" || mime.include?("text/plain")
        return "rtf" if ext == "rtf"
        return "html" if %w[html htm].include?(ext) || mime.include?("html")
        return "markdown" if %w[md markdown].include?(ext) || mime.include?("markdown")

        "file"
      end

      class << self
        private

        def normalize_attachment_types(types)
          return nil if types.nil?

          Array(types).map(&:downcase)
        end

        def disallowed_attachment?(allowed_types, attachment_type)
          !allowed_types.nil? && !allowed_types.include?(attachment_type)
        end

        def image_extension?(ext)
          %w[jpg jpeg png gif webp].include?(ext)
        end

        def encode_document(upload, mime_type)
          path = fetch_path(upload)
          return if path.blank?

          encoded = Base64.strict_encode64(File.binread(path))

          {
            base64: encoded,
            mime_type: mime_type,
            kind: :document,
            filename: upload.original_filename,
          }
        end

        def encode_image(upload, desired_extension, max_pixels)
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

        def fetch_path(upload)
          path = Discourse.store.path_for(upload)
          if path.blank?
            external_copy = Discourse.store.download_safe(upload)
            path = external_copy&.path
          end
          if path.blank?
            external_copy = Discourse.store.download(upload)
            path = external_copy&.path
          end

          return if path.blank?
          return unless File.exist?(path)

          path
        end
      end
    end
  end
end
