# frozen_string_literal: true

class AiUsageSerializer < ApplicationSerializer
  attributes :data, :features, :models, :users, :summary, :period

  def data
    object.tokens_by_period.map do |row|
      row.as_json(
        only: %i[
          period
          total_tokens
          total_cache_read_tokens
          total_cache_write_tokens
          total_request_tokens
          total_response_tokens
        ],
      )
    end
  end

  def period
    object.guess_period
  end

  def features
    object.feature_breakdown.map do |row|
      row.as_json(
        only: %i[
          feature_name
          usage_count
          total_tokens
          total_cache_read_tokens
          total_cache_write_tokens
          total_request_tokens
          total_response_tokens
          input_spending
          output_spending
          cache_read_spending
          cache_write_spending
        ],
      )
    end
  end

  def models
    object.model_breakdown.map do |row|
      {
        id: row.llm_id,
        llm: row.llm_label,
        usage_count: row.usage_count,
        total_tokens: row.total_tokens,
        total_cache_read_tokens: row.total_cache_read_tokens,
        total_cache_write_tokens: row.total_cache_write_tokens,
        total_request_tokens: row.total_request_tokens,
        total_response_tokens: row.total_response_tokens,
        input_spending: row.input_spending,
        output_spending: row.output_spending,
        cache_read_spending: row.cache_read_spending,
        cache_write_spending: row.cache_write_spending,
      }
    end
  end

  def users
    object.user_breakdown.map do |user|
      {
        avatar_template: User.avatar_template(user.username, user.uploaded_avatar_id),
        username: user.username,
        usage_count: user.usage_count,
        total_tokens: user.total_tokens,
        total_cache_read_tokens: user.total_cache_read_tokens,
        total_cache_write_tokens: user.total_cache_write_tokens,
        total_request_tokens: user.total_request_tokens,
        total_response_tokens: user.total_response_tokens,
        input_spending: user.input_spending,
        output_spending: user.output_spending,
        cache_read_spending: user.cache_read_spending,
        cache_write_spending: user.cache_write_spending,
      }
    end
  end

  def summary
    {
      total_tokens: object.total_tokens,
      total_cache_read_tokens: object.total_cache_read_tokens,
      total_cache_write_tokens: object.total_cache_write_tokens,
      total_request_tokens: object.total_request_tokens,
      total_response_tokens: object.total_response_tokens,
      total_requests: object.total_requests,
      total_spending: object.total_spending,
      date_range: {
        start: object.start_date,
        end: object.end_date,
      },
    }
  end
end
