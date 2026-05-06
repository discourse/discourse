# frozen_string_literal: true

module Jobs
  class PostLocalizationBackfill < ::Jobs::Scheduled
    every 15.minutes
    cluster_concurrency 1

    REDIS_KEY = "discourse-ai:localize_posts:in_progress"

    def execute(args)
      return if !DiscourseAi::Translation.backfill_enabled?

      # Skip if previous batch is still running
      return if Discourse.redis.get(REDIS_KEY).to_i > 0

      post_raw_llm = find_llm_model_for_agent(SiteSetting.ai_translation_post_raw_translator_agent)

      if post_raw_llm && !LlmCreditAllocation.credits_available?(post_raw_llm)
        Rails.logger.info(
          "Post localization backfill skipped: insufficient credits. Will resume when credits reset.",
        )
        return
      end

      limit = SiteSetting.ai_translation_backfill_hourly_rate / (60 / 15) # this job runs in 15-minute intervals
      return if limit == 0

      pairs = DiscourseAi::Translation::PostCandidates.needs_localization(limit: limit)
      return if pairs.empty?

      parallel_jobs = SiteSetting.ai_translation_backfill_parallel_jobs
      chunks = pairs.each_slice((pairs.size.to_f / parallel_jobs).ceil).to_a

      # Set counter with 15-min TTL safety net (if a job crashes without decrementing)
      Discourse.redis.setex(REDIS_KEY, 15.minutes.to_i, chunks.size)

      chunks.each { |chunk| Jobs.enqueue(:localize_posts, pairs: chunk) }
    end

    private

    def find_llm_model_for_agent(agent_id)
      return nil if agent_id.blank?

      agent_klass = AiAgent.find_by_id_from_cache(agent_id)
      return nil if agent_klass.blank?

      DiscourseAi::Translation::BaseTranslator.preferred_llm_model(agent_klass)
    end
  end
end
