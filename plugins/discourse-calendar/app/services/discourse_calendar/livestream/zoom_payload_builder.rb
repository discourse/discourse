# frozen_string_literal: true

module DiscourseCalendar
  module Livestream
    # Builds the payload the client needs to join a Zoom meeting through the
    # Meeting SDK, including a signed JWT auth token.
    # See https://developers.zoom.us/docs/meeting-sdk/auth/ for details on each
    # of the token fields.
    class ZoomPayloadBuilder < Service::ActionBase
      ROLE_PARTICIPANT = 0
      TOKEN_ISSUE_LEEWAY = 30.seconds
      TOKEN_VALIDITY = 2.hours

      option :topic

      # The user joining the zoom meeting as an attendee
      option :user

      # Parsed from a zoom URL via DiscourseCalendar::Livestream::ZoomUrlParser
      option :zoom_join_data

      def call
        {
          sdk_key: sdk_key,
          signature: signature,
          meeting_number: zoom_join_data[:meeting_number],
          password: zoom_join_data[:password],
          user_name: user.display_name,
          user_email: user.email,
          leave_url: topic.relative_url,
        }
      end

      private

      def signature
        JWT.encode(
          jwt_payload,
          SiteSetting.livestream_zoom_sdk_secret,
          "HS256",
          { alg: "HS256", typ: "JWT" },
        )
      end

      def jwt_payload
        {
          sdkKey: sdk_key,
          appKey: sdk_key,
          mn: zoom_join_data[:meeting_number],
          role: ROLE_PARTICIPANT,
          iat: issued_at,
          exp: expires_at,
          tokenExp: expires_at,
        }
      end

      def issued_at
        @issued_at ||= Time.zone.now.to_i - TOKEN_ISSUE_LEEWAY.to_i
      end

      def expires_at
        issued_at + TOKEN_VALIDITY.to_i
      end

      def sdk_key
        SiteSetting.livestream_zoom_sdk_key
      end
    end
  end
end
