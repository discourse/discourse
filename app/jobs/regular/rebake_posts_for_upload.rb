# frozen_string_literal: true

module Jobs
  class RebakePostsForUpload < ::Jobs::Base
    def execute(args)
      upload = Upload.find_by(id: args[:id])
      return if upload.blank?
      upload.posts.find_each(&:rebake!)
    end
  end
end
