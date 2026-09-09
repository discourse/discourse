# frozen_string_literal: true

module Voice
  module Livekit
    # Twirp-JSON client for LiveKit's Egress service, which records rooms
    # server-side. Dedicated S3 settings override the egress deployment's
    # storage configuration and are required for recording on LiveKit Cloud.
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
          output = { filepath: filepath }
          if SiteSetting.voice_livekit_recording_s3_bucket.present?
            validator = VoiceLivekitRecordingS3BucketValidator.new
            unless validator.valid_value?(SiteSetting.voice_livekit_recording_s3_bucket)
              Voice.warn(
                "[voice-livekit] StartRoomCompositeEgress refused: invalid recording storage configuration",
              )
              return { ok: false, error: validator.error_message }
            end

            output[:s3] = {
              bucket: SiteSetting.voice_livekit_recording_s3_bucket,
              region: SiteSetting.voice_livekit_recording_s3_region,
              accessKey: SiteSetting.voice_livekit_recording_s3_access_key_id,
              secret: SiteSetting.voice_livekit_recording_s3_secret_access_key,
            }
            if SiteSetting.voice_livekit_recording_s3_endpoint.present?
              output[:s3][:endpoint] = SiteSetting.voice_livekit_recording_s3_endpoint
              output[:s3][:forcePathStyle] = true
            end
          end

          request(
            "StartRoomCompositeEgress",
            roomName: Livekit.room_name(room),
            audioOnly: !room.video_allowed?,
            fileOutputs: [output],
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
            Voice.warn(
              "[voice-livekit] #{method} failed: " \
                "HTTP #{response.status}",
            )
            { ok: false, error: "HTTP #{response.status}" }
          end
        rescue FinalDestination::SSRFDetector::DisallowedIpError
          {
            ok: false,
            error: "The LiveKit URL resolves to an address this server is not allowed to reach",
          }
        rescue StandardError => e
          message = redact_credentials(e.message)
          Voice.warn("[voice-livekit] #{method} failed: #{e.class}")
          { ok: false, error: "#{e.class}: #{message}" }
        end

        def redact_credentials(message)
          message = message.to_s
          [
            SiteSetting.voice_livekit_recording_s3_access_key_id,
            SiteSetting.voice_livekit_recording_s3_secret_access_key,
          ].each do |credential|
            message = message.gsub(credential, "[FILTERED]") if credential.present?
          end
          message
        end
      end
    end
  end
end
