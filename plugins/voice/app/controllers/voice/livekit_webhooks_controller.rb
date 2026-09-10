# frozen_string_literal: true

module Voice
  # Human events only reconcile existing presence; agents require an authorized
  # session verified against the current provider connection.
  class LivekitWebhooksController < ApplicationController
    skip_before_action :ensure_logged_in,
                       :verify_authenticity_token,
                       :redirect_to_login_if_required,
                       :redirect_to_profile_if_required,
                       :check_xhr,
                       :preload_json

    def create
      body = request.body.read

      begin
        Livekit::WebhookVerifier.verify!(
          authorization: request.headers["Authorization"],
          body: body,
        )
      rescue Livekit::WebhookVerifier::VerificationError => e
        Rails.logger.warn("[voice-livekit] rejected webhook: #{e.message}")
        return head :forbidden
      end

      Livekit.touch_last_webhook!

      event = parse_event(body)
      return head :bad_request if event.nil?

      case event["event"]
      when "participant_joined"
        record_participant_join(event)
      when "participant_left", "participant_connection_aborted"
        expire_participant(event)
      when "room_finished"
        finish_room(event)
      when "egress_ended"
        egress_ended(event)
      end

      head :ok
    end

    private

    def parse_event(body)
      parsed = JSON.parse(body)
      parsed.is_a?(Hash) ? parsed : nil
    rescue JSON::ParserError
      nil
    end

    def record_participant_join(event)
      room = event_room(event)
      return if room.nil?

      identity = event.dig("participant", "identity").to_s
      return unless /\A-?[1-9]\d*\z/.match?(identity)

      user_id = identity.to_i
      return AgentManager.reconcile(room) if user_id.negative?

      ParticipantTracker.set_livekit_sid(room.id, user_id, event.dig("participant", "sid"))
    end

    def expire_participant(event)
      room = event_room(event)
      return if room.nil?

      identity = event.dig("participant", "identity").to_s
      return unless /\A-?[1-9]\d*\z/.match?(identity)

      user_id = identity.to_i
      return AgentManager.reconcile(room) if user_id.negative?

      # A quick disconnect/rejoin can deliver the old session's departure
      # after the new session is up; `gone_at` can't distinguish them (the
      # rejoin predates the disconnect), but the SID can. Departures without
      # SID context on either side keep expiring — reconcile-only backstop.
      sid = event.dig("participant", "sid")
      known_sid = Voice::ParticipantTracker.livekit_sid(room.id, user_id)
      return if sid.present? && known_sid.present? && sid != known_sid

      expired =
        Voice::ParticipantTracker.expire_presence(
          room.id,
          user_id,
          gone_at: event_created_at(event),
        )
      if expired
        if ParticipantTracker.human_user_ids(room.id).empty? &&
             AgentIntegrationRoom.exists?(room_id: room.id)
          AgentManager.evict_agents_in_room!(room)
        end
        RoomBroadcaster.publish_participants_if_changed(room)
      end
    end

    def finish_room(event)
      room = event_room(event)
      return if room.nil?

      AgentManager.evict_agents_in_room!(room, delete_room: false)
      Voice::ParticipantTracker.clear_livekit_sids(room.id)
    end

    # Egress events name the room inside egressInfo, not in a room object,
    # and are handled regardless of the transport pin: by the time the final
    # egress of a finished room reports in, the pin may already be gone.
    def egress_ended(event)
      egress_info = event["egress_info"] || event["egressInfo"]
      room_name = egress_info&.fetch("room_name", egress_info["roomName"])
      room_id = Livekit.room_id_from_name(room_name)
      return if room_id.nil?

      room = Voice::Room.find_by(id: room_id)
      return if room.nil?

      Voice::RecordingManager.handle_egress_ended(room, egress_info)
    end

    # Resolves the event's LiveKit room name back to a room, ignoring events
    # for other sites on a shared server (foreign prefix) and for rooms not
    # currently pinned to livekit — a mesh call's presence is none of
    # LiveKit's business, however stale the SFU's view of the room is.
    def event_room(event)
      room_id = Livekit.room_id_from_name(event.dig("room", "name"))
      return if room_id.nil?
      return if Voice::ParticipantTracker.pinned_transport(room_id) != "livekit"

      Voice::Room.find_by(id: room_id)
    end

    # Proto3 JSON renders int64 as a string; tolerate a plain number too.
    def event_created_at(event)
      ts = event["createdAt"].to_i
      ts.positive? ? Time.at(ts) : nil
    end
  end
end
