# frozen_string_literal: true

class DiscourseCalendar::Livestream::PrepareZoomJoin
  include Service::Base

  params do
    attribute :topic_id, :integer
    # TODO (martin) ignore_timeframe backs the showzoom testing workaround,
    # remove before merge
    attribute :ignore_timeframe, :boolean, default: false

    validates :topic_id, presence: true
  end

  policy :livestream_available
  policy :zoom_enabled
  model :topic
  policy :can_see_topic
  model :event
  policy :event_has_livestream
  policy :event_within_timeframe
  model :zoom_join_data, :build_zoom_join_data
  model :zoom_join_payload, :build_zoom_join_payload

  private

  def livestream_available
    SiteSetting.chat_enabled && SiteSetting.calendar_enabled &&
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

  def event_has_livestream(event:)
    event.livestream? && event.livestream_url.present?
  end

  def event_within_timeframe(event:, params:, guardian:)
    # TODO (martin) showzoom is for testing only, remove before merge
    return true if params.ignore_timeframe && guardian.is_staff?

    event.currently_within_event_timeframe?
  end

  def build_zoom_join_data(event:)
    DiscourseCalendar::Livestream::ZoomUrlParser.parse(event.livestream_url)
  end

  def build_zoom_join_payload(topic:, zoom_join_data:, guardian:)
    DiscourseCalendar::Livestream::ZoomPayloadBuilder.call(
      topic:,
      zoom_join_data:,
      user: guardian.user,
    )
  end
end
