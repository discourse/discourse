# frozen_string_literal: true

module Jobs
  class RebakePostsForUpload < ::Jobs::Base
    def execute(args)
      Upload.find(args[:id]).posts.find_each(&:rebake!)
    end
  end
end
