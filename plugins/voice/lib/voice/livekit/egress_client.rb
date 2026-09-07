# frozen_string_literal: true

module Voice
  module Livekit
    # Twirp-JSON client for LiveKit's Egress service, which records rooms
    # server-side. Where the recording lands (S3, GCS, local disk) is the
    # egress deployment's own configuration — Discourse only passes a
    # filepath, so no storage credentials live here.
    #
    # Unlike RoomServiceClient's fire-and-forget sync calls, these return a
    # structured result: the caller (RecordingManager) must know whether a
    # recording actually started before telling a room it is being recorded.
    class EgressClient
      # Starting an egress spins up a recorder process on the media server,
      # which is much slower than a RoomService metadata call.
      TIMEOUT_SECONDS = 10

      class << self
        def start_room_composite(room, filepath:)
          request(
            "StartRoomCompositeEgress",
            roomName: Livekit.room_name(room),
            audioOnly: !room.video_allowed?,
            fileOutputs: [{ filepath: filepath }],
          )
        end

        def stop(egress_id)
          request("StopEgress", egressId: egress_id)
        end

        def list(egress_id:)
          request("ListEgress", egressId: egress_id)
        end

        private

        def request(method, body)
          return { ok: false, error: "LiveKit is not configured" } unless Livekit.configured?

          response =
            Twirp.post(
              service: "Egress",
              method: method,
              body: body,
              grants: {
                roomRecord: true,
              },
              timeout: TIMEOUT_SECONDS,
            )

          if response.status == 200
            { ok: true, data: JSON.parse(response.body) }
          else
            # The upstream body goes to the log for the operator; the result
            # surfaced to the UI only carries the status code.
            Rails.logger.warn(
              "[voice-livekit] #{method} failed: " \
                "HTTP #{response.status} #{response.body.to_s.truncate(200)}",
            )
            { ok: false, error: "HTTP #{response.status}" }
          end
        rescue FinalDestination::SSRFDetector::DisallowedIpError
          {
            ok: false,
            error: "The LiveKit URL resolves to an address this server is not allowed to reach",
          }
        rescue StandardError => e
          Rails.logger.warn("[voice-livekit] #{method} failed: #{e.class} #{e.message}")
          { ok: false, error: "#{e.class}: #{e.message}" }
        end
      end
    end
  end
end
