# frozen_string_literal: true

module DiscourseDataExplorer
  class AiQueryEnqueuer
    REDIS_TTL = 360

    def self.enabled?
      SiteSetting.data_explorer_ai_queries_enabled && defined?(DiscourseAi)
    end

    def self.redis_key(generation_id)
      "data_explorer_ai_generating:#{generation_id}"
    end

    def self.enqueue(generation_id:, user:, ai_description:, existing_sql: nil)
      return if !enabled? || ai_description.blank?

      Discourse.redis.setex(redis_key(generation_id), REDIS_TTL, user.id)
      Jobs.enqueue(
        :generate_de_query_with_ai,
        generation_id: generation_id,
        user_id: user.id,
        ai_description: ai_description,
        existing_sql: existing_sql,
      )
    end
  end
end
