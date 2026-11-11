# frozen_string_literal: true

class DiscourseEvents::Livestream::PauseNotifications
  include Service::Base

  params do
    attribute :topic_id, :integer
    attribute :pause_key, :string

    validates :topic_id, presence: true
    validates :pause_key, presence: true, format: { with: /\A[0-9a-f-]{36}\z/ }
  end

  model :topic
  policy :can_see_topic
  model :event
  policy :event_not_over
  model :do_not_disturb_timing, :start_pause

  private

  def fetch_topic(params:)
    Topic.includes(first_post: :event).find_by(id: params.topic_id)
  end

  def can_see_topic(topic:, guardian:)
    guardian.can_see?(topic)
  end

  def fetch_event(topic:)
    topic.first_post&.event
  end

  def event_not_over(event:)
    event.notification_pause_ends_at > Time.zone.now
  end

  # Finds nothing when leaving the webinar already ended this pause.
  def start_pause(params:, guardian:, event:)
    UserNotificationPause.new(user: guardian.user).start(
      ends_at: event.notification_pause_ends_at,
      source: "livestream",
      key: params.pause_key,
    )
  end
end
