# frozen_string_literal: true

class BrowserPageviewBeaconEvent < BrowserPageviewEvent
  self.table_name = "browser_pageview_events_beacon"
end

# == Schema Information
#
# Table name: browser_pageview_events_beacon
#
#  id           :bigint           not null, primary key
#  country_code :string(2)
#  ip_address   :inet
#  referrer     :string(2000)
#  url          :string(2000)     not null
#  user_agent   :string(1000)     not null
#  created_at   :datetime         not null
#  session_id   :string(32)       not null
#  topic_id     :integer
#  user_id      :integer
#
# Indexes
#
#  index_browser_pageview_events_beacon_on_created_at  (created_at) USING brin
#  index_browser_pageview_events_beacon_on_topic_id    (topic_id)
#  index_browser_pageview_events_beacon_on_user_id     (user_id)
#
