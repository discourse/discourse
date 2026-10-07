# frozen_string_literal: true

module DiscourseAi
  module Completions
    # plumbing shared by the image and document halves of UploadEncoder
    module UploadEncoding
      def fetch_path(upload)
        path = Discourse.store.path_for(upload)
        path = Discourse.store.download(upload) if path.blank?

        return if path.blank?
        return unless File.exist?(path)

        path
      end

      def record_skip(skips, upload_id:, filename:, message:)
        return if skips.nil?
        return if skips.any? { |skip| skip[:upload_id] == upload_id }

        skips << { upload_id: upload_id, filename: filename, message: message }
      end

      def record_upload_skip(skips, upload, message)
        record_skip(
          skips,
          upload_id: upload.id,
          filename: upload.original_filename,
          message: message,
        )
      end
    end
  end
end
