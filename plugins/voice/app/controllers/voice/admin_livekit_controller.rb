# frozen_string_literal: true

module Voice
  # Status payloads report presence booleans, latencies and error strings —
  # never setting values. A request spec pins that the API secret cannot
  # appear here (or in any serializer) whatever state the probes are in.
  class AdminLivekitController < ::Admin::AdminController
    requires_plugin "voice"

    def status
      render json: status_payload
    end

    def probe
      return render json: status_payload unless Livekit.configured?

      result = Livekit::HealthCheck.connectivity_check
      Livekit::HealthCheck.store_probe!(result)

      render json:
               status_payload(
                 probe_result: result,
                 token_check: result[:token],
                 server_check: result[:server],
               )
    end

    private

    def status_payload(probe_result: nil, token_check: nil, server_check: nil)
      configured = Livekit.configured?

      payload = {
        configured:,
        settings: Livekit::HealthCheck.settings_status,
        last_webhook_at: Livekit.last_webhook_at&.iso8601,
        # For the ready-to-paste server config snippet; derived from the
        # site's own URL, not from any LiveKit setting.
        webhook_url: "#{Discourse.base_url}/voice/livekit/webhook",
        last_probe: probe_result || Livekit::HealthCheck.last_probe,
        rooms: [],
      }

      if configured
        payload[:token_check] = token_check || Livekit::HealthCheck.token_check
        payload[:server_check] = server_check || Livekit::HealthCheck.server_check

        # When the server is already known unreachable, per-room participant
        # probes would only stack timeouts onto the response.
        rooms =
          Livekit::HealthCheck.pinned_rooms_status(probe_participants: payload[:server_check][:ok])
        payload[:rooms] = rooms
        payload[:usernames] = usernames_for(rooms)
      end

      payload
    end

    # Id → username for every id in the roster diffs, so the panel can show
    # who is ghosting instead of bare ids.
    def usernames_for(rooms)
      user_ids =
        rooms
          .flat_map { |room| [room[:presence_user_ids], room[:livekit_user_ids]] }
          .flatten
          .compact
          .uniq
      return {} if user_ids.empty?

      User.where(id: user_ids).pluck(:id, :username).to_h
    end
  end
end
