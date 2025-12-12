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
  MAX_PREVIOUS_PATH_LENGTH = 1024
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
      previous_path: data[:previous_path]&.slice(0, MAX_PREVIOUS_PATH_LENGTH),
      ip_address: data[:request_remote_ip],
      user_agent: data[:user_agent]&.slice(0, MAX_USER_AGENT_LENGTH),
      is_mobile: data[:is_mobile] || false,
      created_at: Time.current,
    )
  rescue => e
    Discourse.warn_exception(e, message: "Failed to log browser page view")
  end
end

# == Schema Information
#
# Table name: browser_page_views
#
#  ip_address    :inet
#  is_mobile     :boolean          default(FALSE), not null
#  path          :string(1024)
#  previous_path :string(1024)
#  query_string  :string(1024)
#  referrer      :string(1024)
#  route_name    :string(256)
#  user_agent    :string(512)
#  created_at    :datetime         not null
#  session_id    :string(36)
#  topic_id      :integer
#  user_id       :integer
#
# Indexes
#
#  index_browser_page_views_on_created_at  (created_at)
#  index_browser_page_views_on_route_name  (route_name)
#  index_browser_page_views_on_session_id  (session_id)
#  index_browser_page_views_on_topic_id    (topic_id)
#  index_browser_page_views_on_user_id     (user_id)
#
