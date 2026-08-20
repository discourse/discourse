# frozen_string_literal: true

class AiApiAuditLog < ActiveRecord::Base
  self.ignored_columns += [
    "cached_tokens", # TODO: Remove when 20251118000500_drop_cached_tokens_from_ai_api_audit_logs has been promoted to pre-deploy
  ]
  belongs_to :post
  belongs_to :topic
  belongs_to :user
  belongs_to :llm_model, foreign_key: :llm_id, optional: true

  # Keep this predicate compatible with idx_ai_api_audit_logs_failed_id.
  FAILURE_CONDITION =
    "(response_status IS NOT NULL AND response_status NOT BETWEEN 200 AND 299) OR " \
      "(response_status IS NULL AND COALESCE(response_tokens, 0) <= 0)"
  SUCCESS_CONDITION =
    "(response_status BETWEEN 200 AND 299) OR " \
      "(response_status IS NULL AND COALESCE(response_tokens, 0) > 0)"

  scope :failed_requests, -> { where(FAILURE_CONDITION) }
  scope :successful_requests, -> { where(SUCCESS_CONDITION) }

  module Provider
    OpenAI = 1
    Anthropic = 2
    HuggingFaceTextGeneration = 3
    Gemini = 4
    Vllm = 5
    Cohere = 6
    Ollama = 7
    SambaNova = 8
    Mistral = 9
    OpenRouter = 10
    BedrockConverse = 11
  end

  def self.token_and_spending_stats(scope)
    spending_expr = LlmModel.estimated_or_calculated_spending_sql(table_name)
    request_tokens,
    response_tokens,
    cache_read_tokens,
    cache_write_tokens,
    spending,
    spending_count =
      scope.joins("LEFT JOIN llm_models ON llm_models.id = #{table_name}.llm_id").pick(
        Arel.sql("COALESCE(SUM(COALESCE(#{table_name}.request_tokens, 0)), 0)"),
        Arel.sql("COALESCE(SUM(COALESCE(#{table_name}.response_tokens, 0)), 0)"),
        Arel.sql("COALESCE(SUM(COALESCE(#{table_name}.cache_read_tokens, 0)), 0)"),
        Arel.sql("COALESCE(SUM(COALESCE(#{table_name}.cache_write_tokens, 0)), 0)"),
        Arel.sql("SUM(#{spending_expr})"),
        Arel.sql("COUNT(#{spending_expr})"),
      )

    {
      request_tokens: request_tokens.to_i,
      response_tokens: response_tokens.to_i,
      cache_read_tokens: cache_read_tokens.to_i,
      cache_write_tokens: cache_write_tokens.to_i,
      spending: spending_count.to_i.positive? ? spending.to_f.round(6) : nil,
    }
  end

  def next_log_id
    self.class.where("id > ?", id).where(topic_id: topic_id).order(id: :asc).pick(:id)
  end

  def prev_log_id
    self.class.where("id < ?", id).where(topic_id: topic_id).order(id: :desc).pick(:id)
  end
end

# == Schema Information
#
# Table name: ai_api_audit_logs
#
#  id                        :bigint           not null, primary key
#  cache_read_tokens         :integer
#  cache_write_tokens        :integer
#  duration_msecs            :integer
#  estimated_cost            :decimal(20, 10)
#  feature_context           :jsonb
#  feature_name              :string(255)
#  language_model            :string(255)
#  raw_request_payload       :string
#  raw_response_payload      :string
#  request_attempts          :jsonb
#  request_tokens            :integer
#  response_status           :integer
#  response_tokens           :integer
#  time_to_first_token_msecs :integer
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  llm_id                    :bigint
#  post_id                   :integer
#  provider_id               :integer          not null
#  topic_id                  :integer
#  user_id                   :integer
#
# Indexes
#
#  idx_ai_api_audit_logs_failed_id                           (id) WHERE (((response_status IS NOT NULL) AND ((response_status < 200) OR (response_status > 299))) OR ((response_status IS NULL) AND (COALESCE(response_tokens, 0) <= 0)))
#  idx_ai_api_audit_logs_feature_name_id                     (feature_name,id) WHERE (feature_name IS NOT NULL)
#  idx_ai_api_audit_logs_payload_id                          (id) WHERE ((raw_request_payload IS NOT NULL) OR (raw_response_payload IS NOT NULL))
#  idx_ai_api_audit_logs_retried_id                          (id) WHERE (request_attempts IS NOT NULL)
#  idx_ai_api_audit_logs_user_id_id                          (user_id,id)
#  index_ai_api_audit_logs_on_created_at_and_feature_name    (created_at,feature_name)
#  index_ai_api_audit_logs_on_created_at_and_language_model  (created_at,language_model)
#  index_ai_api_audit_logs_on_created_at_and_user_id         (created_at,user_id)
#  index_ai_api_audit_logs_on_llm_id                         (llm_id)
#  index_ai_api_audit_logs_on_post_id                        (post_id)
#  index_ai_api_audit_logs_on_topic_id                       (topic_id)
#
