# frozen_string_literal: true

class AiApiAuditLogSerializer < ApplicationSerializer
  attributes :id,
             :provider_id,
             :user_id,
             :request_tokens,
             :response_tokens,
             :cache_read_tokens,
             :cache_write_tokens,
             :raw_request_payload,
             :raw_response_payload,
             :topic_id,
             :post_id,
             :feature_name,
             :llm_id,
             :language_model,
             :created_at,
             :prev_log_id,
             :next_log_id,
             :spending,
             :conversation_request_tokens,
             :conversation_response_tokens,
             :conversation_cache_read_tokens,
             :conversation_cache_write_tokens,
             :conversation_spending

  def spending
    object.llm_model&.spending_for(object)
  end

  def conversation_request_tokens
    conversation_stats && conversation_stats[:request_tokens]
  end

  def conversation_response_tokens
    conversation_stats && conversation_stats[:response_tokens]
  end

  def conversation_cache_read_tokens
    conversation_stats && conversation_stats[:cache_read_tokens]
  end

  def conversation_cache_write_tokens
    conversation_stats && conversation_stats[:cache_write_tokens]
  end

  def conversation_spending
    conversation_stats && conversation_stats[:spending]
  end

  private

  def conversation_stats
    return @conversation_stats if defined?(@conversation_stats)

    @conversation_stats =
      if object.topic_id.blank?
        nil
      else
        AiApiAuditLog.token_and_spending_stats(AiApiAuditLog.where(topic_id: object.topic_id))
      end
  end
end
