# frozen_string_literal: true

# Zoom reports that a meeting started or ended. Attendees already waiting are
# pushed to; anyone arriving later reads the recorded state instead.
class DiscourseCalendar::Livestream::UpdateZoomLiveState
  include Service::Base

  params do
    attribute :meeting_number, :string
    attribute :live, :boolean, default: false

    # Digits only: the number reaches a SQL LIKE pattern, where `%` and `_`
    # would otherwise widen the scan.
    validates :meeting_number, presence: true, format: { with: /\A\d+\z/ }
  end

  model :events

  only_if :started? do
    step :record_meeting_started
  end

  only_if :ended? do
    step :record_meeting_ended
  end

  each :events do
    step :publish_live_state
  end

  private

  # Zoom sends events for every meeting on the account, so most webhooks are
  # for meetings no event here points at.
  def fetch_events(params:)
    DiscourseCalendar::Livestream::ZoomLiveMeetings.events_for(params.meeting_number)
  end

  def started?(params:)
    params.live
  end

  def ended?(params:)
    !params.live
  end

  def record_meeting_started(params:)
    DiscourseCalendar::Livestream::ZoomLiveMeetings.started(params.meeting_number)
  end

  def record_meeting_ended(params:)
    DiscourseCalendar::Livestream::ZoomLiveMeetings.ended(params.meeting_number)
  end

  def publish_live_state(event:, params:)
    topic = event.post.topic

    MessageBus.publish(
      "/discourse-calendar/livestream/zoom/#{topic.id}",
      { live: params.live },
      **topic.secure_audience_publish_messages,
    )
  end
end
