# frozen_string_literal: true

class AiApiAuditLogSerializer < ApplicationSerializer
  attributes :id,
             :provider_id,
             :user_id,
             :request_tokens,
             :response_tokens,
             :raw_request_payload,
             :raw_response_payload,
             :topic_id,
             :post_id,
             :feature_name,
             :language_model,
             :created_at,
             :prev_log_id,
             :next_log_id
end
