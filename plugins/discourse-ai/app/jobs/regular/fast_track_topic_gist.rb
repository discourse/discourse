# frozen_string_literal: true

module Jobs
  class FastTrackTopicGist < ::Jobs::Base
    sidekiq_options retry: false

    def execute(args)
      return if !SiteSetting.discourse_ai_enabled
      return if !SiteSetting.ai_summarization_enabled
      return if !SiteSetting.ai_summary_gists_enabled

      topic = Topic.find_by(id: args[:topic_id])
      return if topic.blank?

      stored = false
      begin
        stored = regenerate(topic, args)
      ensure
        drop_gist(topic, args[:locale]) if args[:drop_on_failure] && !stored
      end
    end

    private

    def regenerate(topic, args)
      summarizer = DiscourseAi::Summarization.topic_gist(topic, locale: args[:locale])
      return false if summarizer.blank?

      gist = summarizer.existing_summary

      unless args[:force_regenerate]
        return false if gist.present? && (!gist.outdated || gist.created_at >= 5.minutes.ago)
      end

      summarizer.summarize(Discourse.system_user)&.persisted?
    end

    # The gist being replaced may quote content that was since removed
    def drop_gist(topic, locale)
      stale_ids =
        AiSummary
          .gist
          .where(target: topic)
          .select(:id, :locale)
          .filter_map do |gist|
            gist.id if gist.locale.blank? || LocaleNormalizer.is_same?(gist.locale, locale)
          end

      AiSummary.where(id: stale_ids).delete_all
    end
  end
end
