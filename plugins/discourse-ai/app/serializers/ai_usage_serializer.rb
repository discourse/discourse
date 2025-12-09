# frozen_string_literal: true

class AiUsageSerializer < ApplicationSerializer
  LLM_MODEL_ID_PATTERN = /^-?\d+$/

  attributes :data, :features, :feature_models, :models, :users, :summary, :period

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

  def feature_models
    result = {}
    breakdown_rows = object.feature_model_breakdown.to_a

    llm_ids = breakdown_rows.map(&:llm_id).compact.select { |id| numeric_id?(id) }.map(&:to_i)
    llm_models = LlmModel.where(id: llm_ids).includes(:llm_credit_allocation).index_by(&:id)

    breakdown_rows.each do |row|
      feature_name = row.feature_name.presence || "unknown"
      result[feature_name] ||= []

      model_data = build_model_data(row)
      enrich_with_credit_allocation!(model_data, row.llm_id, llm_models)

      result[feature_name] << model_data
    end

    result
  end

  def models
    breakdown_rows = object.model_breakdown.to_a

    llm_ids = breakdown_rows.map(&:llm_id).compact.select { |id| numeric_id?(id) }.map(&:to_i)
    llm_models = LlmModel.where(id: llm_ids).includes(:llm_credit_allocation).index_by(&:id)

    breakdown_rows.map do |row|
      model_data = build_model_data(row, id_key: :id)
      enrich_with_credit_allocation!(model_data, row.llm_id, llm_models)
      model_data
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

  private

  def numeric_id?(value)
    value.to_s.match?(LLM_MODEL_ID_PATTERN)
  end

  def build_model_data(row, id_key: :llm_id)
    {
      id_key => row.llm_id,
      :llm => row.llm_label,
      :usage_count => row.usage_count,
      :total_tokens => row.total_tokens,
      :total_cache_read_tokens => row.total_cache_read_tokens,
      :total_cache_write_tokens => row.total_cache_write_tokens,
      :total_request_tokens => row.total_request_tokens,
      :total_response_tokens => row.total_response_tokens,
      :input_spending => row.input_spending,
      :output_spending => row.output_spending,
      :cache_read_spending => row.cache_read_spending,
      :cache_write_spending => row.cache_write_spending,
    }
  end

  def enrich_with_credit_allocation!(model_data, llm_id, llm_models_index)
    return unless llm_id.present? && numeric_id?(llm_id)

    llm_model = llm_models_index[llm_id.to_i]
    return if llm_model&.llm_credit_allocation.blank?

    model_data[:credit_allocation] = LlmCreditAllocationSerializer.new(
      llm_model.llm_credit_allocation,
      root: false,
    ).as_json
  end
end
