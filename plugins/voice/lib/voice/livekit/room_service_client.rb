# frozen_string_literal: true

module Voice
  module Livekit
    # Minimal Twirp-JSON client for the three RoomService calls that keep the
    # SFU in sync with Discourse-side moderation and lifecycle events. Every
    # call is best-effort and requires a transport pin or pending agent cleanup: the SFU
    # being slow or down must never fail the Discourse request that triggered
    # the call, and mesh rooms must make zero HTTP requests.
    class RoomServiceClient
      TIMEOUT_SECONDS = 2

      class << self
        def remove_participant(room, user_id, identity: nil)
          call(
            room,
            "RemoveParticipant",
            body: {
              identity: identity || participant_identity(room, user_id),
            },
            agent_cleanup: user_id.to_i.negative?,
          )
        end

        # UpdateParticipant replaces the participant's whole permission
        # object, so this sends the full set mirroring the access-token
        # grants — sending only `canPublish` would silently revoke
        # `canSubscribe` and deafen the participant.
        def update_participant(room, user, identity: nil)
          can_publish =
            user.bot? ? user.id == AgentBot.user&.id : user.guardian.can_speak_in_voice_room?(room)
          call(
            room,
            "UpdateParticipant",
            agent_cleanup: user.id.negative?,
            body: {
              identity: identity || participant_identity(room, user.id),
              permission: {
                canSubscribe: true,
                canPublish: can_publish,
                canPublishData: false,
                canPublishSources: Livekit.publish_sources(room, can_publish).map(&:upcase),
                hidden: false,
                recorder: false,
              },
            },
          )
        end

        def delete_room(room)
          # LiveKit guards DeleteRoom behind the roomCreate grant; a
          # room-scoped roomAdmin token gets "permissions denied".
          call(room, "DeleteRoom", grants: { roomCreate: true }, agent_cleanup: true)
        end

        # Diagnostic probes for the admin status panel. Unlike the sync calls
        # above they run regardless of any room's transport pin, and return a
        # structured result — latency and an error string for the admin to
        # read — instead of a boolean plus a log line.

        def list_rooms
          probe("ListRooms", grants: { roomList: true })
        end

        def list_participants(livekit_room)
          probe(
            "ListParticipants",
            body: {
              room: livekit_room,
            },
            grants: {
              roomAdmin: true,
              room: livekit_room,
            },
          )
        end

        private

        def participant_identity(room, user_id)
          if user_id.to_i.negative?
            ParticipantTracker.get_metadata(room.id, user_id)[:livekit_identity] || user_id.to_s
          else
            user_id.to_s
          end
        end

        def sync?(room, agent_cleanup:)
          Livekit.configured? &&
            (
              Voice::ParticipantTracker.pinned_transport(room.id) == "livekit" ||
                (agent_cleanup && AgentManager.provider_room?(room.id))
            )
        end

        def call(room, method, body: {}, grants: { roomAdmin: true }, agent_cleanup: false)
          return unless sync?(room, agent_cleanup:)

          livekit_room = Livekit.room_name(room)
          response = post(method, body.merge(room: livekit_room), grants.merge(room: livekit_room))

          if response.status == 200
            true
          elsif method == "DeleteRoom" && response.status == 404
            # The SFU tears an emptied room down on its own, so the last
            # leave's DeleteRoom routinely races it — already-gone is the
            # desired end state, not a fault worth a Logster entry.
            Rails.logger.debug("[voice-livekit] DeleteRoom no-op for room #{room.id}: already gone")
            true
          else
            Rails.logger.warn(
              "[voice-livekit] #{method} failed for room #{room.id}: " \
                "HTTP #{response.status} #{response.body.to_s.truncate(200)}",
            )
            false
          end
        rescue StandardError => e
          Rails.logger.warn(
            "[voice-livekit] #{method} failed for room #{room.id}: #{e.class} #{e.message}",
          )
          false
        end

        def probe(method, body: {}, grants:)
          return { ok: false, error: "LiveKit is not configured" } unless Livekit.configured?

          started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          response = post(method, body, grants)
          latency_ms = elapsed_ms(started)

          if response.status == 200
            { ok: true, latency_ms:, data: JSON.parse(response.body) }
          else
            # The upstream body goes to the log for the operator; the result
            # shown to admins only carries the status code.
            Rails.logger.warn(
              "[voice-livekit] #{method} probe failed: " \
                "HTTP #{response.status} #{response.body.to_s.truncate(200)}",
            )
            { ok: false, latency_ms:, error: "HTTP #{response.status}" }
          end
        rescue FinalDestination::SSRFDetector::DisallowedIpError
          {
            ok: false,
            latency_ms: elapsed_ms(started),
            error: "The LiveKit URL resolves to an address this server is not allowed to reach",
          }
        rescue StandardError => e
          { ok: false, latency_ms: elapsed_ms(started), error: "#{e.class}: #{e.message}" }
        end

        def elapsed_ms(started)
          ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
        end

        def post(method, body, grants)
          Twirp.post(
            service: "RoomService",
            method: method,
            body: body,
            grants: grants,
            timeout: TIMEOUT_SECONDS,
          )
        end
      end
    end
  end
end
