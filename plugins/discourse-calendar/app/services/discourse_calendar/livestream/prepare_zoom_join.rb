# frozen_string_literal: true

class DiscourseCalendar::Livestream::PrepareZoomJoin
  include Service::Base

  params do
    attribute :topic_id, :integer

    validates :topic_id, presence: true
  end

  model :topic
  policy :livestream_enabled
  policy :zoom_enabled
  policy :can_see_topic
  policy :topic_has_livestream_tag
  policy :topic_has_first_post_event
  policy :event_has_zoom_url
  step :build_join_payload

  private

  def fetch_topic(params:)
    Topic.includes(:tags, first_post: :event).find_by(id: params.topic_id)
  end

  def livestream_enabled
    SiteSetting.livestream_enabled && SiteSetting.discourse_post_event_enabled
  end

  def zoom_enabled
    SiteSetting.livestream_zoom_enabled && SiteSetting.livestream_zoom_sdk_key.present? &&
      SiteSetting.livestream_zoom_sdk_secret.present?
  end

  def can_see_topic(topic:, guardian:)
    guardian.can_see?(topic)
  end

  def topic_has_livestream_tag(topic:)
    topic.tags.any? { |tag| tag.name == "livestream" }
  end

  def topic_has_first_post_event(topic:)
    context[:event] = topic.first_post&.event
    context[:event].present?
  end

  def event_has_zoom_url(event:)
    context[:zoom_join_data] = DiscourseCalendar::Livestream::ZoomUrlParser.parse(event.url)
    context[:zoom_join_data].present?
  end

  def build_join_payload(topic:, zoom_join_data:, guardian:)
    user = guardian.user
    iat = Time.zone.now.to_i - 30
    exp = iat + 2.hours.to_i

    payload = {
      sdkKey: SiteSetting.livestream_zoom_sdk_key,
      appKey: SiteSetting.livestream_zoom_sdk_key,
      mn: zoom_join_data[:meeting_number],
      role: 0,
      iat: iat,
      exp: exp,
      tokenExp: exp,
    }

    context[:sdk_key] = SiteSetting.livestream_zoom_sdk_key
    context[:signature] = JWT.encode(
      payload,
      SiteSetting.livestream_zoom_sdk_secret,
      "HS256",
      { alg: "HS256", typ: "JWT" },
    )
    context[:meeting_number] = zoom_join_data[:meeting_number]
    context[:password] = zoom_join_data[:password]
    context[:user_name] = user.name.presence || user.username
    context[:user_email] = user.email
    context[:leave_url] = topic.relative_url
  end
end
