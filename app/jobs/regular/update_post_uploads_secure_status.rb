# frozen_string_literal: true

module Jobs
  class UpdatePostUploadsSecureStatus < ::Jobs::Base
    def execute(args)
      post = Post.find_by(id: args[:post_id])
      return if post.blank?

      post.uploads.each { |upload| upload.update_secure_status(source: args[:source]) }
    end
  end
end
