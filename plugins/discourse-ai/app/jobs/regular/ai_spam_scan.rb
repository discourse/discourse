# frozen_string_literal: true

module Jobs
  class AiSpamScan < ::Jobs::Base
    def execute(args)
      return if !args[:post_id]
      post = Post.find_by(id: args[:post_id])
      return if !post

      DiscourseAi::AiModeration::SpamScanner.perform_scan(
        post,
        triggering_user_id: args[:triggering_user_id],
      )
    rescue DiscourseAi::Completions::Endpoints::Base::CompletionFailed => error
      # Keep retries without logging provider failures already surfaced by the admin notice.
      raise ::Jobs::HandledExceptionWrapper.new(error)
    end
  end
end
