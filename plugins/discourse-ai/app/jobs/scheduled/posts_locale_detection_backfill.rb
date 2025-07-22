# frozen_string_literal: true

module Jobs
  class PostsLocaleDetectionBackfill < ::Jobs::Scheduled
    every 5.minutes
    sidekiq_options retry: false
    cluster_concurrency 1

    def execute(args)
      return if !DiscourseAi::Translation.backfill_enabled?

      limit = SiteSetting.ai_translation_backfill_hourly_rate / (60 / 5) # this job runs in 5-minute intervals

      posts =
        Post
          .where(locale: nil)
          .where(deleted_at: nil)
          .where("posts.user_id > 0")
          .where("posts.created_at > ?", SiteSetting.ai_translation_backfill_max_age_days.days.ago)
          .where.not(raw: [nil, ""])

      if SiteSetting.ai_translation_backfill_limit_to_public_content
        posts =
          posts
            .joins(:topic)
            .where(topics: { category_id: Category.where(read_restricted: false).select(:id) })
            .where("archetype != ?", Archetype.private_message)
      else
        posts =
          posts.joins(:topic).where(
            "topics.archetype != ? OR EXISTS (SELECT 1 FROM topic_allowed_groups WHERE topic_id = topics.id)",
            Archetype.private_message,
          )
      end

      posts = posts.order(updated_at: :desc).limit(limit)
      return if posts.empty?

      posts.each do |post|
        begin
          DiscourseAi::Translation::PostLocaleDetector.detect_locale(post)
        rescue FinalDestination::SSRFDetector::LookupFailedError
          # do nothing, there are too many sporadic lookup failures
        rescue => e
          DiscourseAi::Translation::VerboseLogger.log(
            "Failed to detect post #{post.id}'s locale: #{e.message}\n\n#{e.backtrace[0..3].join("\n")}",
          )
        end
      end

      DiscourseAi::Translation::VerboseLogger.log("Detected #{posts.size} post locales")
    end
  end
end
