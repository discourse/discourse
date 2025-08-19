# frozen_string_literal: true

module ::Jobs
  class PostSentimentAnalysis < ::Jobs::Base
    sidekiq_options queue: "low"

    def execute(args)
      return unless SiteSetting.ai_sentiment_enabled
      return if (post_id = args[:post_id]).blank?

      post = Post.find_by(id: post_id, post_type: Post.types[:regular])
      return if post&.raw.blank?

      DiscourseAi::Sentiment::PostClassification.new.classify!(post)
    end
  end
end
