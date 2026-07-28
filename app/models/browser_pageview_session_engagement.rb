# frozen_string_literal: true

class BrowserPageviewSessionEngagement < ActiveRecord::Base
  MAX_SESSION_ID_LENGTH = 32
  BEACON_SETTLE_PERIOD = 10.minutes

  INTERACTION_COLUMNS = %i[
    mouse_move_events
    click_events
    key_events
    scroll_events
    touch_events
    back_forward_events
  ]

  GREATEST_COLUMNS = INTERACTION_COLUMNS + %i[engaged_seconds time_to_first_interaction_ms]

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

    session_id = session_id.slice(0, MAX_SESSION_ID_LENGTH)

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
      on_duplicate: greatest_on_duplicate_clause,
      record_timestamps: true,
    )
  end

  def self.greatest_on_duplicate_clause
    assignments =
      GREATEST_COLUMNS.map do |column|
        "#{column} = GREATEST(#{table_name}.#{column}, EXCLUDED.#{column})"
      end
    assignments << "updated_at = EXCLUDED.updated_at"
    Arel.sql(assignments.join(", "))
  end
  private_class_method :greatest_on_duplicate_clause
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
