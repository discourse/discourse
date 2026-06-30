# frozen_string_literal: true

class BrowserPageviewSessionEngagement < ActiveRecord::Base
  MAX_SESSION_ID_LENGTH = 32

  def self.upsert_from_payload(
    session_id:,
    mouse_move_events:,
    click_events:,
    key_events:,
    scroll_events:,
    touch_events:,
    back_forward_events:,
    engaged_seconds:,
    time_to_first_interaction_ms:
  )
    return if session_id.blank?

    upsert_all(
      [
        {
          session_id:,
          mouse_move_events:,
          click_events:,
          key_events:,
          scroll_events:,
          touch_events:,
          back_forward_events:,
          engaged_seconds:,
          time_to_first_interaction_ms:,
        },
      ],
      unique_by: :session_id,
      record_timestamps: true,
    )
  end
end

# == Schema Information
#
# Table name: browser_pageview_session_engagements
#
#  id                           :bigint           not null, primary key
#  back_forward_events          :integer          default(0), not null
#  click_events                 :integer          default(0), not null
#  engaged_seconds              :integer          default(0), not null
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
