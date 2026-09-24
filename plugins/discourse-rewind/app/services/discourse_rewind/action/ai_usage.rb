# frozen_string_literal: true

module DiscourseRewind
  module Action
    class AiUsage < BaseReport
      MAX_USAGES = 3
      MINIMUM_REQUESTS = 10
      MINIMUM_TOKENS = 1000

      FakeData = {
        data: {
          total_requests: 247,
          total_tokens: 156_890,
          feature_usage: [
            { name: "chat_composer_helper", count: 89 },
            { name: "post_summarizer", count: 56 },
            { name: "semantic_search", count: 42 },
          ],
          model_usage: [
            { name: "gpt-4", count: 123 },
            { name: "claude-3-5-sonnet", count: 89 },
            { name: "gpt-3.5-turbo", count: 35 },
          ],
          success_rate: 94.7,
        },
        identifier: "ai-usage",
      }

      def call
        return FakeData if should_use_fake_data?

        base_query = AiApiRequestStat.where(user_id: user.id).where(bucket_date: date)

        stats =
          base_query.select(
            "COALESCE(SUM(usage_count), 0) as total_requests",
            "COALESCE(SUM(request_tokens), 0) as total_request_tokens",
            "COALESCE(SUM(response_tokens), 0) as total_response_tokens",
            "COALESCE(SUM(CASE WHEN response_tokens > 0 THEN usage_count ELSE 0 END), 0) as successful_requests",
          ).take

        return if stats.total_requests < MINIMUM_REQUESTS

        total_tokens = stats.total_request_tokens + stats.total_response_tokens
        return if total_tokens < MINIMUM_TOKENS

        success_rate = (stats.successful_requests.to_f / stats.total_requests * 100).round(1)

        feature_usage = usage_by(base_query, :feature_name)
        model_usage = usage_by(base_query, :language_model)

        {
          data: {
            total_requests: stats.total_requests,
            total_tokens:,
            feature_usage:,
            model_usage:,
            success_rate:,
          },
          identifier: "ai-usage",
        }
      end

      def self.filter_for_viewer(report, guardian:, for_user:)
        return report if guardian.is_me?(for_user) || guardian.is_admin?

        report.merge(data: report[:data].except(:model_usage))
      end

      def self.enabled?
        plugin_enabled?("discourse-ai")
      end

      private

      def usage_by(query, column)
        query
          .where.not(column => [nil, ""])
          .group(column)
          .order(Arel.sql("SUM(usage_count) DESC"), column)
          .limit(MAX_USAGES)
          .pluck(column, Arel.sql("SUM(usage_count)"))
          .map { |name, count| { name:, count: } }
      end
    end
  end
end
