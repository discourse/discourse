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
             :created_at

  def request_url
    object.web_hook.payload_url
  end
end
