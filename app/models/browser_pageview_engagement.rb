# frozen_string_literal: true

class BrowserPageviewEngagement < ActiveRecord::Base
  belongs_to :event, class_name: "BrowserPageviewEvent"

  # A ping that races the deferred pageview insert resolves to no event and
  # is dropped: a later ping heals the loss, a stored orphan never would.
  def self.record(session_id:, url:, occurred_at:)
    event_id =
      BrowserPageviewEvent
        .where(session_id: session_id, url: url)
        .where(created_at: ..occurred_at)
        .order(created_at: :desc, id: :desc)
        .pick(:id)

    create!(event_id: event_id, created_at: occurred_at) if event_id
  end
end

# == Schema Information
#
# Table name: browser_pageview_engagements
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  event_id   :bigint           not null
#
# Indexes
#
#  index_browser_pageview_engagements_on_event_id_and_created_at  (event_id,created_at)
#
