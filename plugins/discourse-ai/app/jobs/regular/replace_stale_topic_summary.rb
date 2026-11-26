# frozen_string_literal: true

module Jobs
  # Regenerates a summary whose source content was removed, replacing it in place.
  # The stale summary is dropped whenever a replacement can't be stored.
  class ReplaceStaleTopicSummary < ::Jobs::Base
    sidekiq_options retry: false

    def execute(args)
      topic_id, summary_type, locale = args.values_at(:topic_id, :summary_type, :locale)
      return if !AiSummary.summary_types.key?(summary_type.to_s)

      stale =
        AiSummary
          .where(target_type: "Topic", target_id: topic_id, summary_type:)
          .select(:id, :locale, :updated_at)
          .select do |summary|
            summary.locale.blank? ||
              (locale.present? && LocaleNormalizer.is_same?(summary.locale, locale))
          end
      return if stale.empty?

      stored_id = nil
      begin
        stored_id = regenerate(Topic.find_by(id: topic_id), summary_type.to_s, locale)&.id
      ensure
        stale.each do |summary|
          next if summary.id == stored_id

          AiSummary.where(id: summary.id, updated_at: summary.updated_at).delete_all
        end
      end
    end

    private

    def regenerate(topic, summary_type, locale)
      return if topic.blank?

      summarizer =
        if summary_type == "gist"
          return if !SiteSetting.ai_summary_gists_enabled

          DiscourseAi::Summarization.topic_gist(topic, locale:)
        else
          DiscourseAi::Summarization.topic_summary(topic, locale:)
        end

      summarizer&.summarize(Discourse.system_user)
    end
  end
end
