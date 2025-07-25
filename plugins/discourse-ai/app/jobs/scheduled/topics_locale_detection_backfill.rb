# frozen_string_literal: true

module Jobs
  class TopicsLocaleDetectionBackfill < ::Jobs::Scheduled
    every 5.minutes
    sidekiq_options retry: false
    cluster_concurrency 1

    def execute(args)
      return if !DiscourseAi::Translation.backfill_enabled?

      limit = SiteSetting.ai_translation_backfill_hourly_rate / (60 / 5) # this job runs in 5-minute intervals

      topics =
        Topic
          .where(locale: nil, deleted_at: nil)
          .where("topics.user_id > 0")
          .where("topics.created_at > ?", SiteSetting.ai_translation_backfill_max_age_days.days.ago)

      if SiteSetting.ai_translation_backfill_limit_to_public_content
        topics =
          topics.where(category_id: Category.where(read_restricted: false).select(:id)).where(
            "archetype != ?",
            Archetype.private_message,
          )
      else
        topics =
          topics.where(
            "archetype != ? OR EXISTS (SELECT 1 FROM topic_allowed_groups WHERE topic_id = topics.id)",
            Archetype.private_message,
          )
      end

      topics = topics.order(updated_at: :desc).limit(limit)
      return if topics.empty?

      topics.each do |topic|
        begin
          DiscourseAi::Translation::TopicLocaleDetector.detect_locale(topic)
        rescue FinalDestination::SSRFDetector::LookupFailedError
          # do nothing, there are too many sporadic lookup failures
        rescue => e
          DiscourseAi::Translation::VerboseLogger.log(
            "Failed to detect topic #{topic.id}'s locale: #{e.message}\n\n#{e.backtrace[0..3].join("\n")}",
          )
        end
      end

      DiscourseAi::Translation::VerboseLogger.log("Detected #{topics.size} topic locales")
    end
  end
end
