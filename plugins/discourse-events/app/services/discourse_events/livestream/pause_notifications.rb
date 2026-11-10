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
  model :notification_pause, :build_notification_pause
  model :do_not_disturb_timing, :start_pause
  step :announce_pause

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

  def build_notification_pause(params:, guardian:)
    DiscourseEvents::Livestream::NotificationPause.new(user: guardian.user, key: params.pause_key)
  end

  # Finds nothing when leaving the meeting already ended this pause.
  def start_pause(notification_pause:, event:)
    notification_pause.start(ends_at: event.notification_pause_ends_at)
  end

  def announce_pause(guardian:)
    guardian.user.publish_do_not_disturb(ends_at: guardian.user.do_not_disturb_until)
  end
end
