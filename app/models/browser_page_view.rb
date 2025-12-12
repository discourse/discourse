# frozen_string_literal: true

class BrowserPageView < ActiveRecord::Base
  self.primary_key = nil

  belongs_to :user, optional: true
  belongs_to :topic, optional: true

  MAX_SESSION_ID_LENGTH = 36
  MAX_PATH_LENGTH = 1024
  MAX_QUERY_STRING_LENGTH = 1024
  MAX_ROUTE_NAME_LENGTH = 256
  MAX_REFERRER_LENGTH = 1024
  MAX_USER_AGENT_LENGTH = 512

  def self.log!(data)
    create!(
      session_id: data[:session_id]&.slice(0, MAX_SESSION_ID_LENGTH),
      user_id: data[:current_user_id],
      topic_id: data[:topic_id],
      path: data[:path]&.slice(0, MAX_PATH_LENGTH),
      query_string: data[:query_string]&.slice(0, MAX_QUERY_STRING_LENGTH),
      route_name: data[:route_name]&.slice(0, MAX_ROUTE_NAME_LENGTH),
      referrer: data[:referrer]&.slice(0, MAX_REFERRER_LENGTH),
      ip_address: data[:request_remote_ip],
      user_agent: data[:user_agent]&.slice(0, MAX_USER_AGENT_LENGTH),
      is_mobile: data[:is_mobile] || false,
      created_at: Time.current,
    )
  rescue => e
    Discourse.warn_exception(e, message: "Failed to log browser page view")
  end
end
