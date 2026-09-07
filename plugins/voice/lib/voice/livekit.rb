# frozen_string_literal: true

module Voice
  module Livekit
    # Raised when an access token cannot be minted (typically a half-deleted
    # configuration on a room whose live call is already pinned to LiveKit).
    class MintError < StandardError
    end

    TOKEN_TTL = 10.minutes
    LAST_WEBHOOK_KEY = "voice:livekit:last_webhook_at"
    LAST_WEBHOOK_TTL = 7.days

    def self.configured?
      SiteSetting.voice_livekit_url.present? && SiteSetting.voice_livekit_api_key.present? &&
        SiteSetting.voice_livekit_api_secret.present?
    end

    def self.available_for?(room)
      return false unless configured?

      case SiteSetting.voice_livekit_room_policy
      when "all_rooms"
        true
      when "per_room"
        room.livekit_enabled
      else
        false
      end
    end

    # Room id, not slug — slugs are mutable. The database prefix keeps rooms
    # from different sites on a shared cluster apart as defense in depth.
    def self.room_name(room)
      "#{room_name_prefix}-r#{room.id}"
    end

    # Inverse of `room_name`, for webhook events: the room id encoded in a
    # LiveKit room name, or nil for names outside this site's namespace
    # (other sites on a shared server, rooms created by other tools).
    def self.room_id_from_name(name)
      match = /\A#{Regexp.escape(room_name_prefix)}-r(\d+)\z/.match(name.to_s)
      match && match[1].to_i
    end

    def self.room_name_prefix
      SiteSetting.voice_livekit_room_prefix.presence ||
        RailsMultisite::ConnectionManagement.current_db
    end

    # Freshness marker for the admin status panel. Webhooks are a
    # reconcile-only backstop, so a configured server that stopped delivering
    # them is a warning there, never an error.
    def self.touch_last_webhook!
      Discourse.redis.setex(LAST_WEBHOOK_KEY, LAST_WEBHOOK_TTL.to_i, Time.now.to_f)
    end

    def self.last_webhook_at
      raw = Discourse.redis.get(LAST_WEBHOOK_KEY)
      raw.present? ? Time.at(raw.to_f) : nil
    end

    # The track sources a publisher may send. Camera and screen sharing are
    # granted independently, so a user allowed only one of them gets a token
    # the SFU will refuse the other on. Lowercase is the access-token grant
    # spelling; RoomService permission updates use the same names uppercased
    # (the proto enum).
    def self.publish_sources(room, can_publish, guardian)
      return [] unless can_publish

      sources = ["microphone"]
      sources << "camera" if guardian.can_publish_video_in_voice_room?(room)
      if guardian.can_screen_share_in_voice_room?(room)
        sources.concat(%w[screen_share screen_share_audio])
      end
      sources
    end

    # Least-privilege HS256 JWT: a leaked token can only join this one room,
    # as this one user, for TOKEN_TTL. Guardian remains the sole authority —
    # callers only mint for users who passed `ensure_can_join_voice_room!`.
    def self.mint_token(user:, room:, guardian:)
      raise MintError, "LiveKit is not fully configured" unless configured?

      can_publish = guardian.can_speak_in_voice_room?(room)
      sources = publish_sources(room, can_publish, guardian)

      payload = {
        iss: SiteSetting.voice_livekit_api_key,
        sub: user.id.to_s,
        name: user.username,
        exp: TOKEN_TTL.from_now.to_i,
        video: {
          room: room_name(room),
          roomJoin: true,
          canSubscribe: true,
          canPublish: can_publish,
          canPublishSources: sources,
          canPublishData: false,
          canUpdateOwnMetadata: false,
          roomCreate: false,
          roomList: false,
          roomAdmin: false,
          roomRecord: false,
          recorder: false,
          hidden: false,
        },
      }

      JWT.encode(payload, SiteSetting.voice_livekit_api_secret, "HS256")
    end
  end
end
