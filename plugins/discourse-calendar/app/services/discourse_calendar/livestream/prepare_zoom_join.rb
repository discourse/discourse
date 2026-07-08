# frozen_string_literal: true

class DiscourseCalendar::Livestream::PrepareZoomJoin
  ZOOM_ROLE_PARTICIPANT = 0

  include Service::Base

  params do
    attribute :topic_id, :integer

    validates :topic_id, presence: true
  end

  model :topic
  policy :livestream_available
  policy :zoom_enabled
  policy :can_see_topic
  model :event
  policy :event_has_livestream
  model :zoom_join_data, :build_zoom_join_data
  model :zoom_join_payload, :build_zoom_join_payload

  private

  def fetch_topic(params:)
    Topic.includes(:tags, first_post: :event).find_by(id: params.topic_id)
  end

  def livestream_available
    SiteSetting.chat_enabled && SiteSetting.calendar_enabled &&
      SiteSetting.discourse_post_event_enabled
  end

  def zoom_enabled
    SiteSetting.livestream_zoom_enabled && SiteSetting.livestream_zoom_sdk_key.present? &&
      SiteSetting.livestream_zoom_sdk_secret.present?
  end

  def can_see_topic(topic:, guardian:)
    guardian.can_see?(topic)
  end

  def fetch_event(topic:)
    topic.first_post&.event
  end

  def event_has_livestream(event:)
    event.livestream? && (event.location.presence || event.url.presence)
  end

  def build_zoom_join_data(event:)
    DiscourseCalendar::Livestream::ZoomUrlParser.parse(event.location || event.url)
  end

  def build_zoom_join_payload(topic:, zoom_join_data:, guardian:)
    user = guardian.user
    token_issue_timestamp = Time.zone.now.to_i - 30
    expiration_timestamp = token_issue_timestamp + 2.hours.to_i

    # Generates a Zoom meeting SDK auth token using JWT,
    # see https://developers.zoom.us/docs/meeting-sdk/auth/
    # for details on each of these fields.
    jwt_payload = {
      sdkKey: SiteSetting.livestream_zoom_sdk_key,
      appKey: SiteSetting.livestream_zoom_sdk_key,
      mn: zoom_join_data[:meeting_number],
      role: ZOOM_ROLE_PARTICIPANT,
      iat: token_issue_timestamp,
      exp: expiration_timestamp,
      tokenExp: expiration_timestamp,
    }

    {
      sdk_key: SiteSetting.livestream_zoom_sdk_key,
      signature:
        JWT.encode(
          jwt_payload,
          SiteSetting.livestream_zoom_sdk_secret,
          "HS256",
          { alg: "HS256", typ: "JWT" },
        ),
      meeting_number: zoom_join_data[:meeting_number],
      password: zoom_join_data[:password],
      user_name: user.display_name,
      user_email: user.email,
      leave_url: topic.relative_url,
    }
  end
end
