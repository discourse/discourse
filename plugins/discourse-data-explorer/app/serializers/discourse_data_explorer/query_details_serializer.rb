# frozen_string_literal: true

module DiscourseDataExplorer
  class QueryDetailsSerializer < QuerySerializer
    attributes :sql, :param_info, :created_at, :hidden

    def param_info
      object&.params&.uniq { |p| p.identifier }&.map(&:to_hash)
    end

    attribute :ai_generating

    def include_ai_generating?
      SiteSetting.data_explorer_ai_queries_enabled
    end

    def ai_generating
      Discourse.redis.exists?(DiscourseDataExplorer::AiQueryEnqueuer.redis_key(object.id))
    end
  end
end
