# frozen_string_literal: true

module DiscourseDataExplorer
  class AiQueryEnqueuer
    def self.enabled?
      SiteSetting.data_explorer_ai_queries_enabled && defined?(DiscourseAi)
    end

    def self.enqueue(query:, user:, ai_description:)
      return if !enabled? || ai_description.blank?

      Discourse.redis.setex("data_explorer_ai_generating:#{query.id}", 120, user.id)
      Jobs.enqueue(
        :generate_de_query_with_ai,
        query_id: query.id,
        user_id: user.id,
        ai_description: ai_description,
      )
    end
  end
end
