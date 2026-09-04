# frozen_string_literal: true

module Voice
  # Starts and stops server-side recordings of a room's live call and owns
  # the room-wide "this call is being recorded" state. Recording is a LiveKit
  # egress, so it only exists for calls pinned to that transport; the live
  # state sits alongside the transport pin and dies with the room instance,
  # while a Recording row persists each egress for delivery and the admin
  # log.
  #
  # Every state change is broadcast to the room: participants must always
  # know a recording is running, not just whoever pressed the button.
  class RecordingManager
    class Error < StandardError
    end

    # Terminal values of EgressInfo.status; anything else is still running
    # (or about to run) and must not be finalized.
    FINAL_EGRESS_STATUSES = %w[
      EGRESS_COMPLETE
      EGRESS_FAILED
      EGRESS_ABORTED
      EGRESS_LIMIT_REACHED
    ].freeze

    # An unresolved row whose egress the server no longer remembers (restart,
    # retention) can never complete; past this age it is written off.
    ABANDONED_AFTER = 24.hours

    class << self
      def available_for?(room)
        SiteSetting.voice_livekit_recording_enabled &&
          Voice::ParticipantTracker.pinned_transport(room.id) == "livekit"
      end

      # Public shape shared by the serializer, the broadcasts, and the
      # start endpoint's response.
      def status(room_id)
        status_from_info(Voice::ParticipantTracker.recording(room_id))
      end

      def status_from_info(info)
        return nil if info.nil?

        {
          started_at: info[:started_at],
          started_by: {
            id: info[:user_id],
            username: info[:username],
          },
        }
      end

      def start!(room, user)
        raise Error, I18n.t("voice.errors.recording_unavailable") unless available_for?(room)
        if Voice::ParticipantTracker.recording(room.id)
          raise Error, I18n.t("voice.errors.recording_already_active")
        end

        # The random suffix makes the storage path a capability: the final
        # URL is only ever shared with the requester, so it must not be
        # derivable from public facts like the room name and start time.
        filepath = "#{SiteSetting.voice_livekit_recording_filepath}-#{SecureRandom.hex(8)}"

        result = Voice::Livekit::EgressClient.start_room_composite(room, filepath: filepath)
        raise Error, I18n.t("voice.errors.recording_failed") unless result[:ok]

        egress_id = result[:data]["egress_id"] || result[:data]["egressId"]
        started_at = Time.zone.now
        Voice::Recording.create!(
          room: room,
          started_by: user,
          egress_id: egress_id,
          filepath: filepath,
          started_at: started_at,
        )
        Voice::ParticipantTracker.set_recording(
          room.id,
          egress_id: egress_id,
          user_id: user.id,
          username: user.username,
          started_at: started_at.to_f,
        )
        broadcast(room)
        status(room.id)
      end

      def stop!(room)
        info = Voice::ParticipantTracker.recording(room.id)
        raise Error, I18n.t("voice.errors.recording_not_active") if info.nil?

        result = Voice::Livekit::EgressClient.stop(info[:egress_id])
        # A failed stop keeps the state: the egress may well still be
        # capturing, and claiming otherwise is worse than asking the
        # moderator to retry. The egress_ended webhook and the state's TTL
        # clean up an egress that already ended on its own.
        raise Error, I18n.t("voice.errors.recording_stop_failed") unless result[:ok]

        Voice::ParticipantTracker.clear_recording(room.id)
        broadcast(room)
      end

      # The egress_ended webhook closes out every recording — whether stopped
      # from here, ended with the room, or killed server-side. It finalizes
      # the Recording row with the file's whereabouts and messages the
      # requester, then clears any still-live room state.
      def handle_egress_ended(room, egress_info)
        egress_id = (egress_info["egress_id"] || egress_info["egressId"]).to_s
        recording = Voice::Recording.find_by(egress_id: egress_id)

        if recording&.recording?
          finalize_recording(recording, egress_info)
          deliver_recording(recording) if recording.completed?
        end

        info = Voice::ParticipantTracker.recording(room.id)
        return if info.nil? || info[:egress_id] != egress_id

        Voice::ParticipantTracker.clear_recording(room.id)
        broadcast(room)
      end

      # Polling fallback for sites without webhooks (and backstop for missed
      # deliveries): resolve every stuck row by asking the Egress service
      # directly. ListEgress returns the same EgressInfo shape the webhook
      # carries, so a finished egress goes through the exact same
      # finalize-and-deliver path.
      def reconcile_pending!
        Voice::Recording
          .recording
          .includes(:room)
          .find_each do |recording|
            result = Voice::Livekit::EgressClient.list(egress_id: recording.egress_id)
            next unless result[:ok]

            info = Array(result[:data]["items"]).first

            if info.nil?
              if recording.started_at < ABANDONED_AFTER.ago
                recording.update!(status: :failed, ended_at: Time.zone.now)
              end
              next
            end

            next if FINAL_EGRESS_STATUSES.exclude?(info["status"])

            handle_egress_ended(recording.room, info)
          end
      end

      private

      def finalize_recording(recording, egress_info)
        file = Array(egress_info["file_results"] || egress_info["fileResults"]).first || {}
        failed = egress_info["error"].present? || file.blank?

        recording.update!(
          status: failed ? :failed : :completed,
          filename: file["filename"].presence,
          location: file["location"].presence,
          # Proto3 JSON renders int64 as a string; duration is nanoseconds.
          duration_ms: file["duration"].present? ? file["duration"].to_i / 1_000_000 : nil,
          size_bytes: file["size"].presence&.to_i,
          ended_at: Time.zone.now,
        )
      end

      def deliver_recording(recording)
        requester = recording.started_by
        return if requester.nil? || !requester.human?

        body_key =
          if recording.location.present?
            "voice.recording_ready_pm.body_with_link"
          else
            "voice.recording_ready_pm.body_with_path"
          end

        PostCreator.create!(
          Discourse.system_user,
          archetype: Archetype.private_message,
          target_usernames: requester.username,
          title: I18n.t("voice.recording_ready_pm.title", room_name: recording.room.name),
          raw:
            I18n.t(
              body_key,
              room_name: recording.room.name,
              link: recording.location,
              filepath: recording.filepath,
              duration: format_duration(recording.duration_ms),
            ),
          skip_validations: true,
        )
      rescue StandardError => e
        # Delivery is best-effort: the recording is safe and listed in the
        # admin panel even when the PM cannot be created.
        Rails.logger.warn(
          "[voice-livekit] recording PM failed for recording #{recording.id}: " \
            "#{e.class} #{e.message}",
        )
      end

      def format_duration(duration_ms)
        return I18n.t("voice.recording_ready_pm.unknown_duration") if duration_ms.blank?

        total_seconds = duration_ms / 1000
        minutes, seconds = total_seconds.divmod(60)
        hours, minutes = minutes.divmod(60)
        if hours.positive?
          format("%d:%02d:%02d", hours, minutes, seconds)
        else
          format("%d:%02d", minutes, seconds)
        end
      end

      def broadcast(room)
        Voice::RoomBroadcaster.new(room).publish_room(
          { type: "recording", recording: status(room.id) },
        )
      end
    end
  end
end
