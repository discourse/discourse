# frozen_string_literal: true

module Jobs
  class SentimentBackfill < ::Jobs::Scheduled
    every 5.minutes
    cluster_concurrency 1

    def execute(_args)
      return if !SiteSetting.ai_sentiment_enabled

      base_budget = SiteSetting.ai_sentiment_backfill_maximum_posts_per_hour
      return if base_budget.zero?
      # Split budget in 12 intervals, but make sure is at least one.
      #
      # This is not exact as we don't have a way of tracking how many
      # posts we classified in the current hour, but it's a good enough approximation.
      limit_per_job = [base_budget, 12].max / 12

      classificator = DiscourseAi::Sentiment::PostClassification.new
      return if !classificator.has_classifiers?

      posts =
        DiscourseAi::Sentiment::PostClassification.backfill_query(
          max_age_days: SiteSetting.ai_sentiment_backfill_post_max_age_days,
        ).limit(limit_per_job)

      classificator.bulk_classify!(posts)
    end
  end
end
