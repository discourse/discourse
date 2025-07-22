# frozen_string_literal: true

module ::Jobs
  class FastTrackTopicGist < ::Jobs::Base
    sidekiq_options retry: false

    def execute(args)
      return if !SiteSetting.discourse_ai_enabled
      return if !SiteSetting.ai_summarization_enabled
      return if !SiteSetting.ai_summary_gists_enabled

      topic = Topic.find_by(id: args[:topic_id])
      return if topic.blank?

      summarizer = DiscourseAi::Summarization.topic_gist(topic)
      gist = summarizer.existing_summary
      return if gist.present? && (!gist.outdated || gist.created_at >= 5.minutes.ago)

      summarizer.summarize(Discourse.system_user)
    end
  end
end
