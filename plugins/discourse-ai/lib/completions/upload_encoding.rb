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
    end
  end
end
