# frozen_string_literal: true

class AdminWebHookEventSerializer < ApplicationSerializer
  attributes :id,
             :web_hook_id,
             :request_url,
             :headers,
             :payload,
             :status,
             :response_headers,
             :response_body,
             :duration,
             :created_at,
             :redelivering

  def request_url
    object.web_hook.payload_url
  end

  def redelivering
    object.redelivering_webhook_event.present?
  end
end
