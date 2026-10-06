# frozen_string_literal: true

module Jobs
  class CookMissingAiSummaries < ::Jobs::Scheduled
    BATCH_SIZE = 100

    every 1.hour
    cluster_concurrency 1

    def execute(_args)
      return if !SiteSetting.discourse_ai_enabled

      cursor_key = "cook_missing_ai_summaries:last_id"
      missing = AiSummary.where(summarized_cooked: nil).order(:id)
      summaries =
        missing.where("id > ?", Discourse.redis.get(cursor_key).to_i).limit(BATCH_SIZE).to_a
      summaries = missing.limit(BATCH_SIZE).to_a if summaries.empty?

      summaries.each do |summary|
        summary.cook_missing!
      rescue => error
        Discourse.warn_exception(error, message: "Failed to cook AI summary #{summary.id}")
      end
      Discourse.redis.set(cursor_key, summaries.last.id) if summaries.present?
    end
  end
end
