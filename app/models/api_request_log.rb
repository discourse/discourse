# frozen_string_literal: true

class ApiRequestLog < ActiveRecord::Base
  self.primary_key = nil

  belongs_to :user, optional: true

  MAX_PATH_LENGTH = 1024
  MAX_ROUTE_LENGTH = 100
  MAX_USER_AGENT_LENGTH = 512

  def self.log!(data)
    create!(
      user_id: data[:current_user_id],
      path: data[:path]&.slice(0, MAX_PATH_LENGTH),
      route: data[:route]&.slice(0, MAX_ROUTE_LENGTH),
      http_method: data[:http_method]&.slice(0, 10),
      http_status: data[:status],
      ip_address: data[:request_remote_ip],
      user_agent: data[:user_agent]&.slice(0, MAX_USER_AGENT_LENGTH),
      is_user_api: data[:is_user_api] || false,
      response_time: data[:timing],
      created_at: Time.current,
    )
  rescue => e
    Discourse.warn_exception(e, message: "Failed to log API request")
  end
end
