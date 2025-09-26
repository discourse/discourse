# frozen_string_literal: true

module Jobs
  class SummariesBackfill < ::Jobs::Scheduled
    every 5.minutes
    cluster_concurrency 1

    def execute(_args)
      return if !SiteSetting.discourse_ai_enabled
      return if !SiteSetting.ai_summarization_enabled
      return if SiteSetting.ai_summary_backfill_maximum_topics_per_hour.zero?

      system_user = Discourse.system_user

      if SiteSetting.ai_summary_gists_enabled
        gist_t = AiSummary.summary_types[:gist]

        backfill_candidates(gist_t)
          .limit(current_budget(gist_t))
          .each do |topic|
            strategy = DiscourseAi::Summarization.topic_gist(topic)
            try_summarize(strategy, system_user, topic)
          end
      end

      complete_t = AiSummary.summary_types[:complete]
      backfill_candidates(complete_t)
        .limit(current_budget(complete_t))
        .each do |topic|
          strategy = DiscourseAi::Summarization.topic_summary(topic)
          try_summarize(strategy, system_user, topic)
        end
    end

    def try_summarize(strategy, user, topic)
      existing_summary = strategy.existing_summary

      if existing_summary.blank? || existing_summary.outdated
        begin
          strategy.summarize(user)
        rescue => e
          Rails.logger.error("Error summarizing topic #{topic.id}: #{e.class.name} - #{e.message}")
          raise e
        end
      else
        # Hiding or deleting a post, and creating a small action alters the Topic#highest_post_number.
        # We use this as a quick way to select potential backfill candidates without relying on original_content_sha.
        # At this point, we are confident the summary doesn't need to be regenerated so something other than a regular reply
        # caused the number to change in the topic.
        existing_summary.update!(highest_target_number: topic.highest_post_number)
      end
    end

    def backfill_candidates(summary_type)
      max_age_days = SiteSetting.ai_summary_backfill_topic_max_age_days

      Topic
        .where("topics.word_count >= ?", SiteSetting.ai_summary_backfill_minimum_word_count)
        .joins(<<~SQL)
          LEFT OUTER JOIN ai_summaries ais ON
                          topics.id = ais.target_id AND
                          ais.target_type = 'Topic' AND
                          ais.summary_type = '#{summary_type}'
        SQL
        .where("topics.last_posted_at > current_timestamp - INTERVAL '#{max_age_days.to_i} DAY'")
        .where(
          <<~SQL, # (1..1) gets stored ad (1..2).
          ais.id IS NULL OR (
            ais.highest_target_number < topics.highest_post_number
            AND ais.updated_at < (current_timestamp - INTERVAL '5 minutes')
          )
        SQL
        )
        .order("ais.updated_at DESC NULLS FIRST, topics.last_posted_at DESC")
    end

    def current_budget(type)
      # Split budget in 12 intervals, but make sure is at least one.
      base_budget = SiteSetting.ai_summary_backfill_maximum_topics_per_hour
      limit_per_job = [base_budget, 12].max / 12

      used_budget =
        AiSummary.system.where("created_at > ?", 1.hour.ago).where(summary_type: type).count

      current_budget = [(base_budget - used_budget), limit_per_job].min
      return 0 if current_budget < 0

      current_budget
    end
  end
end
