# frozen_string_literal: true

class DiscourseEvents::Livestream::PrepareZoomJoin
  include Service::Base

  params do
    attribute :topic_id, :integer
    attribute :ignore_timeframe, :boolean, default: false

    validates :topic_id, presence: true
  end

  policy :livestream_available
  policy :zoom_enabled
  model :topic
  policy :can_see_topic
  model :event
  policy :can_see_event
  policy :can_join_event
  policy :event_has_livestream
  policy :event_within_timeframe
  model :zoom_join_data, :build_zoom_join_data
  model :zoom_join_payload, :build_zoom_join_payload

  private

  def livestream_available
    SiteSetting.chat_enabled && SiteSetting.discourse_events_enabled &&
      SiteSetting.discourse_post_event_enabled
  end

  def zoom_enabled
    SiteSetting.livestream_zoom_enabled && SiteSetting.livestream_zoom_sdk_key.present? &&
      SiteSetting.livestream_zoom_sdk_secret.present?
  end

  def fetch_topic(params:)
    Topic.includes(:tags, first_post: :event).find_by(id: params.topic_id)
  end

  def can_see_topic(topic:, guardian:)
    guardian.can_see?(topic)
  end

  def fetch_event(topic:)
    topic.first_post&.event
  end

  def can_see_event(event:, guardian:)
    guardian.authenticated? || guardian.can_see_livestream_event?(event)
  end

  def can_join_event(event:, guardian:)
    guardian.authenticated? || event.allow_anonymous_livestream?
  end

  def event_has_livestream(event:)
    event.livestream? && event.livestream_url.present?
  end

  def event_within_timeframe(event:, params:, guardian:)
    if Rails.env.development? && params.ignore_timeframe &&
         (guardian.is_staff? || (guardian.anonymous? && event.allow_anonymous_livestream?))
      return true
    end

    event.currently_within_event_timeframe?
  end

  def build_zoom_join_data(event:)
    DiscourseEvents::Livestream::ZoomUrlParser.parse(event.livestream_url)
  end

  def build_zoom_join_payload(topic:, zoom_join_data:, guardian:)
    DiscourseEvents::Livestream::ZoomPayloadBuilder.call(
      topic:,
      zoom_join_data:,
      user: guardian.user,
    )
  end
end
