# frozen_string_literal: true
module DiscourseAi
  module Completions
    class Report
      UNKNOWN_FEATURE = "unknown"
      USER_LIMIT = 50

      attr_reader :start_date, :end_date, :base_query, :timezone

      def initialize(start_date: 30.days.ago, end_date: Time.current, timezone: Time.zone.name)
        @timezone = timezone

        Time.zone = timezone # Set the timezone for parsing dates in the user's timezone
        @start_date = start_date.beginning_of_day
        @end_date = end_date.end_of_day
        Time.zone = nil # Reset to default timezone

        @base_query = AiApiAuditLog.where(created_at: @start_date..@end_date)
      end

      def total_tokens
        stats.total_tokens || 0
      end

      def total_cached_tokens
        stats.total_cached_tokens || 0
      end

      def total_request_tokens
        stats.total_request_tokens || 0
      end

      def total_response_tokens
        stats.total_response_tokens || 0
      end

      def total_requests
        stats.total_requests || 0
      end

      def total_spending
        total = total_input_spending + total_output_spending + total_cached_input_spending
        total.round(2)
      end

      def total_input_spending
        model_costs.sum { |row| row.input_cost.to_f * row.total_request_tokens.to_i / 1_000_000.0 }
      end

      def total_output_spending
        model_costs.sum do |row|
          row.output_cost.to_f * row.total_response_tokens.to_i / 1_000_000.0
        end
      end

      def total_cached_input_spending
        model_costs.sum do |row|
          row.cached_input_cost.to_f * row.total_cached_tokens.to_i / 1_000_000.0
        end
      end

      def stats
        @stats ||=
          base_query.select(
            "COUNT(*) as total_requests",
            "SUM(COALESCE(request_tokens + response_tokens, 0)) as total_tokens",
            "SUM(COALESCE(cached_tokens,0)) as total_cached_tokens",
            "SUM(COALESCE(request_tokens,0)) as total_request_tokens",
            "SUM(COALESCE(response_tokens,0)) as total_response_tokens",
          )[
            0
          ]
      end

      def model_costs
        @model_costs ||=
          base_query
            .joins("LEFT JOIN llm_models ON llm_models.name = language_model")
            .group(
              "llm_models.name, llm_models.input_cost, llm_models.output_cost, llm_models.cached_input_cost",
            )
            .select(
              "llm_models.name",
              "llm_models.input_cost",
              "llm_models.output_cost",
              "llm_models.cached_input_cost",
              "SUM(COALESCE(request_tokens, 0)) as total_request_tokens",
              "SUM(COALESCE(response_tokens, 0)) as total_response_tokens",
              "SUM(COALESCE(cached_tokens, 0)) as total_cached_tokens",
            )
      end

      def guess_period(period = nil)
        period = nil if %i[day month hour].include?(period)
        period ||
          case @end_date - @start_date
          when 0..3.days
            :hour
          when 3.days..90.days
            :day
          else
            :month
          end
      end

      def tokens_by_period(period = nil)
        period = guess_period(period)
        results =
          base_query
            .group("DATE_TRUNC('#{period}', created_at)")
            .order("DATE_TRUNC('#{period}', created_at)")
            .select(
              "DATE_TRUNC('#{period}', created_at) as period",
              "SUM(COALESCE(request_tokens + response_tokens, 0)) as total_tokens",
              "SUM(COALESCE(cached_tokens,0)) as total_cached_tokens",
              "SUM(COALESCE(request_tokens,0)) as total_request_tokens",
              "SUM(COALESCE(response_tokens,0)) as total_response_tokens",
            )

        # Convert periods to user's timezone
        results.map do |row|
          row.period = row.period.in_time_zone(timezone)
          row
        end
      end

      def user_breakdown
        base_query
          .joins(:user)
          .joins("LEFT JOIN llm_models ON llm_models.name = language_model")
          .group(:user_id, "users.username", "users.uploaded_avatar_id")
          .order("usage_count DESC")
          .limit(USER_LIMIT)
          .select(
            "users.username",
            "users.uploaded_avatar_id",
            "COUNT(*) as usage_count",
            "SUM(COALESCE(request_tokens + response_tokens, 0)) as total_tokens",
            "SUM(COALESCE(cached_tokens,0)) as total_cached_tokens",
            "SUM(COALESCE(request_tokens,0)) as total_request_tokens",
            "SUM(COALESCE(response_tokens,0)) as total_response_tokens",
            "SUM(COALESCE(request_tokens, 0) * COALESCE(llm_models.input_cost, 0)) / 1000000.0 as input_spending",
            "SUM(COALESCE(response_tokens, 0) * COALESCE(llm_models.output_cost, 0)) / 1000000.0 as output_spending",
            "SUM(COALESCE(cached_tokens, 0) * COALESCE(llm_models.cached_input_cost, 0)) / 1000000.0 as cached_input_spending",
          )
      end

      def feature_breakdown
        base_query
          .joins("LEFT JOIN llm_models ON llm_models.name = language_model")
          .group(:feature_name)
          .order("usage_count DESC")
          .select(
            "case when coalesce(feature_name, '') = '' then '#{UNKNOWN_FEATURE}' else feature_name end as feature_name",
            "COUNT(*) as usage_count",
            "SUM(COALESCE(request_tokens + response_tokens, 0)) as total_tokens",
            "SUM(COALESCE(cached_tokens,0)) as total_cached_tokens",
            "SUM(COALESCE(request_tokens,0)) as total_request_tokens",
            "SUM(COALESCE(response_tokens,0)) as total_response_tokens",
            "SUM(COALESCE(request_tokens, 0) * COALESCE(llm_models.input_cost, 0))  / 1000000.0 as input_spending",
            "SUM(COALESCE(response_tokens, 0) * COALESCE(llm_models.output_cost, 0)) / 1000000.0 as output_spending",
            "SUM(COALESCE(cached_tokens, 0) * COALESCE(llm_models.cached_input_cost, 0)) / 1000000.0 as cached_input_spending",
          )
      end

      def model_breakdown
        base_query
          .joins("LEFT JOIN llm_models ON llm_models.name = language_model")
          .group(
            :language_model,
            "llm_models.input_cost",
            "llm_models.output_cost",
            "llm_models.cached_input_cost",
          )
          .order("usage_count DESC")
          .select(
            "language_model as llm",
            "COUNT(*) as usage_count",
            "SUM(COALESCE(request_tokens + response_tokens, 0)) as total_tokens",
            "SUM(COALESCE(cached_tokens,0)) as total_cached_tokens",
            "SUM(COALESCE(request_tokens,0)) as total_request_tokens",
            "SUM(COALESCE(response_tokens,0)) as total_response_tokens",
            "SUM(COALESCE(request_tokens, 0)) * COALESCE(llm_models.input_cost, 0) / 1000000.0 as input_spending",
            "SUM(COALESCE(response_tokens, 0)) * COALESCE(llm_models.output_cost, 0) / 1000000.0 as output_spending",
            "SUM(COALESCE(cached_tokens, 0)) * COALESCE(llm_models.cached_input_cost, 0) / 1000000.0 as cached_input_spending",
          )
      end

      def tokens_per_hour
        tokens_by_period(:hour)
      end

      def tokens_per_day
        tokens_by_period(:day)
      end

      def tokens_per_month
        tokens_by_period(:month)
      end

      def filter_by_feature(feature_name)
        if feature_name == UNKNOWN_FEATURE
          @base_query = base_query.where("coalesce(feature_name, '') = ''")
        else
          @base_query = base_query.where(feature_name: feature_name)
        end
        self
      end

      def filter_by_model(model_name)
        @base_query = base_query.where(language_model: model_name)
        self
      end
    end
  end
end
