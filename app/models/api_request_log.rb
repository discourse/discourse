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

# == Schema Information
#
# Table name: api_request_logs
#
#  http_method   :string(10)
#  http_status   :integer
#  ip_address    :inet
#  is_user_api   :boolean          default(FALSE), not null
#  path          :string(1024)
#  response_time :float
#  route         :string(100)
#  user_agent    :string(512)
#  created_at    :datetime         not null
#  user_id       :integer
#
# Indexes
#
#  index_api_request_logs_on_created_at   (created_at)
#  index_api_request_logs_on_http_status  (http_status)
#  index_api_request_logs_on_route        (route)
#  index_api_request_logs_on_user_id      (user_id)
#
