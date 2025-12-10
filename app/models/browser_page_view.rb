# frozen_string_literal: true

class BrowserPageView < ActiveRecord::Base
  self.primary_key = nil

  belongs_to :user, optional: true
  belongs_to :topic, optional: true

  def self.log!(data)
    create!(
      user_id: data[:current_user_id],
      topic_id: data[:topic_id],
      url: data[:url]&.slice(0, 1024),
      route: data[:route]&.slice(0, 100),
      user_agent: data[:user_agent]&.slice(0, 512),
      ip_address: data[:request_remote_ip],
      referrer: data[:referrer]&.slice(0, 1024),
      is_crawler: data[:is_crawler] || false,
      is_mobile: data[:is_mobile] || false,
      is_api: data[:is_api] || false,
      is_user_api: data[:is_user_api] || false,
      http_status: data[:status],
      created_at: Time.current,
    )
  rescue => e
    Discourse.warn_exception(e, message: "Failed to log browser page view")
  end
end
