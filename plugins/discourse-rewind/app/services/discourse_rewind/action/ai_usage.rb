# frozen_string_literal: true

# AI usage statistics from discourse-ai plugin
# Shows total usage, favorite features, token consumption, etc.
# Uses AiApiRequestStat for efficient aggregation queries
module DiscourseRewind
  module Action
    class AiUsage < BaseReport
      FakeData = {
        data: {
          total_requests: 247,
          total_tokens: 156_890,
          request_tokens: 45_230,
          response_tokens: 111_660,
          feature_usage: {
            "chat_composer_helper" => 89,
            "post_summarizer" => 56,
            "semantic_search" => 42,
            "topic_gist" => 38,
            "similar_topics" => 22,
          },
          model_usage: {
            "gpt-4" => 123,
            "claude-3-5-sonnet" => 89,
            "gpt-3.5-turbo" => 35,
          },
          success_rate: 94.7,
        },
        identifier: "ai-usage",
      }

      def call
        return FakeData if Rails.env.development?
        return if !enabled?

        base_query = AiApiRequestStat.where(user_id: user.id).where(bucket_date: date)

        # Get aggregated stats in a single query
        stats =
          base_query.select(
            "COALESCE(SUM(usage_count), 0) as total_requests",
            "COALESCE(SUM(request_tokens), 0) as total_request_tokens",
            "COALESCE(SUM(response_tokens), 0) as total_response_tokens",
            "COALESCE(SUM(CASE WHEN response_tokens > 0 THEN usage_count ELSE 0 END), 0) as successful_requests",
          ).take

        return if stats.total_requests == 0

        total_tokens = stats.total_request_tokens + stats.total_response_tokens
        success_rate =
          (
            if stats.total_requests > 0
              (stats.successful_requests.to_f / stats.total_requests * 100).round(1)
            else
              0
            end
          )

        # Most used features (top 5)
        feature_usage =
          base_query
            .group(:feature_name)
            .order("SUM(usage_count) DESC")
            .limit(5)
            .pluck(:feature_name, Arel.sql("SUM(usage_count)"))
            .to_h

        # Most used AI model (top 5)
        model_usage =
          base_query
            .where.not(language_model: nil)
            .group(:language_model)
            .order("SUM(usage_count) DESC")
            .limit(5)
            .pluck(:language_model, Arel.sql("SUM(usage_count)"))
            .to_h

        {
          data: {
            total_requests: stats.total_requests,
            total_tokens: total_tokens,
            request_tokens: stats.total_request_tokens,
            response_tokens: stats.total_response_tokens,
            feature_usage: feature_usage,
            model_usage: model_usage,
            success_rate: success_rate,
          },
          identifier: "ai-usage",
        }
      end

      def enabled?
        Discourse.plugins_by_name["discourse-ai"]&.enabled?
      end
    end
  end
end
