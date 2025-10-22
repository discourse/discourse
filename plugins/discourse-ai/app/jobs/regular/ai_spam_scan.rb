# frozen_string_literal: true

module Jobs
  class AiSpamScan < ::Jobs::Base
    def execute(args)
      return if !args[:post_id]
      post = Post.find_by(id: args[:post_id])
      return if !post

      DiscourseAi::AiModeration::SpamScanner.perform_scan(post)
    end
  end
end
