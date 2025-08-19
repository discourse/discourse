# frozen_string_literal: true

class AiUsageSerializer < ApplicationSerializer
  attributes :data, :features, :models, :users, :summary, :period

  def data
    object.tokens_by_period.as_json(
      only: %i[period total_tokens total_cached_tokens total_request_tokens total_response_tokens],
    )
  end

  def period
    object.guess_period
  end

  def features
    object.feature_breakdown.as_json(
      only: %i[
        feature_name
        usage_count
        total_tokens
        total_cached_tokens
        total_request_tokens
        total_response_tokens
        input_spending
        output_spending
        cached_input_spending
      ],
    )
  end

  def models
    object.model_breakdown.as_json(
      only: %i[
        llm
        usage_count
        total_tokens
        total_cached_tokens
        total_request_tokens
        total_response_tokens
        input_spending
        output_spending
        cached_input_spending
      ],
    )
  end

  def users
    object.user_breakdown.map do |user|
      {
        avatar_template: User.avatar_template(user.username, user.uploaded_avatar_id),
        username: user.username,
        usage_count: user.usage_count,
        total_tokens: user.total_tokens,
        total_cached_tokens: user.total_cached_tokens,
        total_request_tokens: user.total_request_tokens,
        total_response_tokens: user.total_response_tokens,
        input_spending: user.input_spending,
        output_spending: user.output_spending,
        cached_input_spending: user.cached_input_spending,
      }
    end
  end

  def summary
    {
      total_tokens: object.total_tokens,
      total_cached_tokens: object.total_cached_tokens,
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
