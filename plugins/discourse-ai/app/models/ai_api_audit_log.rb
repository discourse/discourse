# frozen_string_literal: true

class AiApiAuditLog < ActiveRecord::Base
  belongs_to :post
  belongs_to :topic
  belongs_to :user

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
  end

  def next_log_id
    self.class.where("id > ?", id).where(topic_id: topic_id).order(id: :asc).pluck(:id).first
  end

  def prev_log_id
    self.class.where("id < ?", id).where(topic_id: topic_id).order(id: :desc).pluck(:id).first
  end
end

# == Schema Information
#
# Table name: ai_api_audit_logs
#
#  id                   :bigint           not null, primary key
#  provider_id          :integer          not null
#  user_id              :integer
#  request_tokens       :integer
#  response_tokens      :integer
#  raw_request_payload  :string
#  raw_response_payload :string
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  topic_id             :integer
#  post_id              :integer
#  feature_name         :string(255)
#  language_model       :string(255)
#  feature_context      :jsonb
#  cached_tokens        :integer
#  duration_msecs       :integer
#
# Indexes
#
#  index_ai_api_audit_logs_on_created_at_and_feature_name    (created_at,feature_name)
#  index_ai_api_audit_logs_on_created_at_and_language_model  (created_at,language_model)
#
