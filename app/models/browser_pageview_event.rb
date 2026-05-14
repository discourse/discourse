# frozen_string_literal: true

class BrowserPageviewEvent < ActiveRecord::Base
  MAX_SESSION_ID_LENGTH = 32
  MAX_URL_LENGTH = 2000
  MAX_REFERRER_LENGTH = 2000
  MAX_USER_AGENT_LENGTH = 1000

  before_save :truncate_fields

  private

  def truncate_fields
    self.url = url.slice(0, MAX_URL_LENGTH) if url.present?
    self.referrer = referrer.slice(0, MAX_REFERRER_LENGTH) if referrer.present?
    self.user_agent = user_agent.slice(0, MAX_USER_AGENT_LENGTH) if user_agent.present?
    self.session_id = session_id.slice(0, MAX_SESSION_ID_LENGTH) if session_id.present?
  end
end

# == Schema Information
#
# Table name: browser_pageview_events
#
#  id           :bigint           not null, primary key
#  asn          :integer
#  country_code :string(2)
#  ip_address   :inet             not null
#  referrer     :string(2000)
#  score        :integer
#  url          :string(2000)     not null
#  user_agent   :string(1000)     not null
#  created_at   :datetime         not null
#  session_id   :string(32)       not null
#  topic_id     :integer
#  user_id      :integer
#
# Indexes
#
#  idx_bpe_ip_ua_created_at                     (ip_address,user_agent,created_at)
#  idx_bpe_session_created_at                   (session_id,created_at)
#  index_browser_pageview_events_on_created_at  (created_at) USING brin
#  index_browser_pageview_events_on_topic_id    (topic_id)
#  index_browser_pageview_events_on_user_id     (user_id)
#
