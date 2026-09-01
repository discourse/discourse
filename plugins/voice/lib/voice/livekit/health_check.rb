# frozen_string_literal: true

module Voice
  module Livekit
    # Diagnostics behind the admin status panel and the one-shot probe job:
    # config-time connectivity checks (token self-mint, RoomService reach)
    # plus a Redis-presence vs LiveKit-participants diff for live rooms — the
    # triage view for "connects but no media" and ghost-participant reports.
    # Results carry booleans, latencies and error strings; never setting
    # values — the API secret must not be reconstructable from any payload.
    module HealthCheck
      LAST_PROBE_KEY = "voice:livekit:last_probe"
      LAST_PROBE_TTL = 7.days

      class << self
        def settings_status
          {
            url_present: SiteSetting.voice_livekit_url.present?,
            api_key_present: SiteSetting.voice_livekit_api_key.present?,
            api_secret_present: SiteSetting.voice_livekit_api_secret.present?,
            policy: SiteSetting.voice_livekit_room_policy,
          }
        end

        # Signs and verifies a token locally with the configured key pair — the
        # cheapest "can we mint at all" check, catching config problems (blank
        # or truncated secret) without touching the network. Whether the server
        # *accepts* our signatures is what `server_check` answers: ListRooms
        # authenticates with a token minted the same way.
        def token_check
          token =
            JWT.encode(
              {
                iss: SiteSetting.voice_livekit_api_key,
                exp: 1.minute.from_now.to_i,
                video: {
                  roomList: true,
                },
              },
              SiteSetting.voice_livekit_api_secret,
              "HS256",
            )
          JWT.decode(token, SiteSetting.voice_livekit_api_secret, true, algorithm: "HS256")
          { ok: true }
        rescue StandardError => e
          { ok: false, error: "#{e.class}: #{e.message}" }
        end

        def server_check
          result = RoomServiceClient.list_rooms

          if result[:ok]
            {
              ok: true,
              latency_ms: result[:latency_ms],
              room_count: result[:data]["rooms"].to_a.size,
            }
          else
            { ok: false, latency_ms: result[:latency_ms], error: result[:error] }
          end
        end

        def connectivity_check
          token = token_check
          server = server_check

          { ok: token[:ok] && server[:ok], checked_at: Time.now.utc.iso8601, token:, server: }
        end

        def store_probe!(result)
          Discourse.redis.setex(LAST_PROBE_KEY, LAST_PROBE_TTL.to_i, result.to_json)
        end

        def last_probe
          raw = Discourse.redis.get(LAST_PROBE_KEY)
          raw.present? ? JSON.parse(raw, symbolize_names: true) : nil
        end

        def clear_probe!
          Discourse.redis.del(LAST_PROBE_KEY)
        end

        # Every room currently pinned to livekit, with the Redis-side roster
        # and (when `probe_participants` — callers pass false when the server
        # is already known unreachable, to avoid stacking per-room timeouts)
        # the identities LiveKit actually has connected. Pinned rooms are
        # always recently active: the pin's TTL is refreshed by joins and
        # heartbeats, which also touch the recently-active set.
        def pinned_rooms_status(probe_participants: true)
          room_ids =
            ParticipantTracker.recently_active_room_ids.select do |room_id|
              ParticipantTracker.pinned_transport(room_id) == "livekit"
            end
          return [] if room_ids.empty?

          Voice::Room
            .where(id: room_ids)
            .order(:id)
            .map { |room| room_status(room, probe_participants:) }
        end

        def room_status(room, probe_participants:)
          status = {
            room_id: room.id,
            name: room.name,
            presence_user_ids: ParticipantTracker.user_ids(room.id).sort,
          }
          return status unless probe_participants

          result = RoomServiceClient.list_participants(Livekit.room_name(room))
          return status.merge(error: result[:error]) if !result[:ok]

          livekit_ids =
            result[:data]["participants"]
              .to_a
              .filter_map do |participant|
                id = participant["identity"].to_i
                id if id.positive?
              end
              .sort

          status.merge(
            livekit_user_ids: livekit_ids,
            missing_on_livekit: status[:presence_user_ids] - livekit_ids,
            missing_in_presence: livekit_ids - status[:presence_user_ids],
          )
        end
      end
    end
  end
end
