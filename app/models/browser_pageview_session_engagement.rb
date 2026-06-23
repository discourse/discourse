# frozen_string_literal: true

class BrowserPageviewSessionEngagement < ActiveRecord::Base
  MAX_SESSION_ID_LENGTH = 32

  METRIC_COLUMNS = %i[
    mouse_move_events
    click_events
    key_events
    scroll_events
    touch_events
    back_forward_events
    engaged_duration_ms
    time_to_first_interaction_ms
  ]

  def self.upsert_from_payload(payload)
    payload = payload.with_indifferent_access
    return if payload[:session_id].blank?

    row = { session_id: payload[:session_id].slice(0, MAX_SESSION_ID_LENGTH) }
    METRIC_COLUMNS.each { |col| row[col] = payload[col].to_i }

    upsert_all([row], unique_by: :session_id, record_timestamps: true)
  end
end

# == Schema Information
#
# Table name: browser_pageview_session_engagements
#
#  id                           :bigint           not null, primary key
#  back_forward_events          :integer          default(0), not null
#  click_events                 :integer          default(0), not null
#  engaged_duration_ms          :integer          default(0), not null
#  key_events                   :integer          default(0), not null
#  mouse_move_events            :integer          default(0), not null
#  scroll_events                :integer          default(0), not null
#  time_to_first_interaction_ms :integer
#  touch_events                 :integer          default(0), not null
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#  session_id                   :string(32)       not null
#
# Indexes
#
#  index_browser_pageview_session_engagements_on_created_at  (created_at) USING brin
#  index_browser_pageview_session_engagements_on_session_id  (session_id) UNIQUE
#
